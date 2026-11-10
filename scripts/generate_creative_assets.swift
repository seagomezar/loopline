#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: "/Users/sebas/Documents/loopline")
let fixturesDir = root.appendingPathComponent("scripts/fixtures")
let duoDir = root.appendingPathComponent("build/raw_duo")
let outRoot = root.appendingPathComponent("build/appstore_screenshots")

let bgColor = NSColor(srgbRed: 244/255, green: 245/255, blue: 242/255, alpha: 1)
let surfaceColor = NSColor(srgbRed: 255/255, green: 255/255, blue: 255/255, alpha: 1)
let darkStage = NSColor(srgbRed: 24/255, green: 26/255, blue: 28/255, alpha: 1)
let inkPrimary = NSColor(srgbRed: 29/255, green: 32/255, blue: 31/255, alpha: 1)
let inkSecondary = NSColor(srgbRed: 82/255, green: 88/255, blue: 86/255, alpha: 1)
let lineColor = NSColor(srgbRed: 222/255, green: 226/255, blue: 223/255, alpha: 1)

let brandBlue = NSColor(srgbRed: 37/255, green: 99/255, blue: 235/255, alpha: 1)
let brandCoral = NSColor(srgbRed: 239/255, green: 68/255, blue: 68/255, alpha: 1)
let brandGold = NSColor(srgbRed: 245/255, green: 158/255, blue: 11/255, alpha: 1)
let brandMint = NSColor(srgbRed: 16/255, green: 185/255, blue: 129/255, alpha: 1)

let pastelBlue = NSColor(srgbRed: 209/255, green: 238/255, blue: 252/255, alpha: 1)
let pastelGreen = NSColor(srgbRed: 209/255, green: 250/255, blue: 229/255, alpha: 1)
let pastelYellow = NSColor(srgbRed: 254/255, green: 243/255, blue: 199/255, alpha: 1)

struct CreativeCopy {
    let locale: String
    let langCode: String
    let eyebrow: String
    let headerTitle: String
    let headerSubtitle: String
    let searchTitle: String
    let searchSubtitle: String
    let partLabels: [String]
    let pills: [String]
}

let copies: [CreativeCopy] = [
    CreativeCopy(
        locale: "en-US",
        langCode: "en",
        eyebrow: "MULTI-TRACK VIDEO STUDIO",
        headerTitle: "Every part.\nAll you.",
        headerSubtitle: "Record voice or instrument parts one by one\nand bring them together on one screen.",
        searchTitle: "Your song, on one screen.",
        searchSubtitle: "Record each part on time, arrange 16 layouts, mix, and sync.",
        partLabels: ["Flute 1", "Flute 2", "First voice", "Cello"],
        pills: ["16 Layouts", "Beat Count-In", "Sync Assist", "Up to 4K"]
    ),
    CreativeCopy(
        locale: "es-MX",
        langCode: "es",
        eyebrow: "ESTUDIO DE VIDEO MULTIPISTA",
        headerTitle: "Cada parte.\nTodo tú.",
        headerSubtitle: "Graba tu voz o instrumento parte por parte\ny únelos en una sola pantalla.",
        searchTitle: "Tu canción, en una pantalla.",
        searchSubtitle: "Graba cada parte a tiempo, elige entre 16 diseños, mezcla y sincroniza.",
        partLabels: ["Flauta 1", "Flauta 2", "Primera voz", "Violonchelo"],
        pills: ["16 diseños", "Cuenta regresiva", "Sync Assist", "Hasta 4K"]
    )
]

func loadImage(_ url: URL) throws -> NSImage {
    guard let img = NSImage(contentsOf: url) else {
        throw NSError(domain: "CreativeGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing image \(url.path)"])
    }
    return img
}

func drawAspectFill(_ image: NSImage, in rect: NSRect, radius: CGFloat, zoom: CGFloat = 1.0, offsetY: CGFloat = 0) {
    NSGraphicsContext.saveGraphicsState()
    let clip = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    clip.addClip()
    let srcSize = image.size
    let scale = max(rect.width / srcSize.width, rect.height / srcSize.height) * zoom
    let drawW = srcSize.width * scale
    let drawH = srcSize.height * scale
    let drawX = rect.origin.x + (rect.width - drawW) / 2
    let drawY = rect.origin.y + (rect.height - drawH) / 2 + offsetY
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(
        in: NSRect(x: drawX, y: drawY, width: drawW, height: drawH),
        from: NSRect(x: 0, y: 0, width: srcSize.width, height: srcSize.height),
        operation: .copy,
        fraction: 1.0,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()
}

func drawPartBadge(label: String, dotColor: NSColor, x: CGFloat, y: CGFloat, scale: CGFloat = 1.0) {
    let font = NSFont.systemFont(ofSize: 28 * scale, weight: .semibold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: inkPrimary
    ]
    let str = NSAttributedString(string: label, attributes: attrs)
    let textSize = str.size()
    let padX: CGFloat = 22 * scale
    let padY: CGFloat = 12 * scale
    let dotSize: CGFloat = 16 * scale
    let gap: CGFloat = 12 * scale
    let pillW = padX * 2 + dotSize + gap + ceil(textSize.width)
    let pillH = max(ceil(textSize.height) + padY * 2, 52 * scale)

    let pillRect = NSRect(x: x, y: y, width: pillW, height: pillH)
    let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: pillH / 2, yRadius: pillH / 2)
    NSColor(srgbRed: 248/255, green: 249/255, blue: 247/255, alpha: 0.96).setFill()
    pillPath.fill()

    let dotRect = NSRect(x: x + padX, y: y + (pillH - dotSize) / 2, width: dotSize, height: dotSize)
    dotColor.setFill()
    NSBezierPath(ovalIn: dotRect).fill()

    str.draw(at: NSPoint(x: x + padX + dotSize + gap, y: y + (pillH - textSize.height) / 2))
}

func drawBrandMark(x: CGFloat, y: CGFloat, scale: CGFloat = 1.0) -> CGFloat {
    let colors = [brandBlue, brandCoral, brandGold, brandMint]
    let heights: [CGFloat] = [28, 52, 38, 60].map { $0 * scale }
    let barW: CGFloat = 12 * scale
    let spacing: CGFloat = 7 * scale
    let maxH: CGFloat = 60 * scale

    for i in 0..<4 {
        let h = heights[i]
        let bx = x + CGFloat(i) * (barW + spacing)
        let by = y + (maxH - h) / 2
        colors[i].setFill()
        NSBezierPath(roundedRect: NSRect(x: bx, y: by, width: barW, height: h), xRadius: barW / 2, yRadius: barW / 2).fill()
    }

    let wordX = x + 4 * (barW + spacing) + 14 * scale
    let font = NSFont.systemFont(ofSize: 54 * scale, weight: .bold)
    let str = NSAttributedString(string: "overdubly", attributes: [
        .font: font,
        .foregroundColor: inkPrimary,
        .kern: -1.6 * scale
    ])
    let sz = str.size()
    str.draw(at: NSPoint(x: wordX, y: y + (maxH - sz.height) / 2))
    return maxH
}

func makeContext(width: Int, height: Int) throws -> (CGContext, NSGraphicsContext) {
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
        throw NSError(domain: "CreativeGen", code: 2, userInfo: nil)
    }
    ctx.translateBy(x: 0, y: CGFloat(height))
    ctx.scaleBy(x: 1, y: -1)
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: true)
    return (ctx, nsCtx)
}

func savePNG(_ ctx: CGContext, to outURL: URL) throws {
    guard let outCG = ctx.makeImage() else {
        throw NSError(domain: "CreativeGen", code: 3, userInfo: nil)
    }
    let rep = NSBitmapImageRep(cgImage: outCG)
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "CreativeGen", code: 4, userInfo: nil)
    }
    try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try pngData.write(to: outURL)
}

let parts = try (0..<4).map { try loadImage(fixturesDir.appendingPathComponent("part-\($0).png")) }
let dotColors = [brandCoral, brandBlue, brandMint, brandGold]

// 1. Product Page Header (Encabezado): 3840 x 1646
func renderHeader(copy: CreativeCopy, outURL: URL) throws {
    let width = 3840
    let height = 1646
    let W = CGFloat(width)
    let H = CGFloat(height)
    let (ctx, nsCtx) = try makeContext(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx

    bgColor.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: W, height: H)).fill()

    // Soft decorative pastel accents in background
    NSColor(srgbRed: 215/255, green: 238/255, blue: 250/255, alpha: 0.55).setFill()
    NSBezierPath(ovalIn: NSRect(x: W - 1850, y: -220, width: 1100, height: 1100)).fill()
    NSColor(srgbRed: 216/255, green: 248/255, blue: 232/255, alpha: 0.50).setFill()
    NSBezierPath(ovalIn: NSRect(x: W - 1100, y: H - 900, width: 980, height: 980)).fill()

    // Left safe area column (x: 240 .. 1680)
    let leftX: CGFloat = 240
    var cursorY: CGFloat = 250

    let brandH = drawBrandMark(x: leftX, y: cursorY, scale: 1.25)
    cursorY += brandH + 56

    // Eyebrow pill
    let eyeFont = NSFont.monospacedSystemFont(ofSize: 28, weight: .bold)
    let eyeStr = NSAttributedString(string: copy.eyebrow, attributes: [
        .font: eyeFont,
        .foregroundColor: brandBlue,
        .kern: 1.8
    ])
    let eyeSize = eyeStr.size()
    let eyeRect = NSRect(x: leftX, y: cursorY, width: eyeSize.width + 44, height: 54)
    pastelBlue.setFill()
    NSBezierPath(roundedRect: eyeRect, xRadius: 27, yRadius: 27).fill()
    eyeStr.draw(at: NSPoint(x: leftX + 22, y: cursorY + (54 - eyeSize.height) / 2))
    cursorY += 54 + 36

    // Main Headline
    let titlePara = NSMutableParagraphStyle()
    titlePara.lineSpacing = 6
    titlePara.maximumLineHeight = 168
    let titleStr = NSAttributedString(string: copy.headerTitle, attributes: [
        .font: NSFont.systemFont(ofSize: 156, weight: .bold),
        .foregroundColor: inkPrimary,
        .kern: -3.5,
        .paragraphStyle: titlePara
    ])
    let titleBounds = titleStr.boundingRect(with: NSSize(width: 1420, height: 420), options: [.usesLineFragmentOrigin, .usesFontLeading])
    titleStr.draw(with: NSRect(x: leftX, y: cursorY, width: 1420, height: ceil(titleBounds.height) + 16), options: [.usesLineFragmentOrigin, .usesFontLeading])
    cursorY += ceil(titleBounds.height) + 34

    // Subtitle
    let subPara = NSMutableParagraphStyle()
    subPara.lineSpacing = 10
    let subStr = NSAttributedString(string: copy.headerSubtitle, attributes: [
        .font: NSFont.systemFont(ofSize: 48, weight: .medium),
        .foregroundColor: inkSecondary,
        .kern: -0.4,
        .paragraphStyle: subPara
    ])
    let subBounds = subStr.boundingRect(with: NSSize(width: 1380, height: 220), options: [.usesLineFragmentOrigin, .usesFontLeading])
    subStr.draw(with: NSRect(x: leftX, y: cursorY, width: 1380, height: ceil(subBounds.height) + 10), options: [.usesLineFragmentOrigin, .usesFontLeading])
    cursorY += ceil(subBounds.height) + 48

    // Feature pills row
    let pillColors = [pastelBlue, pastelGreen, pastelYellow, SurfacePillBg()]
    var pillX = leftX
    for (idx, pillText) in copy.pills.enumerated() {
        let pStr = NSAttributedString(string: pillText, attributes: [
            .font: NSFont.systemFont(ofSize: 32, weight: .semibold),
            .foregroundColor: inkPrimary
        ])
        let pSz = pStr.size()
        let pW = ceil(pSz.width) + 52
        let pH: CGFloat = 66
        let pRect = NSRect(x: pillX, y: cursorY, width: pW, height: pH)
        pillColors[idx % pillColors.count].setFill()
        let pPath = NSBezierPath(roundedRect: pRect, xRadius: pH / 2, yRadius: pH / 2)
        pPath.fill()
        lineColor.setStroke()
        pPath.lineWidth = 2
        pPath.stroke()
        pStr.draw(at: NSPoint(x: pillX + 26, y: cursorY + (pH - pSz.height) / 2))
        pillX += pW + 20
    }

    // Right column: Hero Split-Screen Stage Card (x: 1760 .. 3600)
    let stageX: CGFloat = 1760
    let stageY: CGFloat = 148
    let stageW: CGFloat = 1840
    let stageH: CGFloat = H - stageY * 2 // 1350

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -24)
    shadow.shadowBlurRadius = 48
    shadow.shadowColor = NSColor(srgbRed: 15/255, green: 23/255, blue: 42/255, alpha: 0.22)
    shadow.set()
    let stageRect = NSRect(x: stageX, y: stageY, width: stageW, height: stageH)
    let stagePath = NSBezierPath(roundedRect: stageRect, xRadius: 56, yRadius: 56)
    darkStage.setFill()
    stagePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor(srgbRed: 68/255, green: 72/255, blue: 76/255, alpha: 1).setStroke()
    stagePath.lineWidth = 4
    stagePath.stroke()

    let pad: CGFloat = 28
    let gap: CGFloat = 18
    let innerX = stageX + pad
    let innerY = stageY + pad
    let innerW = stageW - pad * 2
    let innerH = stageH - pad * 2

    // Left Hero Tile (52% width) + Right 3 Stacked/Grid Tiles (48% width)
    let leftTileW = round(innerW * 0.50)
    let rightColX = innerX + leftTileW + gap
    let rightColW = innerW - leftTileW - gap
    let topRightH = round((innerH - gap) * 0.52)
    let botRightY = innerY + topRightH + gap
    let botRightH = innerH - topRightH - gap
    let botHalfW = round((rightColW - gap) / 2)

    let tile0 = NSRect(x: innerX, y: innerY, width: leftTileW, height: innerH)
    let tile1 = NSRect(x: rightColX, y: innerY, width: rightColW, height: topRightH)
    let tile2 = NSRect(x: rightColX, y: botRightY, width: botHalfW, height: botRightH)
    let tile3 = NSRect(x: rightColX + botHalfW + gap, y: botRightY, width: rightColW - botHalfW - gap, height: botRightH)

    drawAspectFill(parts[0], in: tile0, radius: 36, zoom: 1.08, offsetY: 20)
    drawAspectFill(parts[1], in: tile1, radius: 32, zoom: 1.05, offsetY: 35)
    drawAspectFill(parts[2], in: tile2, radius: 32, zoom: 1.04, offsetY: 10)
    drawAspectFill(parts[3], in: tile3, radius: 32, zoom: 1.04, offsetY: 10)

    for (idx, rect) in [tile0, tile1, tile2, tile3].enumerated() {
        drawPartBadge(label: copy.partLabels[idx], dotColor: dotColors[idx], x: rect.minX + 24, y: rect.maxY - 82, scale: 1.05)
    }

    NSGraphicsContext.restoreGraphicsState()
    try savePNG(ctx, to: outURL)
}

func SurfacePillBg() -> NSColor {
    return NSColor(srgbRed: 255/255, green: 255/255, blue: 255/255, alpha: 1)
}

// 2. Search Results (Resultados de la búsqueda): 3840 x 2560
func renderSearchResults(copy: CreativeCopy, outURL: URL) throws {
    let width = 3840
    let height = 2560
    let W = CGFloat(width)
    let H = CGFloat(height)
    let (ctx, nsCtx) = try makeContext(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx

    bgColor.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: W, height: H)).fill()

    // Top centered header area (safe area)
    var cursorY: CGFloat = 130
    let brandW: CGFloat = 420
    _ = drawBrandMark(x: (W - brandW) / 2, y: cursorY, scale: 1.15)
    cursorY += 96

    let titlePara = NSMutableParagraphStyle()
    titlePara.alignment = .center
    let titleStr = NSAttributedString(string: copy.searchTitle, attributes: [
        .font: NSFont.systemFont(ofSize: 132, weight: .bold),
        .foregroundColor: inkPrimary,
        .kern: -2.8,
        .paragraphStyle: titlePara
    ])
    titleStr.draw(in: NSRect(x: 200, y: cursorY, width: W - 400, height: 165))
    cursorY += 165

    let subPara = NSMutableParagraphStyle()
    subPara.alignment = .center
    let subStr = NSAttributedString(string: copy.searchSubtitle, attributes: [
        .font: NSFont.systemFont(ofSize: 50, weight: .medium),
        .foregroundColor: inkSecondary,
        .kern: -0.4,
        .paragraphStyle: subPara
    ])
    subStr.draw(in: NSRect(x: 240, y: cursorY, width: W - 480, height: 80))
    cursorY += 110

    // Load the 3 landscape duo inner screenshots (scene 1: Capture, scene 7: Hero Preview, scene 3: Mix & Sync)
    let sceneCapture = try loadImage(duoDir.appendingPathComponent("duoinner_\(copy.langCode)_scene_1.png"))
    let sceneHero = try loadImage(duoDir.appendingPathComponent("duoinner_\(copy.langCode)_scene_7.png"))
    let sceneMix = try loadImage(duoDir.appendingPathComponent("duoinner_\(copy.langCode)_scene_3.png"))

    // Draw side cards (Capture on left, Mix & Sync on right) and dominant center card (Hero Preview)
    func drawBezelCard(_ img: NSImage, rect: NSRect, bezelPad: CGFloat, outerRadius: CGFloat, innerRadius: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: 0, height: -24)
        shadow.shadowBlurRadius = 48
        shadow.shadowColor = NSColor(srgbRed: 15/255, green: 23/255, blue: 42/255, alpha: 0.24)
        shadow.set()
        let bezelPath = NSBezierPath(roundedRect: rect, xRadius: outerRadius, yRadius: outerRadius)
        darkStage.setFill()
        bezelPath.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor(srgbRed: 72/255, green: 76/255, blue: 82/255, alpha: 1).setStroke()
        let borderPath = NSBezierPath(roundedRect: rect, xRadius: outerRadius, yRadius: outerRadius)
        borderPath.lineWidth = 3.5
        borderPath.stroke()

        let screenRect = NSRect(x: rect.minX + bezelPad, y: rect.minY + bezelPad, width: rect.width - bezelPad * 2, height: rect.height - bezelPad * 2)
        drawAspectFill(img, in: screenRect, radius: innerRadius)
    }

    let sideW: CGFloat = 1380
    let sideH: CGFloat = round(sideW * 2007.0 / 2853.0) // ~971
    let sideY: CGFloat = cursorY + 460

    let leftCard = NSRect(x: 150, y: sideY, width: sideW, height: sideH)
    let rightCard = NSRect(x: W - 150 - sideW, y: sideY, width: sideW, height: sideH)
    drawBezelCard(sceneCapture, rect: leftCard, bezelPad: 20, outerRadius: 44, innerRadius: 30)
    drawBezelCard(sceneMix, rect: rightCard, bezelPad: 20, outerRadius: 44, innerRadius: 30)

    let centerW: CGFloat = 1980
    let centerH: CGFloat = round(centerW * 2007.0 / 2853.0) // ~1393
    let centerCard = NSRect(x: round((W - centerW) / 2), y: cursorY + 60, width: centerW, height: centerH)
    drawBezelCard(sceneHero, rect: centerCard, bezelPad: 26, outerRadius: 56, innerRadius: 40)

    // Bottom pills bar
    let pillY = cursorY + centerH + 110
    let pillColors = [pastelBlue, pastelGreen, pastelYellow, SurfacePillBg()]
    var totalPillsW: CGFloat = 0
    var pillSizes: [(NSAttributedString, CGFloat)] = []
    for pillText in copy.pills {
        let pStr = NSAttributedString(string: pillText, attributes: [
            .font: NSFont.systemFont(ofSize: 36, weight: .semibold),
            .foregroundColor: inkPrimary
        ])
        let pW = ceil(pStr.size().width) + 64
        pillSizes.append((pStr, pW))
        totalPillsW += pW
    }
    totalPillsW += CGFloat(max(0, pillSizes.count - 1)) * 24
    var pillX = (W - totalPillsW) / 2
    for (idx, (pStr, pW)) in pillSizes.enumerated() {
        let pH: CGFloat = 74
        let pRect = NSRect(x: pillX, y: pillY, width: pW, height: pH)
        pillColors[idx % pillColors.count].setFill()
        let pPath = NSBezierPath(roundedRect: pRect, xRadius: pH / 2, yRadius: pH / 2)
        pPath.fill()
        lineColor.setStroke()
        pPath.lineWidth = 2
        pPath.stroke()
        let pSz = pStr.size()
        pStr.draw(at: NSPoint(x: pillX + 32, y: pillY + (pH - pSz.height) / 2))
        pillX += pW + 24
    }

    NSGraphicsContext.restoreGraphicsState()
    try savePNG(ctx, to: outURL)
}

for copy in copies {
    let headerOut = outRoot.appendingPathComponent("\(copy.locale)/header_3840x1646.png")
    let searchOut = outRoot.appendingPathComponent("\(copy.locale)/search_3840x2560.png")
    try renderHeader(copy: copy, outURL: headerOut)
    try renderSearchResults(copy: copy, outURL: searchOut)
    print("[\(copy.locale)] Generated header_3840x1646.png and search_3840x2560.png")
}
