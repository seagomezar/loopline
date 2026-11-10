#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: "/Users/sebas/Documents/loopline")
let rawDir = root.appendingPathComponent("build/raw_v101")  // from scripts/capture_appstore_scenes.sh
let docsDir = root.appendingPathComponent("docs/screenshots")
let duoDir = root.appendingPathComponent("build/raw_duo")  // from scripts/capture_duo.sh
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

// Ordered as a story (Apple asset best practices): outcome first, then how you get there.
// `index` is the raw simulator scene captured by scripts/capture_appstore_scenes.sh.
let scenesByLocale: [String: [SceneMeta]] = [
    "es-MX": [
        SceneMeta(index: 7, badge: "", title: "Tu canción, en una pantalla.", subtitle: ""),
        SceneMeta(index: 1, badge: "", title: "Graba cada parte a tiempo.", subtitle: ""),
        SceneMeta(index: 4, badge: "", title: "Acomoda cada cuadro.", subtitle: ""),
        SceneMeta(index: 3, badge: "", title: "Mezcla y sincroniza.", subtitle: ""),
        SceneMeta(index: 2, badge: "", title: "Guarda y comparte.", subtitle: "")
    ],
    "en-US": [
        SceneMeta(index: 7, badge: "", title: "Your song, on one screen.", subtitle: ""),
        SceneMeta(index: 1, badge: "", title: "Record every part on time.", subtitle: ""),
        SceneMeta(index: 4, badge: "", title: "Arrange every frame.", subtitle: ""),
        SceneMeta(index: 3, badge: "", title: "Mix and sync.", subtitle: ""),
        SceneMeta(index: 2, badge: "", title: "Save and share.", subtitle: "")
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

    let marginX: CGFloat = isIPad ? 120 : 64
    var cursorY: CGFloat = isIPad ? 110 : 120

    // One short, centered caption (3-5 words) that stays legible at thumbnail size.
    let titleFont = NSFont.systemFont(ofSize: isIPad ? 104 : 92, weight: .bold)
    let titlePara = NSMutableParagraphStyle()
    titlePara.alignment = .center
    titlePara.lineSpacing = 4
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: titleFont,
        .foregroundColor: inkPrimary,
        .kern: -1.6,
        .paragraphStyle: titlePara
    ]
    let maxTextW = W - marginX * 2
    let titleStr = NSAttributedString(string: meta.title, attributes: titleAttrs)
    let titleBounds = titleStr.boundingRect(with: NSSize(width: maxTextW, height: 600),
                                            options: [.usesLineFragmentOrigin, .usesFontLeading])
    titleStr.draw(with: NSRect(x: marginX, y: cursorY, width: maxTextW, height: ceil(titleBounds.height) + 8),
                  options: [.usesLineFragmentOrigin, .usesFontLeading])
    cursorY += ceil(titleBounds.height)

    // Small accent bar under the caption keeps the brand colors without extra words.
    let barW: CGFloat = isIPad ? 120 : 96
    let barH: CGFloat = isIPad ? 12 : 10
    accent.dot.setFill()
    NSBezierPath(roundedRect: NSRect(x: (W - barW) / 2, y: cursorY + 24, width: barW, height: barH),
                 xRadius: barH / 2, yRadius: barH / 2).fill()
    cursorY += 24 + barH + (isIPad ? 56 : 56)

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
for (scene, name) in [(1, "capture.png"), (2, "export.png"), (3, "mix.png")] {
    try? fm.removeItem(at: docsDir.appendingPathComponent(name))
    try fm.copyItem(at: rawDir.appendingPathComponent("iphone_en_scene_\(scene).png"), to: docsDir.appendingPathComponent(name))
}

for (locale, list) in scenesByLocale {
    for (idx, meta) in list.enumerated() {
        let accent = accents[idx]
        let s = meta.index
        let lang = locale.hasPrefix("es") ? "es" : "en"
        let iphoneRaw = rawDir.appendingPathComponent("iphone_\(lang)_scene_\(s).png")
        let ipadRaw = rawDir.appendingPathComponent("ipad_\(lang)_scene_\(s).png")

        let position = idx + 1
        let iphoneOut = outRoot.appendingPathComponent("\(locale)/0\(position)_iphone67.png")
        let ipadOut = outRoot.appendingPathComponent("\(locale)/0\(position)_ipad129.png")

        try renderPoster(width: 1290, height: 2796, rawURL: iphoneRaw, meta: meta, accent: accent, isIPad: false, outURL: iphoneOut)
        try renderPoster(width: 2064, height: 2752, rawURL: ipadRaw, meta: meta, accent: accent, isIPad: true, outURL: ipadOut)
        // iPhone Duo: inner (unfolded) and outer displays, uploaded to the APP_IPHONE_DUO set.
        // Inner display is captured in landscape (2853x2007), the outer one in portrait (1398x2034).
        for (display, width, height, wide) in [("duoinner", 2853, 2007, true), ("duoouter", 1398, 2034, false)] {
            let raw = duoDir.appendingPathComponent("\(display)_\(lang)_scene_\(s).png")
            guard fm.fileExists(atPath: raw.path) else { continue }
            let out = outRoot.appendingPathComponent("\(locale)/0\(position)_\(display).png")
            try renderPoster(width: width, height: height, rawURL: raw, meta: meta, accent: accent, isIPad: wide, outURL: out)
        }
        print("[\(locale)] Generated 0\(position) from scene \(s)")
    }
}
