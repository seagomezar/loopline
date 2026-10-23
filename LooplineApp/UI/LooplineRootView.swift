import SwiftUI

@MainActor
struct LooplineRootView: View {
    @StateObject private var model: LooplineViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingProjects = false
    init(viewModel: LooplineViewModel? = nil) {
        var root: URL?
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-LooplineProjectRoot"), arguments.indices.contains(index + 1) {
            let path = arguments[index + 1]
            root = path.hasPrefix("/") ? URL(fileURLWithPath: path) : FileManager.default.temporaryDirectory.appendingPathComponent(path)
        }
        #endif
        _model = StateObject(wrappedValue: viewModel ?? LooplineViewModel(rootURL: root))
    }
    var body: some View {
        LooplineScreenBackground {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        ForEach([Color.looplineBlue, .looplineCoral, .looplineGold, .looplineMint].indices, id: \.self) { index in
                            Capsule().fill([Color.looplineBlue, .looplineCoral, .looplineGold, .looplineMint][index])
                                .frame(width: 5, height: [12.0, 22.0, 16.0, 26.0][index])
                        }
                    }
                    Text("loopline").font(LooplineTheme.text(22, weight: .bold)).tracking(-0.7)
                    Spacer()
                    Button { showingProjects = true } label: {
                        Label(model.projectTitle, systemImage: "folder").font(LooplineTheme.text(12, weight: .medium)).lineLimit(1)
                    }.tint(.looplineInk).disabled(model.transportBusy).accessibilityIdentifier("project.library")
                }.padding(.horizontal, 22).padding(.vertical, 14)
                Group {
                    switch model.selectedTab {
                    case .capture: LooplineCaptureView(model: model)
                    case .mix: LooplineMixSyncView(model: model)
                    case .export: LooplineExportView(model: model)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 6) {
                    ForEach(LooplineTab.allCases) { tab in
                        Button { model.select(tab) } label: {
                            VStack(spacing: 6) {
                                Image(systemName: tab.icon).font(LooplineTheme.text(18))
                                Text(tab.title).font(LooplineTheme.text(11, weight: .medium))
                            }.foregroundStyle(Color.looplineInk).frame(maxWidth: .infinity, minHeight: 60)
                                .background(model.selectedTab == tab ? Color.looplinePastelBlue : .clear, in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain).disabled(model.transportBusy).accessibilityIdentifier("tab.\(tab.rawValue)")
                    }
                }.padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 4).background(Color.looplineSurface)
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .background { model.handleBackground() } }
        .task {
            #if DEBUG && targetEnvironment(simulator)
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-LooplineHarnessMode"), arguments.contains("-LooplineProjectRoot"),
               let index = arguments.firstIndex(of: "-LooplineSeedTrackCount"), arguments.indices.contains(index + 1),
               let count = Int(arguments[index + 1]), (2...8).contains(count) {
                await model.seedSimulatorSession(trackCount: count)
            }
            #endif
        }
        .sheet(isPresented: $showingProjects) {
            NavigationStack {
                List {
                    Button { model.newProject(); showingProjects = false } label: { Label("New session", systemImage: "plus") }
                    ForEach(model.projects) { project in
                        Button { model.open(project); showingProjects = false } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(project.title).font(LooplineTheme.text(18, weight: .bold))
                                Text("\(project.manifest.project.tracks.count) parts · Saved on this iPhone").font(LooplineTheme.text(12, mono: true))
                            }.padding(.vertical, 8)
                        }
                    }
                }.tint(.looplineInk).navigationTitle("Your sessions")
                    .toolbar { Button("Done") { showingProjects = false } }
            }.preferredColorScheme(.light)
        }
        .alert("Loopline", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}
