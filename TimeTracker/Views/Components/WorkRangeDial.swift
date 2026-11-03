import SwiftUI

/// A 24-hour ring for picking when work started and stopped; drag either handle in 5-minute steps.
struct WorkRangeDial: View {
    @Binding var startMinutes: Int
    @Binding var endMinutes: Int
    let timeFormatter: DateFormatter
    var tint: Color = AppTheme.accent

    @State private var activeHandle: Handle?

    private enum Handle {
        case start
        case end
    }

    private let totalMinutes = 24 * 60
    private let stepMinutes = 5

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.spacingMD) {
            timeColumn(title: "Start", minutes: $startMinutes, handle: .start)

            dial
                .frame(width: 236, height: 236)
                .frame(maxWidth: .infinity)

            timeColumn(title: "End", minutes: $endMinutes, handle: .end)
        }
    }

    // MARK: - Times

    private func timeColumn(title: String, minutes: Binding<Int>, handle: Handle) -> some View {
        VStack(spacing: AppTheme.spacingSM) {
            HStack(spacing: 6) {
                handleMark(handle, size: 9)
                AppTheme.sectionLabel(title)
            }

            Text(formattedTime(for: minutes.wrappedValue))
                .font(.system(size: 26, weight: .semibold))
                .monospacedDigit()
                .numericTextTransition()
                .foregroundColor(AppTheme.textPrimary)
                .animation(.easeOut(duration: 0.15), value: minutes.wrappedValue)

            HStack(spacing: AppTheme.spacingSM) {
                stepButton(systemImage: "minus", minutes: minutes, by: -stepMinutes, help: "\(stepMinutes) minutes earlier")
                stepButton(systemImage: "plus", minutes: minutes, by: stepMinutes, help: "\(stepMinutes) minutes later")
            }
            .glassGroup(spacing: AppTheme.spacingSM)
        }
        .frame(width: 124)
    }

    private func stepButton(systemImage: String, minutes: Binding<Int>, by delta: Int, help: String) -> some View {
        Button {
            minutes.wrappedValue = normalized(minutes.wrappedValue + delta)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.glassCircle())
        .help(help)
    }

    // MARK: - Dial

    private var dial: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let lineWidth: CGFloat = 18
            let radius = side / 2 - lineWidth / 2 - 12
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                hourTicks(radius: radius + lineWidth / 2 + 7, center: center)

                Circle()
                    .stroke(AppTheme.surfaceMuted, lineWidth: lineWidth)
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)

                RangeArcShape(startMinutes: startMinutes, endMinutes: endMinutes, totalMinutes: totalMinutes)
                    .stroke(tint.opacity(0.9), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)

                hourLabels(radius: radius - lineWidth / 2 - 15, center: center)

                VStack(spacing: 2) {
                    AppTheme.sectionLabel("Worked")
                    Text(workedDurationText)
                        .font(.system(size: 22, weight: .semibold))
                        .monospacedDigit()
                        .numericTextTransition()
                        .foregroundColor(AppTheme.textPrimary)
                }
                .position(center)

                // The smaller end dot sits on top of the start ring, so both show when they meet.
                handle(.start, center: center, radius: radius)
                handle(.end, center: center, radius: radius)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateHandle(from: value.location, in: geometry.size)
                    }
                    .onEnded { _ in
                        activeHandle = nil
                    }
            )
        }
    }

    private var workedDurationMinutes: Int {
        (endMinutes - startMinutes + totalMinutes) % totalMinutes
    }

    private var workedDurationText: String {
        let hours = workedDurationMinutes / 60
        let minutes = workedDurationMinutes % 60
        return String(format: "%dh %02dm", hours, minutes)
    }

    private func hourTicks(radius: CGFloat, center: CGPoint) -> some View {
        ZStack {
            ForEach(0..<24, id: \.self) { hour in
                let isMajor = hour.isMultiple(of: 6)

                VStack {
                    Capsule()
                        .fill(isMinuteWithinRange(hour * 60) ? tint.opacity(0.9) : AppTheme.textTertiary)
                        .frame(width: isMajor ? 2 : 1.5, height: isMajor ? 7 : 4)
                    Spacer(minLength: 0)
                }
                .frame(width: 8, height: radius * 2)
                .rotationEffect(.degrees(Double(hour) * 15))
                .position(center)
            }
        }
    }

    private func hourLabels(radius: CGFloat, center: CGPoint) -> some View {
        ZStack {
            ForEach([0, 6, 12, 18], id: \.self) { hour in
                Text(hourLabel(hour))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textTertiary)
                    .position(position(for: hour * 60, center: center, radius: radius))
            }
        }
    }

    /// "12 AM" style for 12-hour clocks, plain hours for 24-hour ones.
    private func hourLabel(_ hour: Int) -> String {
        guard timeFormatter.dateFormat.contains("a") else { return "\(hour)" }
        let display = hour % 12 == 0 ? 12 : hour % 12
        return "\(display) \(hour < 12 ? "AM" : "PM")"
    }

    @ViewBuilder
    private func handle(_ handle: Handle, center: CGPoint, radius: CGFloat) -> some View {
        let minute = handle == .start ? startMinutes : endMinutes
        let isActive = activeHandle == handle

        handleMark(handle, size: handle == .start ? 24 : 15)
            .shadow(color: .black.opacity(isActive ? 0.35 : 0.22), radius: isActive ? 8 : 5, y: 2)
            .scaleEffect(isActive ? 1.12 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isActive)
            .position(position(for: minute, center: center, radius: radius))
    }

    /// Start is a white ring, end a filled dot in the project's colour.
    @ViewBuilder
    private func handleMark(_ handle: Handle, size: CGFloat) -> some View {
        switch handle {
        case .start:
            Circle()
                .fill(AppTheme.canvas)
                .overlay(Circle().strokeBorder(AppTheme.textPrimary, lineWidth: max(2, size * 0.14)))
                .frame(width: size, height: size)
        case .end:
            Circle()
                .fill(tint)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: max(1, size * 0.08)))
                .frame(width: size, height: size)
        }
    }

    private func updateHandle(from location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y

        var degrees = atan2(dy, dx) * 180 / .pi + 90
        if degrees < 0 {
            degrees += 360
        }

        let rawMinutes = Int((degrees / 360) * Double(totalMinutes))
        let snappedMinutes = snap(rawMinutes)

        if activeHandle == nil {
            activeHandle = nearestHandle(to: snappedMinutes)
        }

        switch activeHandle {
        case .start:
            startMinutes = snappedMinutes
        case .end:
            endMinutes = snappedMinutes
        case .none:
            break
        }
    }

    private func nearestHandle(to minute: Int) -> Handle {
        let startDistance = circularDistance(from: minute, to: startMinutes)
        let endDistance = circularDistance(from: minute, to: endMinutes)
        return startDistance <= endDistance ? .start : .end
    }

    private func circularDistance(from lhs: Int, to rhs: Int) -> Int {
        let delta = abs(lhs - rhs)
        return min(delta, totalMinutes - delta)
    }

    private func isMinuteWithinRange(_ minute: Int) -> Bool {
        if startMinutes == endMinutes {
            return false
        }

        if startMinutes < endMinutes {
            return minute >= startMinutes && minute <= endMinutes
        }

        return minute >= startMinutes || minute <= endMinutes
    }

    private func snap(_ minute: Int) -> Int {
        normalized(Int((Double(minute) / Double(stepMinutes)).rounded()) * stepMinutes)
    }

    /// Wraps minutes into one day, so stepping past midnight comes round again.
    private func normalized(_ minute: Int) -> Int {
        ((minute % totalMinutes) + totalMinutes) % totalMinutes
    }

    private func position(for minute: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = angle(for: minute)
        return CGPoint(
            x: center.x + cos(angle.radians) * radius,
            y: center.y + sin(angle.radians) * radius
        )
    }

    private func angle(for minute: Int) -> Angle {
        let normalizedMinute = ((minute % totalMinutes) + totalMinutes) % totalMinutes
        return .degrees((Double(normalizedMinute) / Double(totalMinutes) * 360) - 90)
    }

    private func formattedTime(for minute: Int) -> String {
        var components = DateComponents()
        components.hour = minute / 60
        components.minute = minute % 60
        let date = Calendar.current.date(from: components) ?? Date()
        return timeFormatter.string(from: date)
    }

}

private struct RangeArcShape: Shape {
    let startMinutes: Int
    let endMinutes: Int
    let totalMinutes: Int

    func path(in rect: CGRect) -> Path {
        let duration = (endMinutes - startMinutes + totalMinutes) % totalMinutes
        guard duration > 0 else { return Path() }

        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let steps = max(12, duration / 5)

        var path = Path()

        for index in 0...steps {
            let progress = Double(index) / Double(steps)
            let minute = startMinutes + Int(Double(duration) * progress)
            let angle = Angle.degrees((Double(minute % totalMinutes) / Double(totalMinutes) * 360) - 90)
            let point = CGPoint(
                x: center.x + cos(angle.radians) * radius,
                y: center.y + sin(angle.radians) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }
}
