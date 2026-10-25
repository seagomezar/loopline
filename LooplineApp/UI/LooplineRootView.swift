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
                if let sceneIdx = arguments.firstIndex(of: "-LooplineScreenshotScene"),
                   arguments.indices.contains(sceneIdx + 1) {
                    let scene = arguments[sceneIdx + 1]
                    switch scene {
                    case "1":
                        model.nextPartTitle = "Lead Flute"
                        model.select(.capture)
                    case "2":
                        model.exportPreviewMode = .realPreview
                        model.select(.export)
                    case "3":
                        model.select(.mix)
                    case "4":
                        model.exportPreviewMode = .frameCrop
                        model.select(.export)
                    case "5":
                        model.newProject()
                        if let currentID = model.currentProjectID {
                            model.renameProject(currentID, to: "Vocal Harmony Arrangement")
                        }
                        if let first = model.projects.first(where: { $0.title.contains("Chamber") }) {
                            model.open(first)
                        }
                        showingProjects = true
                    default:
                        break
                    }
                }
            }
            #endif
        }
        .sheet(isPresented: $showingProjects) {
            LooplineSessionsSheet(model: model, isPresented: $showingProjects)
                .preferredColorScheme(.light)
        }
        .alert("Loopline", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}

@MainActor
struct LooplineSessionsSheet: View {
    @ObservedObject var model: LooplineViewModel
    @Binding var isPresented: Bool
    @State private var editingProjectID: UUID?
    @State private var draftSessionTitle = ""
    @State private var projectPendingDelete: StoredProject?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        model.newProject()
                        isPresented = false
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(LooplineTheme.text(18, weight: .bold))
                                .foregroundStyle(Color.looplineBlue)
                            Text("New session")
                                .font(LooplineTheme.text(16, weight: .bold))
                                .foregroundStyle(Color.looplineInk)
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityIdentifier("session.new")
                }

                Section("Saved sessions") {
                    ForEach(model.projects) { project in
                        let isActive = model.currentProjectID == project.id
                        let isEditing = editingProjectID == project.id
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Button {
                                    model.open(project)
                                    isPresented = false
                                } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack(spacing: 8) {
                                            Text(project.title)
                                                .font(LooplineTheme.text(17, weight: .bold))
                                                .foregroundStyle(Color.looplineInk)
                                                .lineLimit(1)
                                            if isActive {
                                                Text("ACTIVE")
                                                    .font(LooplineTheme.text(9, mono: true))
                                                    .foregroundStyle(Color.looplineInk)
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 3)
                                                    .background(Color.looplinePastelBlue, in: Capsule())
                                            }
                                        }
                                        let count = project.manifest.project.tracks.count
                                        Text("\(count) \(count == 1 ? "part" : "parts") · Saved on this iPhone")
                                            .font(LooplineTheme.text(12, mono: true))
                                            .foregroundStyle(Color.looplineMuted)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("session.open.\(project.id.uuidString)")

                                Button {
                                    if isEditing {
                                        editingProjectID = nil
                                    } else {
                                        draftSessionTitle = project.title
                                        editingProjectID = project.id
                                    }
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(LooplineTheme.text(14, weight: .bold))
                                        .foregroundStyle(Color.looplineInk)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            isEditing ? Color.looplinePastelBlue : Color.looplineBackground,
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Rename \(project.title)")
                                .accessibilityIdentifier("session.rename.\(project.title)")

                                Button {
                                    projectPendingDelete = project
                                } label: {
                                    Image(systemName: "trash")
                                        .font(LooplineTheme.text(14, weight: .bold))
                                        .foregroundStyle(Color.looplineCoral)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Color.looplinePastelRed.opacity(0.65),
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete \(project.title)")
                                .accessibilityIdentifier("session.delete.\(project.title)")
                            }

                            if isEditing {
                                HStack(spacing: 8) {
                                    TextField("Session name", text: $draftSessionTitle)
                                        .font(LooplineTheme.text(14, weight: .medium))
                                        .textFieldStyle(.plain)
                                        .submitLabel(.done)
                                        .onSubmit {
                                            commitRename(for: project.id)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 9)
                                        .background(Color.looplineBackground, in: RoundedRectangle(cornerRadius: 10))
                                        .accessibilityIdentifier("session.titleInput.\(project.id.uuidString)")

                                    Button("Save") {
                                        commitRename(for: project.id)
                                    }
                                    .font(LooplineTheme.text(13, weight: .bold))
                                    .foregroundStyle(Color.looplineInk)
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 38)
                                    .background(Color.looplinePastelGreen, in: RoundedRectangle(cornerRadius: 10))
                                    .buttonStyle(.plain)
                                    .disabled(draftSessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    .accessibilityIdentifier("session.titleSave.\(project.id.uuidString)")

                                    Button("Cancel") {
                                        editingProjectID = nil
                                    }
                                    .font(LooplineTheme.text(12, weight: .medium))
                                    .foregroundStyle(Color.looplineMuted)
                                    .padding(.horizontal, 6)
                                    .frame(minHeight: 38)
                                    .buttonStyle(.plain)
                                }
                                .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 6)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                projectPendingDelete = project
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                draftSessionTitle = project.title
                                editingProjectID = project.id
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(.looplineBlue)
                        }
                        .contextMenu {
                            Button {
                                draftSessionTitle = project.title
                                editingProjectID = project.id
                            } label: {
                                Label("Rename session", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                projectPendingDelete = project
                            } label: {
                                Label("Delete session & assets", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .tint(.looplineInk)
            .navigationTitle("Your sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { isPresented = false }
            }
            .alert(
                "Delete \"\(projectPendingDelete?.title ?? "session")\"?",
                isPresented: Binding(
                    get: { projectPendingDelete != nil },
                    set: { if !$0 { projectPendingDelete = nil } }
                )
            ) {
                Button("Delete session", role: .destructive) {
                    if let target = projectPendingDelete {
                        if editingProjectID == target.id {
                            editingProjectID = nil
                        }
                        model.deleteProject(target.id)
                    }
                    projectPendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    projectPendingDelete = nil
                }
            } message: {
                Text("This will permanently delete the session and all of its recorded takes and rendered videos from this iPhone.")
            }
        }
    }

    private func commitRename(for projectID: UUID) {
        let trimmed = draftSessionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        model.renameProject(projectID, to: trimmed)
        editingProjectID = nil
    }
}
