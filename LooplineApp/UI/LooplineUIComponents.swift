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
    @State private var image: UIImage?
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.looplinePastelBlue
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else { Image(systemName: "waveform").font(LooplineTheme.text(28)).foregroundStyle(Color.looplineInk) }
            }
        }
        .task(id: url) {
            image = nil
            guard let url else { return }
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 480, height: 480)
            if let result = try? await generator.image(at: .zero) { image = UIImage(cgImage: result.image) }
        }
        .accessibilityHidden(true)
    }
}

struct LooplineStageGrid: View {
    let tracks: [LooplineTrack]
    var compact = false
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(tracks) { track in
                ZStack(alignment: .bottomLeading) {
                    LooplineClipThumbnail(url: track.sourceURL)
                    Text(track.name).font(LooplineTheme.text(12, weight: .medium))
                        .padding(8).background(Color.looplineSurface.opacity(0.94), in: Capsule()).padding(10)
                }
                .frame(height: compact ? 120 : 170)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
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
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    Circle().fill(track.tint).frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.name).font(LooplineTheme.text(16, weight: .bold))
                        Text(track.role).font(LooplineTheme.text(11)).foregroundStyle(Color.looplineMuted)
                    }
                    Spacer()
                    Text(track.formattedDuration).font(LooplineTheme.text(12, mono: true))
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.accessibilityLabel("Select \(track.name)").accessibilityValue(isSelected ? "Selected" : "Not selected")
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
            HStack(spacing: 2) {
                Text("\(track.offsetMilliseconds > 0 ? "+" : "")\(track.offsetMilliseconds) ms")
                    .font(LooplineTheme.text(12, mono: true)).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("track.offset.\(track.name)")
                ForEach([-10, -1, 1, 10], id: \.self) { value in
                    Button("\(value > 0 ? "+" : "")\(value)") { onNudge(value) }
                        .font(LooplineTheme.text(12, mono: true)).frame(minWidth: 38, minHeight: 44)
                        .accessibilityLabel("Move \(track.name) by \(value) milliseconds")
                }
            }
        }
        .buttonStyle(.plain).padding(16)
        .background(Color.looplineSurface, in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(isSelected ? Color.looplineBlue : Color.looplineLine, lineWidth: isSelected ? 2 : 1) }
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
