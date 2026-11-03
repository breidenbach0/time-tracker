// Draws the disk image's window background: TimeTracker's off-white (#F5F5F7, the colour of its
// Start button), an arrow from where the app sits to where Applications sits, and a line of
// instructions. Light, because Finder always draws icon names in black on a custom background.
// Usage: swiftc scripts/dmg/make-background.swift -o build/make-background
//        build/make-background scripts/dmg/background.png 1   (and 2 for @2x)
import AppKit

let arguments = CommandLine.arguments
let output = URL(fileURLWithPath: arguments[1])
let scale = CGFloat(Double(arguments[2]) ?? 1)
let size = NSSize(width: 660, height: 400)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSColor(srgbRed: 0xF5 / 255.0, green: 0xF5 / 255.0, blue: 0xF7 / 255.0, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()

// Finder places icons by their centre, measured from the top: the app at (170, 190) and
// Applications at (490, 190). AppKit measures from the bottom.
let arrowY = size.height - 190
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 262, y: arrowY))
arrow.line(to: NSPoint(x: 398, y: arrowY))
arrow.move(to: NSPoint(x: 384, y: arrowY + 12))
arrow.line(to: NSPoint(x: 398, y: arrowY))
arrow.line(to: NSPoint(x: 384, y: arrowY - 12))
arrow.lineWidth = 3
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
let ink = NSColor(srgbRed: 0x11 / 255.0, green: 0x11 / 255.0, blue: 0x14 / 255.0, alpha: 1)
ink.withAlphaComponent(0.3).setStroke()
arrow.stroke()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let title = NSAttributedString(string: "Drag TimeTracker to Applications", attributes: [
    .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
    .foregroundColor: ink.withAlphaComponent(0.85),
    .paragraphStyle: paragraph,
])
let detail = NSAttributedString(string: "Then open it from your Applications folder.", attributes: [
    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
    .foregroundColor: ink.withAlphaComponent(0.5),
    .paragraphStyle: paragraph,
])
title.draw(in: NSRect(x: 0, y: 72, width: size.width, height: 22))
detail.draw(in: NSRect(x: 0, y: 52, width: size.width, height: 18))

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: output)
