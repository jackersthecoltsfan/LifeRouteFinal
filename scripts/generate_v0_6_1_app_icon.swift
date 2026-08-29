#!/usr/bin/env swift
import AppKit

let size = CGSize(width: 1024, height: 1024)
let output = CommandLine.arguments.dropFirst().first ?? "LifeRoute/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

let navyTop = color(0x020a18)
let navyBottom = color(0x061b3a)
let navyGrid = color(0x18325c, alpha: 0.34)
let gold = color(0xe2ad43)
let goldLight = color(0xffdf78)
let goldDeep = color(0x9f6717)

let image = NSImage(size: size)
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("Missing graphics context") }
ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)

let full = NSRect(origin: .zero, size: size)

// App Store icons must be fully opaque. Paint the complete square first; iOS applies the final icon mask.
navyTop.setFill()
NSBezierPath(rect: full).fill()

// v0.6.2 safe-area refinement: keep the complete mark comfortably inside iOS's final icon mask.
let outer = NSBezierPath(roundedRect: full.insetBy(dx: 58, dy: 58), xRadius: 164, yRadius: 164)
ctx.saveGState()
outer.addClip()
let bgGradient = NSGradient(colors: [navyTop, navyBottom])!
bgGradient.draw(in: full, angle: -90)
ctx.restoreGState()

// Subtle premium map/street texture behind the LR mark.
ctx.saveGState()
outer.addClip()
navyGrid.setStroke()
for i in 0..<10 {
    let path = NSBezierPath()
    path.lineWidth = CGFloat(10 + (i % 3) * 3)
    let y = CGFloat(90 + i * 92)
    path.move(to: NSPoint(x: -80, y: y))
    path.line(to: NSPoint(x: 1100, y: y + CGFloat((i % 4 - 2) * 72)))
    path.stroke()
}
for i in 0..<9 {
    let path = NSBezierPath()
    path.lineWidth = CGFloat(9 + (i % 2) * 4)
    let x = CGFloat(70 + i * 120)
    path.move(to: NSPoint(x: x, y: -80))
    path.line(to: NSPoint(x: x + CGFloat((i % 3 - 1) * 150), y: 1100))
    path.stroke()
}
ctx.restoreGState()

// Premium beveled gold inner rim.
let border = NSBezierPath(roundedRect: full.insetBy(dx: 72, dy: 72), xRadius: 150, yRadius: 150)
border.lineWidth = 20
gold.setStroke()
border.stroke()
let innerBorder = NSBezierPath(roundedRect: full.insetBy(dx: 86, dy: 86), xRadius: 138, yRadius: 138)
innerBorder.lineWidth = 4
goldLight.setStroke()
innerBorder.stroke()

func drawLetter(_ string: String, rect: NSRect) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.65)
    shadow.shadowBlurRadius = 18
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    let font = NSFont(name: "Times New Roman Bold", size: 450) ?? NSFont.systemFont(ofSize: 450, weight: .black)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: goldLight,
        .paragraphStyle: paragraph,
        .shadow: shadow,
        .strokeColor: goldDeep,
        .strokeWidth: -1.4
    ]
    NSAttributedString(string: string, attributes: attrs).draw(in: rect)
}

drawLetter("L", rect: NSRect(x: 130, y: 236, width: 350, height: 560))
drawLetter("R", rect: NSRect(x: 512, y: 228, width: 372, height: 560))

// Location navigation pin between L and R.
let pin = NSBezierPath()
pin.move(to: NSPoint(x: 510, y: 620))
pin.curve(to: NSPoint(x: 445, y: 724), controlPoint1: NSPoint(x: 475, y: 664), controlPoint2: NSPoint(x: 445, y: 690))
pin.curve(to: NSPoint(x: 510, y: 814), controlPoint1: NSPoint(x: 445, y: 776), controlPoint2: NSPoint(x: 472, y: 814))
pin.curve(to: NSPoint(x: 575, y: 724), controlPoint1: NSPoint(x: 548, y: 814), controlPoint2: NSPoint(x: 575, y: 776))
pin.curve(to: NSPoint(x: 510, y: 620), controlPoint1: NSPoint(x: 575, y: 690), controlPoint2: NSPoint(x: 545, y: 664))
pin.close()
gold.setFill(); pin.fill()
goldLight.setStroke(); pin.lineWidth = 5; pin.stroke()
let hole = NSBezierPath(ovalIn: NSRect(x: 480, y: 730, width: 60, height: 60))
navyTop.setFill(); hole.fill()

// Gold route ribbon / S-shaped road sweeping out of the pin.
let road = NSBezierPath()
road.move(to: NSPoint(x: 510, y: 615))
road.curve(to: NSPoint(x: 620, y: 500), controlPoint1: NSPoint(x: 575, y: 586), controlPoint2: NSPoint(x: 653, y: 570))
road.curve(to: NSPoint(x: 392, y: 340), controlPoint1: NSPoint(x: 572, y: 420), controlPoint2: NSPoint(x: 422, y: 444))
road.curve(to: NSPoint(x: 265, y: 72), controlPoint1: NSPoint(x: 350, y: 220), controlPoint2: NSPoint(x: 294, y: 150))
road.lineWidth = 42
road.lineCapStyle = .round
road.lineJoinStyle = .round
gold.setStroke(); road.stroke()
let roadHighlight = road.copy() as! NSBezierPath
roadHighlight.lineWidth = 7
goldLight.setStroke(); roadHighlight.stroke()

image.unlockFocus()

// Encode as true RGB PNG with no alpha channel. Use a 32-bit aligned row while retaining only three RGB samples.
guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let opaqueBitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 3,
        hasAlpha: false,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: Int(size.width) * 4,
        bitsPerPixel: 32
      ),
      let opaqueGraphicsContext = NSGraphicsContext(bitmapImageRep: opaqueBitmap) else {
    fatalError("Could not create opaque RGB bitmap")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = opaqueGraphicsContext
navyTop.setFill()
NSBezierPath(rect: full).fill()
image.draw(in: full, from: .zero, operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

guard let png = opaqueBitmap.representation(using: .png, properties: [.compressionFactor: 1.0]) else {
    fatalError("Could not encode opaque PNG")
}

try png.write(to: URL(fileURLWithPath: output), options: .atomic)
print("Generated approved premium navy/gold LR AppIcon as opaque RGB PNG at \(output)")
