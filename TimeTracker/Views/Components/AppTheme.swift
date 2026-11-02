import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct AppTheme {
    // MARK: - Colors
    // The windows are translucent (see `AppBackdrop`), so surfaces are tints layered
    // over the blurred desktop instead of opaque greys.

    /// Solid dark used under translucent layers and wherever an opaque color is required.
    static let canvas = Color(hex: "#111114")
    /// Root background of each screen. Clear so the window glass shows through.
    static let primary = Color.clear
    static let secondary = Color.white.opacity(0.04)
    static let accent = Color(hex: "#F5F5F7")
    /// Text and icons drawn on top of `accent`.
    static let onAccent = Color(hex: "#111114")
    static let accentBlue = Color(hex: "#E4E4E7")
    static let accentMint = Color(hex: "#63E6BE")
    static let accentWarm = Color(hex: "#FF9F0A")
    static let accentRose = Color(hex: "#FF6482")
    static let recording = Color(hex: "#FF453A")
    static let success = Color(hex: "#30D158")
    static let danger = Color(hex: "#FF453A")
    static let textPrimary = Color(hex: "#F5F5F7")
    static let textSecondary = Color.white.opacity(0.58)
    static let textTertiary = Color.white.opacity(0.34)
    static let surface = Color.white.opacity(0.06)
    static let surfaceAlt = Color.white.opacity(0.11)
    static let surfaceMuted = Color.black.opacity(0.22)
    static let border = Color.white.opacity(0.08)
    static let highlight = Color.white.opacity(0.18)

    /// Hairline that is brighter on top, like light catching the edge of a glass pane.
    static let edgeHighlight = LinearGradient(
        colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let heroGradient = LinearGradient(
        colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let colorPalette: [String] = [
        "#FF6B6B",
        "#FF9F43",
        "#F4D35E",
        "#4ECDC4",
        "#2E86DE",
        "#5F27CD",
        "#F368E0",
        "#10AC84"
    ]

    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32
    static let spacingXXL: CGFloat = 48

    // MARK: - Corner Radius
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16
    static let cornerRadiusXL: CGFloat = 26
    static let cornerRadiusFull: CGFloat = 28

    // MARK: - Typography
    static func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundColor(textSecondary)
    }
}

// MARK: - Glass

extension View {
    /// Liquid Glass on macOS 26 and later; a frosted material with a lit edge before that.
    /// Meant for controls that float above content, not for content itself.
    @ViewBuilder
    func glassSurface<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            background(tint ?? Color.clear, in: shape)
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(AppTheme.edgeHighlight, lineWidth: 1))
        }
    }

    /// Groups neighbouring glass so it renders in one pass and can blend together (macOS 26+).
    @ViewBuilder
    func glassGroup(spacing: CGFloat? = nil) -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { self }
        } else {
            self
        }
    }

    /// Translucent content card. Content stays off the glass layer, so cards use a soft
    /// tint and a lit hairline rather than stacking glass on glass.
    func cardSurface(
        cornerRadius: CGFloat = AppTheme.cornerRadiusLarge,
        fill: Color = AppTheme.surface
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(fill, in: shape)
            .overlay(shape.strokeBorder(AppTheme.edgeHighlight, lineWidth: 1))
    }

    /// Recessed field background for text inputs.
    func fieldSurface(cornerRadius: CGFloat = AppTheme.cornerRadiusMedium, isFocused: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(AppTheme.surfaceMuted, in: shape)
            .overlay(shape.strokeBorder(isFocused ? AppTheme.highlight : AppTheme.border, lineWidth: 1))
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    /// Soft highlight while the pointer is over the view.
    func hoverHighlight(cornerRadius: CGFloat = AppTheme.cornerRadiusMedium) -> some View {
        modifier(HoverHighlight(cornerRadius: cornerRadius))
    }

    /// Rolls changing digits instead of swapping them (macOS 14+).
    @ViewBuilder
    func numericTextTransition() -> some View {
        if #available(macOS 14.0, *) {
            contentTransition(.numericText())
        } else {
            self
        }
    }
}

private struct HoverHighlight: ViewModifier {
    let cornerRadius: CGFloat
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.05 : 0))
                    .allowsHitTesting(false)
            )
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.12)) {
                    isHovered = hovering
                }
            }
    }
}

/// Button drawn on glass, with a light press response on every macOS version.
struct AppGlassButtonStyle<S: Shape>: ButtonStyle {
    var shape: S
    var tint: Color?

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(shape)
            .glassSurface(in: shape, tint: tint, interactive: true)
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == AppGlassButtonStyle<Capsule> {
    static func glassCapsule(tint: Color? = nil) -> Self {
        AppGlassButtonStyle(shape: Capsule(style: .continuous), tint: tint)
    }
}

extension ButtonStyle where Self == AppGlassButtonStyle<Circle> {
    static func glassCircle(tint: Color? = nil) -> Self {
        AppGlassButtonStyle(shape: Circle(), tint: tint)
    }
}

extension ButtonStyle where Self == AppGlassButtonStyle<RoundedRectangle> {
    static func glassRounded(_ cornerRadius: CGFloat = AppTheme.cornerRadiusMedium, tint: Color? = nil) -> Self {
        AppGlassButtonStyle(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), tint: tint)
    }
}

// MARK: - Shared Components

/// The window background: a behind-window blur, deepened slightly so text stays legible.
struct AppBackdrop: View {
    var body: some View {
        ZStack {
            #if canImport(AppKit)
            WindowGlassBackground()
            #endif

            LinearGradient(
                colors: [AppTheme.canvas.opacity(0.45), AppTheme.canvas.opacity(0.70)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

/// Small status light; pulses while active.
struct PulsingDot: View {
    var color: Color = AppTheme.recording
    var isActive: Bool
    var size: CGFloat = 8

    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(isActive ? color : AppTheme.textTertiary)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(color.opacity(isActive ? 0.45 : 0))
                    .scaleEffect(isPulsing ? 2.4 : 1)
                    .opacity(isPulsing ? 0 : 1)
            )
            .onAppear(perform: updatePulse)
            .onChange(of: isActive) { _ in updatePulse() }
    }

    private func updatePulse() {
        guard isActive else {
            isPulsing = false
            return
        }

        isPulsing = false
        withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
            isPulsing = true
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    var hexString: String {
        guard let components = rgbComponents else { return "#000000" }
        let r = Int(components.red * 255)
        let g = Int(components.green * 255)
        let b = Int(components.blue * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    var hsbComponents: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat)? {
        guard let rgb = rgbComponents else { return nil }

        let r = rgb.red
        let g = rgb.green
        let b = rgb.blue

        let maxValue = max(r, g, b)
        let minValue = min(r, g, b)
        let delta = maxValue - minValue

        let brightness = maxValue
        let saturation = maxValue == 0 ? 0 : delta / maxValue

        let hue: CGFloat
        if delta == 0 {
            hue = 0
        } else if maxValue == r {
            hue = (((g - b) / delta).truncatingRemainder(dividingBy: 6)) / 6
        } else if maxValue == g {
            hue = (((b - r) / delta) + 2) / 6
        } else {
            hue = (((r - g) / delta) + 4) / 6
        }

        return (hue < 0 ? hue + 1 : hue, saturation, brightness)
    }

    private var rgbComponents: (red: CGFloat, green: CGFloat, blue: CGFloat)? {
        #if canImport(UIKit)
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let cgColor = UIColor(self).cgColor.converted(
                to: colorSpace,
                intent: .defaultIntent,
                options: nil
            ),
            let components = cgColor.components
        else {
            return nil
        }
        #elseif canImport(AppKit)
        guard
            let color = NSColor(self).usingColorSpace(.sRGB),
            let components = color.cgColor.components
        else {
            return nil
        }
        #else
        return nil
        #endif

        switch components.count {
        case 2:
            return (components[0], components[0], components[0])
        case 3...:
            return (components[0], components[1], components[2])
        default:
            return nil
        }
    }
}
