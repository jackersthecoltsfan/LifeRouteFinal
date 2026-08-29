#!/usr/bin/env swift
import AppKit

// LifeRoute v0.7.0 official identity: refined 1E/1F hybrid.
// Full square artwork only; iOS supplies the final platform icon mask.
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

let navyDeep = color(0x020713)
let navyMid = color(0x06172f)
let navyLift = color(0x0b2d55)
let topoBlue = color(0x27527e, alpha: 0.32)
let mountainBack = color(0x102d4a)
let mountainFront = color(0x06182a)
let goldDeep = color(0x8b5814)
let gold = color(0xdca43a)
let goldLight = color(0xffdc72)
let goldHot = color(0xffefae)

let image = NSImage(size: size)
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("Missing graphics context") }
ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)

let full = NSRect(origin: .zero, size: size)

// Fully opaque deep-navy field. No baked transparent/rounded app-icon mask.
navyDeep.setFill()
NSBezierPath(rect: full).fill()
let background = NSGradient(colors: [navyDeep, navyMid, navyLift, navyDeep])!
background.draw(in: full, angle: -76)

// Very broad illumination keeps the mark dimensional without sacrificing small-size contrast.
let glow = NSBezierPath(ovalIn: NSRect(x: 170, y: 330, width: 720, height: 720))
ctx.saveGState()
glow.addClip()
NSGradient(colors: [color(0x0d3762, alpha: 0.04), color(0x164e7c, alpha: 0.34), .clear])!.draw(fromCenter: NSPoint(x: 610, y: 650), radius: 20, toCenter: NSPoint(x: 610, y: 650), radius: 420, options: [])
ctx.restoreGState()

// Subtle map intelligence layer: deliberately sparse so it survives downsampling cleanly.
ctx.saveGState()
topoBlue.setStroke()
for index in 0..<7 {
    let path = NSBezierPath()
    path.lineWidth = index.isMultiple(of: 3) ? 4.0 : 2.2
    let y = CGFloat(150 + index * 112)
    path.move(to: NSPoint(x: -80, y: y))
    path.curve(
        to: NSPoint(x: 1110, y: y + CGFloat((index % 3 - 1) * 38)),
        controlPoint1: NSPoint(x: 250, y: y + CGFloat((index % 2 == 0) ? 56 : -42)),
        controlPoint2: NSPoint(x: 720, y: y + CGFloat((index % 2 == 0) ? -46 : 60))
    )
    path.stroke()
}
for index in 0..<5 {
    let path = NSBezierPath()
    path.lineWidth = 2.2
    let x = CGFloat(130 + index * 195)
    path.move(to: NSPoint(x: x, y: -60))
    path.curve(
        to: NSPoint(x: x + CGFloat((index % 2 == 0) ? 80 : -70), y: 1100),
        controlPoint1: NSPoint(x: x + 65, y: 280),
        controlPoint2: NSPoint(x: x - 55, y: 730)
    )
    path.stroke()
}
ctx.restoreGState()

// Topographic contour accents: a few organic lines rather than noisy micro-detail.
ctx.saveGState()
color(0x365f87, alpha: 0.34).setStroke()
for ring in 0..<5 {
    let inset = CGFloat(118 + ring * 38)
    let contour = NSBezierPath(ovalIn: NSRect(x: inset, y: 390 + CGFloat(ring * 15), width: 1024 - inset * 2, height: 360 - CGFloat(ring * 34)))
    contour.lineWidth = 2.2
    contour.stroke()
}
ctx.restoreGState()

// Distant and foreground mountain silhouettes tie the identity to journey/destination.
let backMountains = NSBezierPath()
backMountains.move(to: NSPoint(x: 0, y: 250))
backMountains.line(to: NSPoint(x: 90, y: 385))
backMountains.line(to: NSPoint(x: 205, y: 318))
backMountains.line(to: NSPoint(x: 345, y: 505))
backMountains.line(to: NSPoint(x: 470, y: 350))
backMountains.line(to: NSPoint(x: 590, y: 540))
backMountains.line(to: NSPoint(x: 720, y: 360))
backMountains.line(to: NSPoint(x: 845, y: 475))
backMountains.line(to: NSPoint(x: 1024, y: 302))
backMountains.line(to: NSPoint(x: 1024, y: 0))
backMountains.line(to: NSPoint(x: 0, y: 0))
backMountains.close()
mountainBack.setFill(); backMountains.fill()

let frontMountains = NSBezierPath()
frontMountains.move(to: NSPoint(x: 0, y: 160))
frontMountains.line(to: NSPoint(x: 150, y: 310))
frontMountains.line(to: NSPoint(x: 290, y: 205))
frontMountains.line(to: NSPoint(x: 455, y: 365))
frontMountains.line(to: NSPoint(x: 610, y: 218))
frontMountains.line(to: NSPoint(x: 780, y: 338))
frontMountains.line(to: NSPoint(x: 1024, y: 184))
frontMountains.line(to: NSPoint(x: 1024, y: 0))
frontMountains.line(to: NSPoint(x: 0, y: 0))
frontMountains.close()
mountainFront.setFill(); frontMountains.fill()

// Decorative premium gold frame, safely inset from Apple's eventual system mask.
let frame = NSBezierPath(roundedRect: full.insetBy(dx: 46, dy: 46), xRadius: 88, yRadius: 88)
frame.lineWidth = 13
gold.setStroke(); frame.stroke()
let frameHighlight = NSBezierPath(roundedRect: full.insetBy(dx: 54, dy: 54), xRadius: 80, yRadius: 80)
frameHighlight.lineWidth = 2.5
goldHot.setStroke(); frameHighlight.stroke()

func drawLetter(_ string: String, rect: NSRect) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.72)
    shadow.shadowBlurRadius = 20
    shadow.shadowOffset = NSSize(width: 0, height: -11)
    let font = NSFont(name: "Times New Roman Bold", size: 500) ?? NSFont.systemFont(ofSize: 500, weight: .black)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: goldLight,
        .paragraphStyle: paragraph,
        .shadow: shadow,
        .strokeColor: goldDeep,
        .strokeWidth: -1.8,
    ]
    NSAttributedString(string: string, attributes: attrs).draw(in: rect)
}

// Large refined LR monogram — the dominant read at Home Screen size.
drawLetter("L", rect: NSRect(x: 104, y: 272, width: 382, height: 600))
drawLetter("R", rect: NSRect(x: 505, y: 255, width: 424, height: 606))

// Integrated location pin centered between the monogram strokes.
let pin = NSBezierPath()
pin.move(to: NSPoint(x: 505, y: 568))
pin.curve(to: NSPoint(x: 438, y: 690), controlPoint1: NSPoint(x: 468, y: 616), controlPoint2: NSPoint(x: 438, y: 650))
pin.curve(to: NSPoint(x: 505, y: 790), controlPoint1: NSPoint(x: 438, y: 750), controlPoint2: NSPoint(x: 468, y: 790))
pin.curve(to: NSPoint(x: 572, y: 690), controlPoint1: NSPoint(x: 542, y: 790), controlPoint2: NSPoint(x: 572, y: 750))
pin.curve(to: NSPoint(x: 505, y: 568), controlPoint1: NSPoint(x: 572, y: 650), controlPoint2: NSPoint(x: 542, y: 616))
pin.close()
gold.setFill(); pin.fill()
pin.lineWidth = 5.5
goldHot.setStroke(); pin.stroke()
let pinHole = NSBezierPath(ovalIn: NSRect(x: 476, y: 695, width: 58, height: 58))
navyDeep.setFill(); pinHole.fill()

// Illuminated winding route rises from the foreground toward the pin/destination.
let route = NSBezierPath()
route.move(to: NSPoint(x: 255, y: 72))
route.curve(to: NSPoint(x: 392, y: 310), controlPoint1: NSPoint(x: 278, y: 150), controlPoint2: NSPoint(x: 355, y: 218))
route.curve(to: NSPoint(x: 610, y: 468), controlPoint1: NSPoint(x: 442, y: 420), controlPoint2: NSPoint(x: 585, y: 375))
route.curve(to: NSPoint(x: 505, y: 570), controlPoint1: NSPoint(x: 650, y: 520), controlPoint2: NSPoint(x: 566, y: 548))
route.lineCapStyle = .round
route.lineJoinStyle = .round
let routeGlow = route.copy() as! NSBezierPath
routeGlow.lineWidth = 72
color(0xe0a63b, alpha: 0.16).setStroke(); routeGlow.stroke()
let routeMid = route.copy() as! NSBezierPath
routeMid.lineWidth = 45
goldDeep.setStroke(); routeMid.stroke()
route.lineWidth = 30
gold.setStroke(); route.stroke()
let routeHighlight = route.copy() as! NSBezierPath
routeHighlight.lineWidth = 6
goldHot.setStroke(); routeHighlight.stroke()

image.unlockFocus()

// Encode a true opaque RGB PNG. App Store Connect rejects alpha in the 1024 AppIcon.
guard let opaqueBitmap = NSBitmapImageRep(
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
), let opaqueContext = NSGraphicsContext(bitmapImageRep: opaqueBitmap) else {
    fatalError("Could not create opaque RGB bitmap")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = opaqueContext
navyDeep.setFill(); NSBezierPath(rect: full).fill()
image.draw(in: full, from: .zero, operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

guard let png = opaqueBitmap.representation(using: .png, properties: [.compressionFactor: 1.0]) else {
    fatalError("Could not encode official LifeRoute AppIcon")
}
try png.write(to: URL(fileURLWithPath: output), options: .atomic)
print("Generated official LifeRoute refined 1E/1F hybrid AppIcon at \(output)")
