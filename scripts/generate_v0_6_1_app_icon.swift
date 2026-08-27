import AppKit

private let canvasSize = 1024
private let outputPath = CommandLine.arguments.dropFirst().first ?? "LifeRoute/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: canvasSize,
    pixelsHigh: canvasSize,
    bitsPerSample: 8,
    samplesPerPixel: 3,
    hasAlpha: false,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 24
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Could not create LifeRoute icon drawing context")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high

let canvas = NSRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.010, green: 0.035, blue: 0.082, alpha: 1),
    NSColor(calibratedRed: 0.020, green: 0.085, blue: 0.165, alpha: 1),
    NSColor(calibratedRed: 0.015, green: 0.045, blue: 0.095, alpha: 1),
])!
background.draw(in: canvas, angle: 115)

// Subtle premium map/street texture behind the LR mark.
let mapLine = NSColor(calibratedRed: 0.18, green: 0.43, blue: 0.72, alpha: 0.15)
mapLine.setStroke()
for x in stride(from: 105.0, through: 920.0, by: 135.0) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: x, y: 70))
    path.line(to: NSPoint(x: x + 58, y: 954))
    path.lineWidth = 8
    path.lineCapStyle = .round
    path.stroke()
}
for y in stride(from: 120.0, through: 890.0, by: 150.0) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 66, y: y))
    path.curve(
        to: NSPoint(x: 960, y: y + 35),
        controlPoint1: NSPoint(x: 300, y: y + 55),
        controlPoint2: NSPoint(x: 690, y: y - 45)
    )
    path.lineWidth = 7
    path.lineCapStyle = .round
    path.stroke()
}

// Cool-blue route layer gives the icon the navigation identity of the newer LR artwork.
let blueRoute = NSBezierPath()
blueRoute.move(to: NSPoint(x: 95, y: 185))
blueRoute.curve(
    to: NSPoint(x: 510, y: 515),
    controlPoint1: NSPoint(x: 260, y: 208),
    controlPoint2: NSPoint(x: 340, y: 410)
)
blueRoute.curve(
    to: NSPoint(x: 905, y: 780),
    controlPoint1: NSPoint(x: 690, y: 610),
    controlPoint2: NSPoint(x: 760, y: 742)
)
NSColor(calibratedRed: 0.10, green: 0.47, blue: 0.84, alpha: 0.42).setStroke()
blueRoute.lineWidth = 34
blueRoute.lineCapStyle = .round
blueRoute.stroke()

// Gold inner rim: strong at Home Screen size without competing with the monogram.
let rim = NSBezierPath(roundedRect: NSRect(x: 42, y: 42, width: 940, height: 940), xRadius: 190, yRadius: 190)
NSColor(calibratedRed: 0.88, green: 0.60, blue: 0.15, alpha: 0.92).setStroke()
rim.lineWidth = 14
rim.stroke()

let darkGold = NSColor(calibratedRed: 0.56, green: 0.34, blue: 0.07, alpha: 1)
let gold = NSColor(calibratedRed: 0.94, green: 0.67, blue: 0.18, alpha: 1)
let brightGold = NSColor(calibratedRed: 1.00, green: 0.84, blue: 0.43, alpha: 1)
let navy = NSColor(calibratedRed: 0.012, green: 0.040, blue: 0.085, alpha: 1)

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let monogramFont = NSFont.systemFont(ofSize: 505, weight: .black)
let monogramRect = NSRect(x: 46, y: 212, width: 932, height: 590)

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.58)
shadow.shadowOffset = NSSize(width: 0, height: -20)
shadow.shadowBlurRadius = 24

("LR" as NSString).draw(
    in: monogramRect.offsetBy(dx: 0, dy: -10),
    withAttributes: [
        .font: monogramFont,
        .foregroundColor: darkGold,
        .paragraphStyle: paragraph,
        .shadow: shadow,
    ]
)
("LR" as NSString).draw(
    in: monogramRect,
    withAttributes: [
        .font: monogramFont,
        .foregroundColor: gold,
        .paragraphStyle: paragraph,
    ]
)
("LR" as NSString).draw(
    in: monogramRect.offsetBy(dx: 0, dy: 8),
    withAttributes: [
        .font: monogramFont,
        .foregroundColor: brightGold.withAlphaComponent(0.32),
        .paragraphStyle: paragraph,
    ]
)

// Gold route ribbon rising into the center navigation pin.
let goldRoute = NSBezierPath()
goldRoute.move(to: NSPoint(x: 190, y: 220))
goldRoute.curve(
    to: NSPoint(x: 510, y: 470),
    controlPoint1: NSPoint(x: 385, y: 255),
    controlPoint2: NSPoint(x: 355, y: 420)
)
brightGold.setStroke()
goldRoute.lineWidth = 30
goldRoute.lineCapStyle = .round
goldRoute.stroke()

let pinCenter = NSPoint(x: 515, y: 575)
let pinCircle = NSBezierPath(ovalIn: NSRect(x: pinCenter.x - 72, y: pinCenter.y - 25, width: 144, height: 144))
brightGold.setFill()
pinCircle.fill()

let pinTail = NSBezierPath()
pinTail.move(to: NSPoint(x: pinCenter.x - 52, y: pinCenter.y + 5))
pinTail.line(to: NSPoint(x: pinCenter.x, y: pinCenter.y - 92))
pinTail.line(to: NSPoint(x: pinCenter.x + 52, y: pinCenter.y + 5))
pinTail.close()
brightGold.setFill()
pinTail.fill()

let pinHole = NSBezierPath(ovalIn: NSRect(x: pinCenter.x - 27, y: pinCenter.y + 20, width: 54, height: 54))
navy.setFill()
pinHole.fill()

// Controlled top-left sheen for a metallic, premium finish.
let sheen = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.10),
    NSColor.white.withAlphaComponent(0.0),
])!
sheen.draw(in: NSRect(x: 86, y: 590, width: 730, height: 320), angle: 305)

NSGraphicsContext.restoreGraphicsState()

let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode LifeRoute v0.6.1 icon as PNG")
}
try png.write(to: outputURL, options: .atomic)
print("Generated LifeRoute v0.6.1 premium navy/gold LR app icon at \(outputPath)")
