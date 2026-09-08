import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-icon.swift <output.png>\n", stderr)
    exit(2)
}

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

NSColor(red: 0.075, green: 0.078, blue: 0.082, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 220, yRadius: 220).fill()

NSColor(red: 0.135, green: 0.142, blue: 0.145, alpha: 1).setFill()
NSBezierPath(
    roundedRect: NSRect(x: 92, y: 92, width: 840, height: 840),
    xRadius: 168,
    yRadius: 168
).fill()

let braces = "{ }" as NSString
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 410, weight: .bold),
    .foregroundColor: NSColor(red: 0.31, green: 0.82, blue: 0.59, alpha: 1),
    .paragraphStyle: paragraph
]
braces.draw(
    in: NSRect(x: 70, y: 250, width: 884, height: 520),
    withAttributes: attributes
)

NSColor(red: 0.96, green: 0.70, blue: 0.28, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 742, y: 746, width: 92, height: 92)).fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to render icon\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
