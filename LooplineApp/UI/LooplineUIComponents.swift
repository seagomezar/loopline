import AVFoundation
import SwiftUI

struct LooplineScreenBackground<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        ZStack { Color.looplineBackground.ignoresSafeArea(); content() }
            .font(LooplineTheme.text(14))
            .foregroundStyle(Color.looplineInk)
            .preferredColorScheme(.light)
    }
}

struct LooplineTopBar<Trailing: View>: View {
    let eyebrow: String
    let title: String
    @ViewBuilder var trailing: () -> Trailing
    init(eyebrow: String, title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.eyebrow = eyebrow; self.title = title; self.trailing = trailing
    }
    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow.uppercased()).font(LooplineTheme.text(11, mono: true)).foregroundStyle(Color.looplineMuted)
                Text(title).font(LooplineTheme.text(34, weight: .bold)).tracking(-1.1)
            }
            Spacer(minLength: 8)
            trailing()
        }
    }
}

struct LooplineSectionHeader: View {
    let title: String
    var detail: String?
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(LooplineTheme.text(18, weight: .bold))
            Spacer()
            if let detail { Text(detail).font(LooplineTheme.text(11, mono: true)).foregroundStyle(Color.looplineMuted) }
        }
    }
}

struct LooplineSurface<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content
    var body: some View {
        content().padding(padding)
            .background(Color.looplineSurface, in: RoundedRectangle(cornerRadius: 22))
            .overlay { RoundedRectangle(cornerRadius: 22).stroke(Color.looplineLine, lineWidth: 1) }
    }
}

struct LooplinePill: View {
    let text: String
    var tint: Color = .looplineMuted
    var icon: String?
    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(LooplineTheme.text(11, weight: .medium))
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

struct LooplineClipThumbnail: View {
    let url: URL?
    var placement: VideoFramePlacement = VideoFramePlacement()
    @State private var image: UIImage?
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.looplinePastelBlue
                if let image {
                    let tileRect = CGRect(origin: .zero, size: geometry.size)
                    let placedRect = placement.videoRect(forSourceSize: image.size, inTile: tileRect)
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: max(1, placedRect.width), height: max(1, placedRect.height))
                        .position(x: placedRect.midX, y: placedRect.midY)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else { Image(systemName: "waveform").font(LooplineTheme.text(28)).foregroundStyle(Color.looplineInk) }
            }
        }
        .task(id: url) {
            image = nil
            guard let url else { return }
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 640, height: 640)
            if let result = try? await generator.image(at: .zero) { image = UIImage(cgImage: result.image) }
        }
        .accessibilityHidden(true)
    }
}

struct LooplinePartSuggestionStrip: View {
    static let suggestions = ["Flute 1", "Flute 2", "Flute 3", "First voice", "Second voice", "Lead", "Harmony", "Rhythm"]
    var currentText: String = ""
    let onSelect: (String) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Self.suggestions, id: \.self) { item in
                    let isMatching = currentText.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(item) == .orderedSame
                    Button {
                        onSelect(item)
                    } label: {
                        Text(item)
                            .font(LooplineTheme.text(11, weight: .medium))
                            .foregroundStyle(Color.looplineInk)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                isMatching ? Color.looplinePastelBlue : Color.looplineBackground,
                                in: Capsule()
                            )
                            .overlay {
                                Capsule().stroke(isMatching ? Color.looplineBlue : Color.looplineLine, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct LooplineStageGrid: View {
    let tracks: [LooplineTrack]
    var compact = false
    var layout: VideoLayoutStyle? = nil
    var tileSpacing: CGFloat = 6
    var tileCornerRadius: CGFloat = 14
    var selectedTrackID: UUID? = nil
    var onSelectTrack: ((LooplineTrack) -> Void)? = nil
    var onUpdateFraming: ((UUID, Double, Double, Double) -> Void)? = nil
    var onRename: ((LooplineTrack) -> Void)? = nil
    var onDelete: ((LooplineTrack) -> Void)? = nil

    var body: some View {
        if let layout, onRename == nil, onDelete == nil, !tracks.isEmpty {
            GeometryReader { geometry in
                let rects = layout.normalizedRects(for: tracks.count)
                let spacing = tileSpacing
                ZStack(alignment: .topLeading) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        let norm = rects[index]
                        let tileWidth = max(24, norm.width * geometry.size.width - spacing)
                        let tileHeight = max(24, norm.height * geometry.size.height - spacing)
                        let x = norm.minX * geometry.size.width + spacing / 2 + tileWidth / 2
                        let y = norm.minY * geometry.size.height + spacing / 2 + tileHeight / 2
                        if let onUpdateFraming {
                            LooplineInteractiveStageTile(
                                track: track,
                                slotIndex: index,
                                isSelected: (selectedTrackID ?? tracks.first?.id) == track.id,
                                tileSize: CGSize(width: tileWidth, height: tileHeight),
                                onSelect: { onSelectTrack?(track) },
                                onUpdateFraming: { panX, panY, zoom in
                                    onUpdateFraming(track.id, panX, panY, zoom)
                                }
                            )
                            .frame(width: tileWidth, height: tileHeight)
                            .clipShape(RoundedRectangle(cornerRadius: tileCornerRadius))
                            .overlay {
                                RoundedRectangle(cornerRadius: tileCornerRadius)
                                    .stroke(
                                        (selectedTrackID ?? tracks.first?.id) == track.id ? Color.looplineBlue : Color.clear,
                                        lineWidth: 2.5
                                    )
                            }
                            .position(x: x, y: y)
                        } else {
                            tileView(for: track)
                                .frame(width: tileWidth, height: tileHeight)
                                .clipShape(RoundedRectangle(cornerRadius: tileCornerRadius))
                                .position(x: x, y: y)
                        }
                    }
                }
            }
            .frame(minHeight: compact ? 200 : 280)
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(tracks) { track in
                    tileView(for: track)
                        .frame(height: compact ? 120 : 170)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    @ViewBuilder
    private func tileView(for track: LooplineTrack) -> some View {
        ZStack(alignment: .bottomLeading) {
            LooplineClipThumbnail(url: track.sourceURL, placement: track.placement)
            VStack {
                if onRename != nil || onDelete != nil {
                    HStack(spacing: 6) {
                        Spacer()
                        if let onRename {
                            Button { onRename(track) } label: {
                                Image(systemName: "pencil")
                                    .font(LooplineTheme.text(12, weight: .bold))
                                    .foregroundStyle(Color.looplineInk)
                                    .frame(width: 30, height: 30)
                                    .background(Color.looplineSurface.opacity(0.92), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Rename \(track.name)")
                        }
                        if let onDelete {
                            Button { onDelete(track) } label: {
                                Image(systemName: "trash")
                                    .font(LooplineTheme.text(12, weight: .bold))
                                    .foregroundStyle(Color.looplineCoral)
                                    .frame(width: 30, height: 30)
                                    .background(Color.looplineSurface.opacity(0.92), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete \(track.name)")
                        }
                    }
                    .padding(8)
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(track.tint).frame(width: 8, height: 8)
                    Text(track.name)
                        .font(LooplineTheme.text(12, weight: .bold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.looplineSurface.opacity(0.94), in: Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
        }
    }
}

struct LooplineInteractiveStageTile: View {
    let track: LooplineTrack
    let slotIndex: Int
    let isSelected: Bool
    let tileSize: CGSize
    let onSelect: () -> Void
    let onUpdateFraming: (Double, Double, Double) -> Void

    @State private var dragStartPan: (x: Double, y: Double)?
    @State private var pinchStartZoom: Double?
    @State private var isManipulating = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LooplineClipThumbnail(url: track.sourceURL, placement: track.placement)

            if isManipulating || isSelected {
                framingGridOverlay
                    .opacity(isManipulating ? 0.55 : 0.22)
                    .allowsHitTesting(false)
            }

            VStack {
                HStack(spacing: 6) {
                    Text("#\(slotIndex + 1)")
                        .font(LooplineTheme.text(9, weight: .bold, mono: true))
                        .foregroundStyle(isSelected ? Color.looplineBlue : Color.looplineInk)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.looplineSurface.opacity(0.9), in: Capsule())
                        .allowsHitTesting(false)

                    Spacer()
                    if isSelected || !track.placement.isDefault {
                        HStack(spacing: 4) {
                            Button {
                                onSelect()
                                let nextZoom = max(1.0, ((track.zoom - 0.25) * 20).rounded() / 20)
                                onUpdateFraming(track.panX, track.panY, nextZoom)
                            } label: {
                                Image(systemName: "minus")
                                    .font(LooplineTheme.text(10, weight: .bold))
                                    .foregroundStyle(track.zoom <= 1.01 ? Color.looplineMuted : Color.looplineInk)
                                    .frame(width: 24, height: 24)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(track.zoom <= 1.01)
                            .accessibilityLabel("Zoom out \(track.name)")

                            Button {
                                onSelect()
                                onUpdateFraming(0, 0, 1.0)
                            } label: {
                                HStack(spacing: 2) {
                                    if !track.placement.isDefault {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(LooplineTheme.text(8, weight: .bold))
                                    }
                                    Text(String(format: "%.1f×", track.zoom))
                                        .font(LooplineTheme.text(10, weight: .bold, mono: true))
                                }
                                .foregroundStyle(Color.looplineInk)
                                .padding(.horizontal, 4)
                                .frame(minHeight: 24)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Reset framing for \(track.name)")

                            Button {
                                onSelect()
                                let nextZoom = min(3.0, ((track.zoom + 0.25) * 20).rounded() / 20)
                                onUpdateFraming(track.panX, track.panY, nextZoom)
                            } label: {
                                Image(systemName: "plus")
                                    .font(LooplineTheme.text(10, weight: .bold))
                                    .foregroundStyle(track.zoom >= 2.99 ? Color.looplineMuted : Color.looplineInk)
                                    .frame(width: 24, height: 24)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(track.zoom >= 2.99)
                            .accessibilityLabel("Zoom in \(track.name)")
                        }
                        .padding(.horizontal, 4)
                        .background(Color.looplineSurface.opacity(0.94), in: Capsule())
                    }
                }
                .padding(6)

                Spacer()

                HStack(spacing: 6) {
                    Circle().fill(track.tint).frame(width: 8, height: 8)
                    Text(track.name)
                        .font(LooplineTheme.text(11, weight: .bold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.looplineSurface.opacity(0.94), in: Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onSelect()
            onUpdateFraming(0, 0, 1.0)
        }
        .onTapGesture(count: 1) {
            onSelect()
        }
        .highPriorityGesture(
            SimultaneousGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        if dragStartPan == nil {
                            onSelect()
                            dragStartPan = (track.panX, track.panY)
                            isManipulating = true
                        }
                        guard let start = dragStartPan else { return }
                        let widthRef = max(tileSize.width, 44)
                        let heightRef = max(tileSize.height, 44)
                        let deltaX = Double(value.translation.width / widthRef) * 1.8
                        let deltaY = Double(value.translation.height / heightRef) * 1.8
                        let nextPanX = min(1.0, max(-1.0, start.x + deltaX))
                        let nextPanY = min(1.0, max(-1.0, start.y + deltaY))
                        onUpdateFraming(nextPanX, nextPanY, track.zoom)
                    }
                    .onEnded { _ in
                        dragStartPan = nil
                        if pinchStartZoom == nil { isManipulating = false }
                    },
                MagnificationGesture(minimumScaleDelta: 0.01)
                    .onChanged { scale in
                        if pinchStartZoom == nil {
                            onSelect()
                            pinchStartZoom = track.zoom
                            isManipulating = true
                        }
                        guard let startZoom = pinchStartZoom else { return }
                        let nextZoom = min(3.0, max(1.0, startZoom * Double(scale)))
                        onUpdateFraming(track.panX, track.panY, nextZoom)
                    }
                    .onEnded { _ in
                        pinchStartZoom = nil
                        if dragStartPan == nil { isManipulating = false }
                    }
            )
        )
    }

    private var framingGridOverlay: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width
                let h = geo.size.height
                path.move(to: CGPoint(x: w / 3, y: 0))
                path.addLine(to: CGPoint(x: w / 3, y: h))
                path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                path.move(to: CGPoint(x: 0, y: h / 3))
                path.addLine(to: CGPoint(x: w, y: h / 3))
                path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                path.addLine(to: CGPoint(x: w, y: 2 * h / 3))
            }
            .stroke(Color.white, lineWidth: 0.8)
        }
    }
}

struct LooplineFrameCropControls: View {
    let tracks: [LooplineTrack]
    let selectedTrack: LooplineTrack?
    let onSelect: (UUID) -> Void
    let onMoveBy: (UUID, Int) -> Void
    let onMoveToSlot: (UUID, Int) -> Void
    let onUpdateFraming: (UUID, Double, Double, Double) -> Void
    let onResetTrack: (UUID) -> Void
    let onResetAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Frame order, position & crop")
                        .font(LooplineTheme.text(15, weight: .bold))
                    Text("Change each voice's frame slot (#1, #2…), or drag and pinch inside any frame.")
                        .font(LooplineTheme.text(11))
                        .foregroundStyle(Color.looplineMuted)
                }
                Spacer()
                if tracks.contains(where: { !$0.placement.isDefault }) {
                    Button("Reset all") {
                        onResetAll()
                    }
                    .font(LooplineTheme.text(12, weight: .bold))
                    .foregroundStyle(Color.looplineBlue)
                    .buttonStyle(.plain)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        let isSelected = selectedTrack?.id == track.id
                        Button {
                            onSelect(track.id)
                        } label: {
                            HStack(spacing: 6) {
                                Text("#\(index + 1)")
                                    .font(LooplineTheme.text(10, weight: .bold, mono: true))
                                    .foregroundStyle(isSelected ? Color.looplineBlue : Color.looplineMuted)
                                Circle().fill(track.tint).frame(width: 8, height: 8)
                                Text(track.name)
                                    .font(LooplineTheme.text(12, weight: .bold))
                                    .lineLimit(1)
                                if !track.placement.isDefault {
                                    Text(String(format: "%.1f×", track.zoom))
                                        .font(LooplineTheme.text(10, mono: true))
                                        .foregroundStyle(Color.looplineBlue)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ? Color.looplinePastelBlue : Color.looplineBackground,
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .stroke(isSelected ? Color.looplineBlue : Color.looplineLine, lineWidth: isSelected ? 1.5 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let selected = selectedTrack,
               let selectedIndex = tracks.firstIndex(where: { $0.id == selected.id }) {
                VStack(alignment: .leading, spacing: 12) {
                    if tracks.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Frame slot for \(selected.name)", systemImage: "square.grid.2x2")
                                    .font(LooplineTheme.text(12, weight: .medium))
                                Spacer()
                                Text("Frame #\(selectedIndex + 1) of \(tracks.count)")
                                    .font(LooplineTheme.text(11, weight: .bold, mono: true))
                                    .foregroundStyle(Color.looplineBlue)
                            }

                            HStack(spacing: 6) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        onMoveBy(selected.id, -1)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.left")
                                        Text("Earlier")
                                    }
                                    .font(LooplineTheme.text(11, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .frame(minHeight: 34)
                                    .background(Color.looplineSurface, in: RoundedRectangle(cornerRadius: 9))
                                    .overlay { RoundedRectangle(cornerRadius: 9).stroke(Color.looplineLine, lineWidth: 1) }
                                }
                                .buttonStyle(.plain)
                                .disabled(selectedIndex == 0)
                                .opacity(selectedIndex == 0 ? 0.45 : 1)
                                .accessibilityLabel("Move \(selected.name) to earlier frame")

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 5) {
                                        ForEach(0..<tracks.count, id: \.self) { slot in
                                            let isCurrentSlot = slot == selectedIndex
                                            Button {
                                                withAnimation(.easeInOut(duration: 0.18)) {
                                                    onMoveToSlot(selected.id, slot)
                                                }
                                            } label: {
                                                Text("#\(slot + 1)")
                                                    .font(LooplineTheme.text(11, weight: .bold, mono: true))
                                                    .foregroundStyle(Color.looplineInk)
                                                    .frame(minWidth: 34, minHeight: 34)
                                                    .background(
                                                        isCurrentSlot ? Color.looplinePastelBlue : Color.looplineSurface,
                                                        in: RoundedRectangle(cornerRadius: 9)
                                                    )
                                                    .overlay {
                                                        RoundedRectangle(cornerRadius: 9)
                                                            .stroke(isCurrentSlot ? Color.looplineBlue : Color.looplineLine, lineWidth: isCurrentSlot ? 1.5 : 1)
                                                    }
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel("Move \(selected.name) to frame \(slot + 1)")
                                        }
                                    }
                                }

                                Button {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        onMoveBy(selected.id, 1)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Later")
                                        Image(systemName: "arrow.right")
                                    }
                                    .font(LooplineTheme.text(11, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .frame(minHeight: 34)
                                    .background(Color.looplineSurface, in: RoundedRectangle(cornerRadius: 9))
                                    .overlay { RoundedRectangle(cornerRadius: 9).stroke(Color.looplineLine, lineWidth: 1) }
                                }
                                .buttonStyle(.plain)
                                .disabled(selectedIndex >= tracks.count - 1)
                                .opacity(selectedIndex >= tracks.count - 1 ? 0.45 : 1)
                                .accessibilityLabel("Move \(selected.name) to later frame")
                            }
                        }

                        Divider()
                    }

                    HStack {
                        Label("Zoom / Crop", systemImage: "viewfinder")
                            .font(LooplineTheme.text(12, weight: .medium))
                        Spacer()
                        Text(String(format: "%.2f×", selected.zoom))
                            .font(LooplineTheme.text(12, weight: .bold, mono: true))
                            .foregroundStyle(Color.looplineInk)
                    }
                    Slider(
                        value: Binding(
                            get: { selected.zoom },
                            set: { onUpdateFraming(selected.id, selected.panX, selected.panY, $0) }
                        ),
                        in: 1.0...3.0,
                        step: 0.02
                    )
                    .tint(.looplineBlue)
                    .accessibilityLabel("Zoom for \(selected.name)")

                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Horizontal")
                                    .font(LooplineTheme.text(11, weight: .medium))
                                Spacer()
                                Text("\(Int((selected.panX * 100).rounded()))%")
                                    .font(LooplineTheme.text(11, mono: true))
                                    .foregroundStyle(Color.looplineMuted)
                            }
                            Slider(
                                value: Binding(
                                    get: { selected.panX },
                                    set: { onUpdateFraming(selected.id, $0, selected.panY, selected.zoom) }
                                ),
                                in: -1.0...1.0,
                                step: 0.02
                            )
                            .tint(.looplineBlue)
                            .accessibilityLabel("Horizontal position for \(selected.name)")
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Vertical")
                                    .font(LooplineTheme.text(11, weight: .medium))
                                Spacer()
                                Text("\(Int((selected.panY * 100).rounded()))%")
                                    .font(LooplineTheme.text(11, mono: true))
                                    .foregroundStyle(Color.looplineMuted)
                            }
                            Slider(
                                value: Binding(
                                    get: { selected.panY },
                                    set: { onUpdateFraming(selected.id, selected.panX, $0, selected.zoom) }
                                ),
                                in: -1.0...1.0,
                                step: 0.02
                            )
                            .tint(.looplineBlue)
                            .accessibilityLabel("Vertical position for \(selected.name)")
                        }
                    }

                    HStack {
                        Text("Tip: Double-tap any frame to center it.")
                            .font(LooplineTheme.text(11))
                            .foregroundStyle(Color.looplineMuted)
                        Spacer()
                        Button {
                            onResetTrack(selected.id)
                        } label: {
                            Label("Center \(selected.name)", systemImage: "arrow.counterclockwise")
                                .font(LooplineTheme.text(12, weight: .bold))
                                .foregroundStyle(selected.placement.isDefault ? Color.looplineMuted : Color.looplineBlue)
                        }
                        .buttonStyle(.plain)
                        .disabled(selected.placement.isDefault)
                    }
                }
                .padding(12)
                .background(Color.looplineBackground, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

struct LooplinePlayerLayerView: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.backgroundColor = .clear
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    final class PlayerContainerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

struct LooplineCompositionPlayerView: View {
    let player: AVPlayer?
    let overlayImage: CGImage?
    let tracks: [LooplineTrack]
    let layout: VideoLayoutStyle
    var showFallbackTitles: Bool = false

    var body: some View {
        ZStack {
            Color.looplineInk
            if let player {
                LooplinePlayerLayerView(player: player)
            }
            if let overlayImage {
                Image(decorative: overlayImage, scale: 1.0)
                    .resizable()
                    .interpolation(.high)
                    .allowsHitTesting(false)
            } else if showFallbackTitles {
                LooplinePlayerTitlesOverlay(tracks: tracks, layout: layout)
                    .allowsHitTesting(false)
            }
        }
    }
}

struct LooplinePlayerTitlesOverlay: View {
    let tracks: [LooplineTrack]
    let layout: VideoLayoutStyle

    var body: some View {
        GeometryReader { geometry in
            let rects = layout.normalizedRects(for: tracks.count)
            ZStack(alignment: .topLeading) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    if index < rects.count {
                        let norm = rects[index]
                        let tileWidth = max(24, norm.width * geometry.size.width)
                        let tileHeight = max(24, norm.height * geometry.size.height)
                        let x = norm.minX * geometry.size.width + tileWidth / 2
                        let y = norm.minY * geometry.size.height + tileHeight / 2
                        ZStack(alignment: .bottomLeading) {
                            Color.clear
                            HStack(spacing: 6) {
                                Circle().fill(track.tint).frame(width: 8, height: 8)
                                Text(track.name)
                                    .font(LooplineTheme.text(11, weight: .bold))
                                    .foregroundStyle(Color.looplineInk)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.looplineSurface.opacity(0.92), in: Capsule())
                            .padding(8)
                        }
                        .frame(width: tileWidth, height: tileHeight)
                        .position(x: x, y: y)
                    }
                }
            }
        }
    }
}

struct LooplineFrameSchematicView: View {
    let layout: VideoLayoutStyle
    var partCount: Int = 4
    var isSelected: Bool = false

    private var characteristicCount: Int {
        switch layout {
        case .bentoSplit: 6
        case .dipticAlternating: 4
        case .heroTop, .heroBottom, .heroLeft, .heroRight: 4
        case .centerStage: 5
        case .grid1: 3
        case .splitRows12, .splitRows21: 3
        case .splitRows23, .splitRows32: 5
        case .horizontalStrip: 3
        case .grid2: 4
        case .grid3: 9
        case .grid4: 8
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let rects = layout.normalizedRects(for: characteristicCount)
            let gap: CGFloat = 2.0
            let palette: [Color] = [.looplineBlue, .looplineCoral, .looplineMint, .looplineGold]
            ZStack(alignment: .topLeading) {
                ForEach(Array(rects.enumerated()), id: \.offset) { idx, norm in
                    let w = max(3, norm.width * geometry.size.width - gap)
                    let h = max(3, norm.height * geometry.size.height - gap)
                    let x = norm.minX * geometry.size.width + gap / 2 + w / 2
                    let y = norm.minY * geometry.size.height + gap / 2 + h / 2
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isSelected ? palette[idx % palette.count].opacity(0.85) : Color.looplineInk.opacity(0.2))
                        .overlay {
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(isSelected ? Color.looplineInk.opacity(0.45) : Color.looplineInk.opacity(0.35), lineWidth: 0.8)
                        }
                        .frame(width: w, height: h)
                        .position(x: x, y: y)
                }
            }
        }
        .padding(4)
        .background(isSelected ? Color.looplineSurface : Color.looplineBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.looplineBlue : Color.looplineLine, lineWidth: isSelected ? 1.5 : 1)
        }
    }
}

struct LooplineFrameLayoutPicker: View {
    @Binding var selection: VideoLayoutStyle
    var partCount: Int
    var isProUnlocked: Bool = true

    private let gridColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Frame layout").font(LooplineTheme.text(15, weight: .bold))
                Spacer()
                LooplinePill(text: selection.title, tint: .looplineBlue, icon: "rectangle.3.group")
            }

            ForEach(VideoLayoutCategory.allCases) { category in
                let styles = VideoLayoutStyle.allCases.filter { $0.category == category }
                VStack(alignment: .leading, spacing: 8) {
                    Text(categoryLabel(for: category))
                        .font(LooplineTheme.text(10, mono: true))
                        .foregroundStyle(Color.looplineMuted)
                    LazyVGrid(columns: gridColumns, spacing: 8) {
                        ForEach(styles) { style in
                            layoutCell(for: style)
                        }
                    }
                }
            }
        }
    }

    private func categoryLabel(for category: VideoLayoutCategory) -> String {
        switch category {
        case .combinations: "COMBINATIONS · FRAMES & DIPTIC"
        case .rows: "ROWS · HORIZONTAL SPLITS"
        case .columns: "COLUMNS & GRIDS · VERTICAL SPLITS"
        }
    }

    @ViewBuilder
    private func layoutCell(for style: VideoLayoutStyle) -> some View {
        let isSelected = selection == style
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selection = style
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    LooplineFrameSchematicView(
                        layout: style,
                        partCount: partCount,
                        isSelected: isSelected
                    )
                    .frame(width: 48, height: 62)

                    if !isProUnlocked && style.isProOnly {
                        Text("PRO")
                            .font(LooplineTheme.text(7, weight: .bold, mono: true))
                            .foregroundStyle(Color.looplineInk)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.looplinePastelYellow, in: Capsule())
                            .overlay { Capsule().stroke(Color.looplineLine, lineWidth: 0.8) }
                            .offset(x: 4, y: -4)
                    }
                }

                VStack(spacing: 1) {
                    Text(style.title)
                        .font(LooplineTheme.text(10, weight: .bold))
                        .foregroundStyle(Color.looplineInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(style.subtitle)
                        .font(LooplineTheme.text(8, mono: true))
                        .foregroundStyle(Color.looplineMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                isSelected ? Color.looplinePastelBlue.opacity(0.75) : Color.looplineBackground,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.looplineBlue : Color.looplineLine, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("export.layout.\(style.rawValue)")
        .accessibilityLabel("\(style.title), \(style.subtitle)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

struct LooplineWaveform: View {
    let samples: [Double]
    var tint: Color = .looplineBlue
    var height: CGFloat = 44
    var body: some View {
        GeometryReader { geometry in
            if samples.isEmpty {
                Rectangle().fill(Color.looplineLine).frame(height: 1).frame(maxHeight: .infinity)
            } else {
                HStack(spacing: 2) {
                    ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                        Capsule().fill(tint).frame(maxWidth: .infinity)
                            .frame(height: max(2, geometry.size.height * min(1, sample * 3)))
                    }
                }.frame(maxHeight: .infinity)
            }
        }.frame(height: height).accessibilityLabel("Recorded audio waveform")
    }
}

struct LooplineTrackLane: View {
    let track: LooplineTrack
    let isSelected: Bool
    let onSelect: () -> Void
    let onMute: () -> Void
    let onSolo: () -> Void
    let onNudge: (Int) -> Void
    let onVolumeChange: (Double) -> Void
    var onRename: ((String) -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @State private var isEditingTitle = false
    @State private var draftTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Button(action: onSelect) {
                    HStack(spacing: 10) {
                        Circle().fill(track.tint).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.name)
                                .font(LooplineTheme.text(18, weight: .bold))
                                .lineLimit(1)
                                .accessibilityIdentifier("track.headline.\(track.id.uuidString)")
                            Text("\(track.formattedDuration) · \(track.role)")
                                .font(LooplineTheme.text(11, mono: true))
                                .foregroundStyle(Color.looplineMuted)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Select \(track.name)")
                .accessibilityValue(isSelected ? "Selected" : "Not selected")

                if onRename != nil {
                    Button {
                        draftTitle = track.name
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isEditingTitle.toggle()
                        }
                    } label: {
                        Image(systemName: "pencil")
                            .font(LooplineTheme.text(14, weight: .bold))
                            .foregroundStyle(Color.looplineInk)
                            .frame(width: 38, height: 38)
                            .background(isEditingTitle ? Color.looplinePastelBlue : Color.looplineBackground, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityLabel("Rename \(track.name)")
                    .accessibilityIdentifier("track.rename.\(track.name)")
                }

                if let onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(LooplineTheme.text(14, weight: .bold))
                            .foregroundStyle(Color.looplineCoral)
                            .frame(width: 38, height: 38)
                            .background(Color.looplinePastelRed.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityLabel("Delete \(track.name)")
                    .accessibilityIdentifier("track.delete.\(track.name)")
                }
            }

            if isEditingTitle, let onRename {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TextField("Part headline (e.g. Flute 1, First voice)", text: $draftTitle)
                            .font(LooplineTheme.text(14, weight: .medium))
                            .textFieldStyle(.plain)
                            .submitLabel(.done)
                            .onSubmit {
                                commitRename(using: onRename)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.looplineBackground, in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityIdentifier("track.titleInput.\(track.name)")

                        Button("Save") {
                            commitRename(using: onRename)
                        }
                        .font(LooplineTheme.text(13, weight: .bold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 40)
                        .background(Color.looplinePastelGreen, in: RoundedRectangle(cornerRadius: 10))
                        .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("track.titleSave.\(track.name)")

                        Button("Cancel") {
                            isEditingTitle = false
                        }
                        .font(LooplineTheme.text(12, weight: .medium))
                        .foregroundStyle(Color.looplineMuted)
                        .padding(.horizontal, 6)
                        .frame(minHeight: 40)
                    }
                    LooplinePartSuggestionStrip(currentText: draftTitle) { suggestion in
                        draftTitle = suggestion
                    }
                }
                .padding(12)
                .background(Color.looplineBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
            }

            LooplineWaveform(samples: track.waveform, tint: track.tint).onTapGesture(perform: onSelect)
            HStack(spacing: 10) {
                Button(action: onMute) { Text("M").frame(width: 44, height: 44).background(track.isMuted ? Color.looplinePastelYellow : Color.looplineBackground, in: RoundedRectangle(cornerRadius: 12)) }
                    .accessibilityLabel("Mute \(track.name)").accessibilityValue(track.isMuted ? "On" : "Off")
                Button(action: onSolo) { Text("S").frame(width: 44, height: 44).background(track.isSolo ? Color.looplinePastelGreen : Color.looplineBackground, in: RoundedRectangle(cornerRadius: 12)) }
                    .accessibilityLabel("Solo \(track.name)").accessibilityValue(track.isSolo ? "On" : "Off")
                Slider(value: Binding(get: { track.volume }, set: { onVolumeChange($0) }), in: 0...1)
                    .tint(.looplineBlue).accessibilityLabel("Volume for \(track.name)")
                Text("\(Int(track.volume * 100))%").font(LooplineTheme.text(11, mono: true)).frame(width: 42)
            }
            HStack(spacing: 6) {
                Text("\(track.offsetMilliseconds > 0 ? "+" : "")\(track.offsetMilliseconds) ms")
                    .font(LooplineTheme.text(12, mono: true)).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("track.offset.\(track.name)")
                ForEach([-10, -1, 1, 10], id: \.self) { value in
                    Button("\(value > 0 ? "+" : "")\(value)") { onNudge(value) }
                        .font(LooplineTheme.text(12, mono: true)).frame(minWidth: 42, minHeight: 44)
                        .background(Color.looplineBackground, in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityLabel("Move \(track.name) by \(value) milliseconds")
                }
            }
        }
        .buttonStyle(.plain).padding(16)
        .background(Color.looplineSurface, in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(isSelected ? Color.looplineBlue : Color.looplineLine, lineWidth: isSelected ? 2 : 1) }
    }

    private func commitRename(using onRename: (String) -> Void) {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onRename(trimmed)
        isEditingTitle = false
    }
}

struct LooplineMeter: View {
    let value: Double
    var tint: Color = .looplineMint
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<12, id: \.self) { index in
                Capsule().fill(index < Int(min(1, max(0, value)) * 12) ? (index > 9 ? Color.looplineCoral : tint) : Color.looplineLine)
                    .frame(height: 12)
            }
        }.accessibilityLabel("Input level").accessibilityValue("\(Int(value * 100)) percent")
    }
}

struct LooplineIconButton: View {
    let icon: String
    var tint: Color = .looplineInk
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(LooplineTheme.text(18)).foregroundStyle(tint)
                .frame(width: 48, height: 48).background(Color.looplineSurfaceRaised, in: Circle())
        }.buttonStyle(.plain)
    }
}

struct LooplinePrimaryButton: View {
    let title: String
    var icon: String?
    var tint: Color = .looplineBlue
    var isDisabled = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let icon { Image(systemName: icon) }
                Text(title).font(LooplineTheme.text(15, weight: .bold))
            }
            .foregroundStyle(isDisabled ? Color.looplineMuted : Color.looplineInk)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(isDisabled ? Color.looplineSurfaceRaised : tint, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).disabled(isDisabled)
    }
}
