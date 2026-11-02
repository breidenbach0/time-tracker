import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct AppTheme {
    // MARK: - Colors
    #if canImport(AppKit)
    static let primary = Color(nsColor: .windowBackgroundColor)
    #else
    static let primary = Color(hex: "#333333")
    #endif
    static let secondary = Color(hex: "#353535")
    static let accent = Color(hex: "#F2F2F2")
    static let accentBlue = Color(hex: "#F5F5F5")
    static let accentMint = Color(hex: "#DADADA")
    static let accentWarm = Color(hex: "#C8C8C8")
    static let accentRose = Color(hex: "#B0B0B0")
    static let success = Color(hex: "#D9D9D9")
    static let danger = Color(hex: "#9C9C9C")
    static let textPrimary = Color(hex: "#FAFAFA")
    static let textSecondary = Color(hex: "#BCBCBC")
    static let surface = Color(hex: "#404040")
    static let surfaceAlt = Color(hex: "#4A4A4A")
    static let surfaceMuted = Color(hex: "#2C2C2C")
    static let border = Color.white.opacity(0.09)

    static let heroGradient = LinearGradient(
        colors: [Color(hex: "#333333"), Color(hex: "#363636"), Color(hex: "#303030")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [Color(hex: "#424242"), Color(hex: "#353535")],
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
    static let cornerRadiusFull: CGFloat = 28
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
