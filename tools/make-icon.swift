// Draws the app icon. Usage: swift tools/make-icon.swift Resources/AppIcon.icns
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns"
let px = 1024

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let gctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = gctx
let cg = gctx.cgContext
let space = CGColorSpaceCreateDeviceRGB()

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}

// Icon body: standard macOS margin and corner radius.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: rgb(0, 0, 0, 0.35))
cg.addPath(bodyPath); cg.setFillColor(rgb(0.3, 0.4, 0.9)); cg.fillPath()
cg.restoreGState()

cg.saveGState()
cg.addPath(bodyPath); cg.clip()
let bg = CGGradient(colorsSpace: space,
                    colors: [rgb(0.30, 0.58, 1.00), rgb(0.43, 0.27, 0.90)] as CFArray,
                    locations: [0, 1])!
cg.drawLinearGradient(bg, start: CGPoint(x: 200, y: 924), end: CGPoint(x: 824, y: 100), options: [])
let sheen = CGGradient(colorsSpace: space,
                       colors: [rgb(1, 1, 1, 0.22), rgb(1, 1, 1, 0)] as CFArray,
                       locations: [0, 1])!
cg.drawLinearGradient(sheen, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 560), options: [])
cg.restoreGState()

// Stopwatch
let c = CGPoint(x: 512, y: 480)
let r: CGFloat = 270

// Top button and stem (drawn first so the face overlaps them).
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -8), blur: 16, color: rgb(0, 0, 0, 0.25))
cg.setFillColor(rgb(1, 1, 1))
cg.addPath(CGPath(roundedRect: CGRect(x: 484, y: c.y + r - 20, width: 56, height: 70),
                  cornerWidth: 8, cornerHeight: 8, transform: nil))
cg.fillPath()
cg.addPath(CGPath(roundedRect: CGRect(x: 446, y: c.y + r + 36, width: 132, height: 44),
                  cornerWidth: 22, cornerHeight: 22, transform: nil))
cg.fillPath()
cg.restoreGState()

// Side button at the upper right.
cg.saveGState()
cg.translateBy(x: c.x, y: c.y)
cg.rotate(by: -.pi / 4)
cg.setShadow(offset: CGSize(width: 0, height: -6), blur: 12, color: rgb(0, 0, 0, 0.25))
cg.setFillColor(rgb(1, 1, 1, 0.95))
cg.addPath(CGPath(roundedRect: CGRect(x: -28, y: r + 2, width: 56, height: 46),
                  cornerWidth: 14, cornerHeight: 14, transform: nil))
cg.fillPath()
cg.restoreGState()

// Face
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -16), blur: 30, color: rgb(0, 0, 0, 0.30))
cg.setFillColor(rgb(1, 1, 1))
cg.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
cg.restoreGState()

let faceGrad = CGGradient(colorsSpace: space,
                          colors: [rgb(1, 1, 1), rgb(0.93, 0.94, 0.99)] as CFArray,
                          locations: [0, 1])!
cg.saveGState()
cg.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)); cg.clip()
cg.drawLinearGradient(faceGrad, start: CGPoint(x: c.x, y: c.y + r), end: CGPoint(x: c.x, y: c.y - r), options: [])
cg.restoreGState()

// Elapsed wedge
let handAngle: CGFloat = 55 * .pi / 180          // clockwise from 12 o'clock
let coral = rgb(0.96, 0.36, 0.42)
cg.saveGState()
cg.setFillColor(rgb(0.96, 0.36, 0.42, 0.16))
cg.move(to: c)
cg.addArc(center: c, radius: r - 34, startAngle: .pi / 2, endAngle: .pi / 2 - handAngle, clockwise: true)
cg.closePath()
cg.fillPath()
cg.restoreGState()

// Ticks
for i in 0..<60 {
    let major = i % 5 == 0
    let a = CGFloat(i) * (.pi / 30)
    let outer = r - 26, inner = outer - (major ? 40 : 18)
    cg.setStrokeColor(major ? rgb(0.30, 0.34, 0.55) : rgb(0.62, 0.66, 0.80))
    cg.setLineWidth(major ? 12 : 6)
    cg.setLineCap(.round)
    cg.move(to: CGPoint(x: c.x + sin(a) * inner, y: c.y + cos(a) * inner))
    cg.addLine(to: CGPoint(x: c.x + sin(a) * outer, y: c.y + cos(a) * outer))
    cg.strokePath()
}

// Hand
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -6), blur: 10, color: rgb(0.5, 0.1, 0.2, 0.35))
cg.setStrokeColor(coral)
cg.setLineWidth(22)
cg.setLineCap(.round)
cg.move(to: CGPoint(x: c.x - sin(handAngle) * 40, y: c.y - cos(handAngle) * 40))
cg.addLine(to: CGPoint(x: c.x + sin(handAngle) * 175, y: c.y + cos(handAngle) * 175))
cg.strokePath()
cg.restoreGState()

cg.setFillColor(coral)
cg.fillEllipse(in: CGRect(x: c.x - 30, y: c.y - 30, width: 60, height: 60))
cg.setFillColor(rgb(1, 1, 1))
cg.fillEllipse(in: CGRect(x: c.x - 11, y: c.y - 11, width: 22, height: 22))

NSGraphicsContext.current = nil

// Write PNG, build the iconset, convert to .icns
let fm = FileManager.default
let tmp = NSTemporaryDirectory() + "stopwatch-icon-\(getpid())"
let iconset = tmp + "/AppIcon.iconset"
try fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)
let master = tmp + "/master.png"
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: master))

func run(_ args: [String]) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: args[0])
    p.arguments = Array(args.dropFirst())
    p.standardOutput = FileHandle.nullDevice
    try! p.run(); p.waitUntilExit()
    precondition(p.terminationStatus == 0, "failed: \(args)")
}

for base in [16, 32, 128, 256, 512] {
    run(["/usr/bin/sips", "-z", "\(base)", "\(base)", master, "--out", "\(iconset)/icon_\(base)x\(base).png"])
    run(["/usr/bin/sips", "-z", "\(base * 2)", "\(base * 2)", master, "--out", "\(iconset)/icon_\(base)x\(base)@2x.png"])
}
run(["/usr/bin/iconutil", "-c", "icns", iconset, "-o", outPath])
try? fm.copyItem(atPath: master, toPath: (outPath as NSString).deletingPathExtension + ".png")
try? fm.removeItem(atPath: tmp)
print("Wrote \(outPath)")
