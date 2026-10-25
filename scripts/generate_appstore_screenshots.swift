#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: "/Users/sebas/Documents/loopline")
let rawDir = root.appendingPathComponent("docs/screenshots")
let outRoot = root.appendingPathComponent("build/appstore_screenshots")

struct Accent {
    let dot: NSColor
    let pillBg: NSColor
}

let accents: [Accent] = [
    Accent(dot: NSColor(srgbRed: 37/255, green: 99/255, blue: 235/255, alpha: 1),
           pillBg: NSColor(srgbRed: 201/255, green: 237/255, blue: 248/255, alpha: 1)),
    Accent(dot: NSColor(srgbRed: 16/255, green: 185/255, blue: 129/255, alpha: 1),
           pillBg: NSColor(srgbRed: 209/255, green: 250/255, blue: 229/255, alpha: 1)),
    Accent(dot: NSColor(srgbRed: 245/255, green: 158/255, blue: 11/255, alpha: 1),
           pillBg: NSColor(srgbRed: 254/255, green: 243/255, blue: 199/255, alpha: 1)),
    Accent(dot: NSColor(srgbRed: 239/255, green: 68/255, blue: 68/255, alpha: 1),
           pillBg: NSColor(srgbRed: 254/255, green: 226/255, blue: 226/255, alpha: 1)),
    Accent(dot: NSColor(srgbRed: 99/255, green: 102/255, blue: 241/255, alpha: 1),
           pillBg: NSColor(srgbRed: 224/255, green: 231/255, blue: 255/255, alpha: 1)),
]

struct SceneMeta {
    let index: Int
    let badge: String
    let title: String
    let subtitle: String
}

let scenesByLocale: [String: [SceneMeta]] = [
    "es-MX": [
        SceneMeta(index: 1, badge: "01 · ESTUDIO EN IPHONE E IPAD", title: "Cada parte. Todo tú.", subtitle: "Graba voces o instrumentos con metrónomo visual, cuenta regresiva y monitoreo local."),
        SceneMeta(index: 2, badge: "02 · VISTA PREVIA REAL Y COMPLETA", title: "Previsualiza tu arreglo.", subtitle: "Reproduce tu mosaico multipista completo en 9:16, 1:1 o 16:9 antes de exportar."),
        SceneMeta(index: 3, badge: "03 · SINCRONIZACIÓN AL MILISEGUNDO", title: "Mejor en conjunto.", subtitle: "Alinea tus pistas con Sync Assist automático o ajusta cada voz con precisión."),
        SceneMeta(index: 4, badge: "04 · ENCUADRE TÁCTIL Y ORDEN DE VOCES", title: "Encuadra cada toma.", subtitle: "Cambia el orden de los marcos, arrastra para encuadrar y haz zoom en cada video."),
        SceneMeta(index: 5, badge: "05 · 100 % EN TU DISPOSITIVO", title: "Tus sesiones, contigo.", subtitle: "Organiza tus proyectos multipista sin cuentas, sin nube y con privacidad total.")
    ],
    "en-US": [
        SceneMeta(index: 1, badge: "01 · IPHONE & IPAD STUDIO", title: "Every part. All you.", subtitle: "Record vocals or instruments with visual count-in, metronome, and local monitoring."),
        SceneMeta(index: 2, badge: "02 · REAL & FULL VIDEO PREVIEW", title: "Preview before export.", subtitle: "Play back your complete multi-track collage in 9:16, 1:1, or 16:9 before rendering."),
        SceneMeta(index: 3, badge: "03 · MILLISECOND SYNC ASSIST", title: "Better together.", subtitle: "Align every take automatically with Sync Assist or nudge timing by milliseconds."),
        SceneMeta(index: 4, badge: "04 · TOUCH CROP & VOICE REORDERING", title: "Frame every performance.", subtitle: "Reorder voice slots and drag or pinch inside any frame in the enlarged Touch Crop canvas."),
        SceneMeta(index: 5, badge: "05 · 100% ON-DEVICE PRIVACY", title: "Your sessions, saved locally.", subtitle: "Manage multi-part arrangements offline with zero accounts, zero cloud, and zero tracking.")
    ]
]

let bgColor = NSColor(srgbRed: 244/255, green: 245/255, blue: 242/255, alpha: 1)
let inkPrimary = NSColor(srgbRed: 29/255, green: 32/255, blue: 31/255, alpha: 1)
let inkSecondary = NSColor(srgbRed: 82/255, green: 88/255, blue: 86/255, alpha: 1)

func renderPoster(
    width: Int,
    height: Int,
    rawURL: URL,
    meta: SceneMeta,
    accent: Accent,
    isIPad: Bool,
    outURL: URL
) throws {
    guard let rawImage = NSImage(contentsOf: rawURL),
          let rawCG = rawImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw NSError(domain: "ScreenshotGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load \(rawURL.path)"])
    }

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        throw NSError(domain: "ScreenshotGen", code: 2, userInfo: nil)
    }

    let W = CGFloat(width)
    let H = CGFloat(height)

    ctx.translateBy(x: 0, y: H)
    ctx.scaleBy(x: 1, y: -1)

    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: true)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx

    // Fill background
    bgColor.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: W, height: H)).fill()

    let marginX: CGFloat = isIPad ? 140 : 84
    var cursorY: CGFloat = isIPad ? 92 : 88

    let badgeFont = NSFont.monospacedSystemFont(ofSize: isIPad ? 28 : 25, weight: .medium)
    let titleFont = NSFont.systemFont(ofSize: isIPad ? 80 : 68, weight: .bold)
    let subFont = NSFont.systemFont(ofSize: isIPad ? 42 : 36, weight: .regular)

    // 1. Pill badge
    let badgeAttrs: [NSAttributedString.Key: Any] = [
        .font: badgeFont,
        .foregroundColor: inkPrimary,
        .kern: 1.2
    ]
    let badgeStr = NSAttributedString(string: meta.badge, attributes: badgeAttrs)
    let badgeSize = badgeStr.size()
    let pillH: CGFloat = isIPad ? 64 : 58
    let pillW: CGFloat = badgeSize.width + 86

    let pillRect = NSRect(x: marginX, y: cursorY, width: pillW, height: pillH)
    accent.pillBg.setFill()
    NSBezierPath(roundedRect: pillRect, xRadius: pillH / 2, yRadius: pillH / 2).fill()

    let dotR: CGFloat = 10
    let dotRect = NSRect(x: marginX + 22, y: cursorY + (pillH - dotR * 2) / 2, width: dotR * 2, height: dotR * 2)
    accent.dot.setFill()
    NSBezierPath(ovalIn: dotRect).fill()

    badgeStr.draw(at: NSPoint(x: marginX + 54, y: cursorY + (pillH - badgeSize.height) / 2))
    cursorY += pillH + 26

    // 2. Title
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: titleFont,
        .foregroundColor: inkPrimary,
        .kern: -1.4
    ]
    let titleStr = NSAttributedString(string: meta.title, attributes: titleAttrs)
    let titleSize = titleStr.size()
    titleStr.draw(at: NSPoint(x: marginX, y: cursorY))
    cursorY += titleSize.height + 16

    // 3. Subtitle wrapped
    let para = NSMutableParagraphStyle()
    para.lineSpacing = 6
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: inkSecondary,
        .paragraphStyle: para
    ]
    let maxTextW = W - marginX * 2
    let subStr = NSAttributedString(string: meta.subtitle, attributes: subAttrs)
    let subBounds = subStr.boundingRect(
        with: NSSize(width: maxTextW, height: 400),
        options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    subStr.draw(
        with: NSRect(x: marginX, y: cursorY, width: maxTextW, height: ceil(subBounds.height) + 12),
        options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    cursorY += ceil(subBounds.height) + (isIPad ? 46 : 42)

    // 4. Device Bezel + Raw Screenshot
    let bottomMargin: CGFloat = isIPad ? 64 : 56
    let availH = H - cursorY - bottomMargin
    let availW = W - marginX * 2
    let bezelPad: CGFloat = isIPad ? 26 : 22

    let rawW = CGFloat(rawCG.width)
    let rawH = CGFloat(rawCG.height)
    let scale = min((availW - bezelPad * 2) / rawW, (availH - bezelPad * 2) / rawH)
    let screenW = round(rawW * scale)
    let screenH = round(rawH * scale)

    let bezelW = screenW + bezelPad * 2
    let bezelH = screenH + bezelPad * 2
    let bezelX = round((W - bezelW) / 2)
    let bezelY = round(cursorY + (availH - bezelH) / 2)

    let outerRadius: CGFloat = isIPad ? 54 : 68
    let innerRadius: CGFloat = isIPad ? 36 : 50

    // Soft shadow + outer bezel
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.shadowBlurRadius = 36
    shadow.shadowColor = NSColor(srgbRed: 15/255, green: 23/255, blue: 42/255, alpha: 0.20)
    shadow.set()

    let bezelRect = NSRect(x: bezelX, y: bezelY, width: bezelW, height: bezelH)
    let bezelPath = NSBezierPath(roundedRect: bezelRect, xRadius: outerRadius, yRadius: outerRadius)
    NSColor(srgbRed: 26/255, green: 28/255, blue: 30/255, alpha: 1).setFill()
    bezelPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Subtle bezel border
    NSColor(srgbRed: 68/255, green: 72/255, blue: 76/255, alpha: 1).setStroke()
    bezelPath.lineWidth = 3
    bezelPath.stroke()

    // Clip inner screen and draw CGImage (unflipped inside CGContext or via NSImage)
    NSGraphicsContext.saveGraphicsState()
    let screenRect = NSRect(x: bezelX + bezelPad, y: bezelY + bezelPad, width: screenW, height: screenH)
    let screenClip = NSBezierPath(roundedRect: screenRect, xRadius: innerRadius, yRadius: innerRadius)
    screenClip.addClip()

    nsCtx.imageInterpolation = .high
    rawImage.draw(
        in: screenRect,
        from: NSRect(x: 0, y: 0, width: rawImage.size.width, height: rawImage.size.height),
        operation: .copy,
        fraction: 1.0,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()

    guard let outCG = ctx.makeImage() else {
        throw NSError(domain: "ScreenshotGen", code: 3, userInfo: nil)
    }
    let rep = NSBitmapImageRep(cgImage: outCG)
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ScreenshotGen", code: 4, userInfo: nil)
    }
    try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try pngData.write(to: outURL)
}

let fm = FileManager.default
try? fm.removeItem(at: rawDir.appendingPathComponent("capture.png"))
try? fm.removeItem(at: rawDir.appendingPathComponent("export.png"))
try? fm.removeItem(at: rawDir.appendingPathComponent("mix.png"))
try fm.copyItem(at: rawDir.appendingPathComponent("iphone_scene_1.png"), to: rawDir.appendingPathComponent("capture.png"))
try fm.copyItem(at: rawDir.appendingPathComponent("iphone_scene_2.png"), to: rawDir.appendingPathComponent("export.png"))
try fm.copyItem(at: rawDir.appendingPathComponent("iphone_scene_3.png"), to: rawDir.appendingPathComponent("mix.png"))

for (locale, list) in scenesByLocale {
    for (idx, meta) in list.enumerated() {
        let accent = accents[idx]
        let s = meta.index
        let iphoneRaw = rawDir.appendingPathComponent("iphone_scene_\(s).png")
        let ipadRaw = rawDir.appendingPathComponent("ipad_scene_\(s).png")

        let iphoneOut = outRoot.appendingPathComponent("\(locale)/0\(s)_iphone67.png")
        let ipadOut = outRoot.appendingPathComponent("\(locale)/0\(s)_ipad129.png")

        try renderPoster(width: 1290, height: 2796, rawURL: iphoneRaw, meta: meta, accent: accent, isIPad: false, outURL: iphoneOut)
        try renderPoster(width: 2064, height: 2752, rawURL: ipadRaw, meta: meta, accent: accent, isIPad: true, outURL: ipadOut)
        print("[\(locale)] Generated 0\(s)_iphone67.png & 0\(s)_ipad129.png")
    }
}
