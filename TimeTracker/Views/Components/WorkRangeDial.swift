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
        VStack(spacing: AppTheme.spacingSM) {
            HStack {
                timeBlock(title: "Stop", value: formattedTime(for: endMinutes), alignment: .leading)
                Spacer()
                timeBlock(title: "Start", value: formattedTime(for: startMinutes), alignment: .trailing)
            }

            GeometryReader { geometry in
                let side = min(geometry.size.width, geometry.size.height)
                let lineWidth = max(20, side * 0.088)
                let ringInset = lineWidth / 2 + 14
                let radius = (side / 2) - ringInset
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

                ZStack {
                    dotRing(radius: radius + 14, center: center)

                    Circle()
                        .stroke(AppTheme.surfaceMuted, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .frame(width: radius * 2, height: radius * 2)

                    RangeArcShape(startMinutes: startMinutes, endMinutes: endMinutes, totalMinutes: totalMinutes)
                        .stroke(
                            LinearGradient(
                                colors: [tint.opacity(0.95), tint.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: tint.opacity(0.45), radius: 10)
                        .frame(width: radius * 2, height: radius * 2)

                    Circle()
                        .fill(AppTheme.surface)
                        .overlay(Circle().strokeBorder(AppTheme.edgeHighlight, lineWidth: 1))
                        .frame(width: radius * 2 - lineWidth - 20, height: radius * 2 - lineWidth - 20)

                    innerClockLabels(radius: radius - lineWidth * 0.78, center: center)

                    handle(for: .start, center: center, radius: radius)
                    handle(for: .end, center: center, radius: radius)
                }
                .contentShape(Rectangle())
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
            .frame(height: 226)

            VStack(spacing: 4) {
                Text("Worked")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)

                Text(workedDurationText)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .numericTextTransition()
                    .foregroundColor(AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var workedDurationMinutes: Int {
        (endMinutes - startMinutes + totalMinutes) % totalMinutes
    }

    private var workedDurationText: String {
        let hours = workedDurationMinutes / 60
        let minutes = workedDurationMinutes % 60
        return String(format: "%02dh %02dm", hours, minutes)
    }

    @ViewBuilder
    private func dotRing(radius: CGFloat, center: CGPoint) -> some View {
        ZStack {
            ForEach(0..<96, id: \.self) { index in
                let minute = index * 15
                Circle()
                    .fill(isMinuteWithinRange(minute) ? tint.opacity(0.9) : AppTheme.textTertiary.opacity(0.5))
                    .frame(width: index.isMultiple(of: 4) ? 4 : 2.5, height: index.isMultiple(of: 4) ? 4 : 2.5)
                    .position(position(for: minute, center: center, radius: radius))
            }
        }
    }

    @ViewBuilder
    private func innerClockLabels(radius: CGFloat, center: CGPoint) -> some View {
        ZStack {
            clockMarker("12AM", minute: 0, center: center, radius: radius)
            clockMarker("6AM", minute: 6 * 60, center: center, radius: radius)
            clockMarker("12PM", minute: 12 * 60, center: center, radius: radius)
            clockMarker("6PM", minute: 18 * 60, center: center, radius: radius)
        }
    }

    @ViewBuilder
    private func clockMarker(_ title: String, minute: Int, center: CGPoint, radius: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textSecondary)
            .position(position(for: minute, center: center, radius: radius))
    }

    @ViewBuilder
    private func handle(for handle: Handle, center: CGPoint, radius: CGFloat) -> some View {
        let minute = handle == .start ? startMinutes : endMinutes
        let isActive = activeHandle == handle
        let handleRadius = max(14, radius * 0.12)

        Circle()
            .fill(handle == .start ? AppTheme.textPrimary : tint)
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5)
            )
            .frame(width: handleRadius * 1.45, height: handleRadius * 1.45)
            .shadow(color: .black.opacity(isActive ? 0.28 : 0.18), radius: isActive ? 12 : 8, x: 0, y: 4)
            .scaleEffect(isActive ? 1.06 : 1)
            .position(position(for: minute, center: center, radius: radius))
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
        let snapped = Int((Double(minute) / Double(stepMinutes)).rounded()) * stepMinutes
        let normalized = ((snapped % totalMinutes) + totalMinutes) % totalMinutes
        return normalized
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

    private func timeBlock(title: String, value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(AppTheme.textPrimary)
        }
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
