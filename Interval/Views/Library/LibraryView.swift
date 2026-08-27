import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersistedSession.createdAt) private var sessions: [PersistedSession]

    @State private var selectedCategory: Category? = nil
    @State private var searchText: String = ""
    @State private var deleteTarget: TimerConfig? = nil
    @State private var showDeleteConfirm = false

    // Personal selection mode
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []

    // Programs
    @State private var selectedProtocol: TrainingProtocol? = nil

    @State private var showPaywall = false

    private var tabBinding: Binding<LibraryTab> {
        Binding(get: { appState.selectedTab },
                set: { appState.setSelectedTab($0) })
    }

    var body: some View {
        // List is the primary scroll container — this is the only reliable way to
        // support both swipe-to-delete (.swipeActions) and free vertical scrolling
        // on iOS 17, where DragGesture inside a ScrollView causes gesture conflicts.
        List {
            // ── Create card ──────────────────────────────────────────────────
            CreateTimerCard { appState.startWizard() }
                .listRowBackground(Color.bg)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 0, trailing: 20))

            // ── Segmented picker ─────────────────────────────────────────────
            Picker("", selection: tabBinding) {
                Text("Presets").tag(LibraryTab.presets)
                Text("Programs").tag(LibraryTab.programs)
                Text("Personal").tag(LibraryTab.personal)
            }
            .pickerStyle(.segmented)
            .onAppear {
                UISegmentedControl.appearance().setTitleTextAttributes(
                    [.foregroundColor: UIColor.white], for: .normal)
                UISegmentedControl.appearance().setTitleTextAttributes(
                    [.foregroundColor: UIColor.black], for: .selected)
            }
            .onChange(of: appState.selectedTab) { _, _ in
                isSelecting = false
                selectedIDs = []
                selectedCategory = nil
            }
            .listRowBackground(Color.bg)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 0, trailing: 20))

            // ── Programs tab ─────────────────────────────────────────────────
            if appState.selectedTab == .programs {
                ForEach(TrainingProtocols.all) { proto in
                    let completed = proto.units.filter {
                        appState.completedUnitIDs.contains($0.id)
                    }.count
                    ProtocolCard(
                        proto: proto,
                        completedCount: completed,
                        onTap: { selectedProtocol = proto }
                    )
                    .listRowBackground(Color.bg)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                }
            } else {
                // ── Filter pills ─────────────────────────────────────────────
                if appState.selectedTab == .presets {
                    FilterPillsView(selected: $selectedCategory)
                        .listRowBackground(Color.bg)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0))
                } else if personalCategories.count > 1 {
                    FilterPillsView(selected: $selectedCategory,
                                    categories: personalCategories)
                        .listRowBackground(Color.bg)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0))
                }

                // ── Search bar ───────────────────────────────────────────────
                SearchBar(text: $searchText)
                    .listRowBackground(Color.bg)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 0, trailing: 20))

                // ── Personal selection header ────────────────────────────────
                if appState.selectedTab == .personal && !filteredConfigs.isEmpty {
                    HStack {
                        if isSelecting && !selectedIDs.isEmpty {
                            Button { deleteSelected() } label: {
                                Text(verbatim: String(format: NSLocalizedString("Delete (%lld)", comment: ""), selectedIDs.count))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        Button {
                            isSelecting.toggle()
                            selectedIDs = []
                        } label: {
                            Text(isSelecting ? "Done" : "Select")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Color.bg)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 0, trailing: 20))
                    .animation(.easeInOut(duration: 0.2), value: isSelecting)
                }

                // ── Timer cards ──────────────────────────────────────────────
                ForEach(filteredConfigs) { config in
                    cardRow(config)
                }
            }

            // Bottom padding so last card clears the home indicator
            Color.clear.frame(height: 80)
                .listRowBackground(Color.bg)
                .listRowSeparator(.hidden)
                .listRowInsets(.init())
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Text("Library")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.textPrimary)
                Spacer()
                Button { appState.navigate(to: .settings) } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.textPrimary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .background(Color.bg)
        }
        .sheet(item: $selectedProtocol) { proto in
            ProtocolDetailView(proto: proto)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallSheet(context: .gate)
        }
        .confirmationDialog("Delete \"\(deleteTarget?.name ?? "")\"?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let target = deleteTarget { delete(target) }
            }
        }
    }

    // MARK: - Card row (List row, modifiers must be on the top-level view)

    @ViewBuilder
    private func cardRow(_ config: TimerConfig) -> some View {
        let insets = EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20)

        if appState.selectedTab == .personal && isSelecting {
            HStack(spacing: 10) {
                Button {
                    if selectedIDs.contains(config.id) { selectedIDs.remove(config.id) }
                    else { selectedIDs.insert(config.id) }
                } label: {
                    Image(systemName: selectedIDs.contains(config.id)
                          ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(selectedIDs.contains(config.id)
                                         ? Color.accent : Color.textTertiary)
                }
                .buttonStyle(.plain)
                TimerCard(
                    config: config,
                    onStart: { appState.startSession(config) },
                    onEdit: { appState.startWizard(editing: config) },
                    onDuplicate: { duplicate(config) },
                    onDelete: { deleteTarget = config; showDeleteConfirm = true },
                    isPinned: appState.pinnedTimerIDs.contains(config.id),
                    onPin: { appState.togglePin(config.id) }
                )
            }
            .listRowBackground(Color.bg)
            .listRowSeparator(.hidden)
            .listRowInsets(insets)
        } else if appState.selectedTab == .personal {
            TimerCard(
                config: config,
                onStart: {
                    guard StoreManager.shared.canRunFreeTimer() else {
                        showPaywall = true
                        return
                    }
                    StoreManager.shared.recordFreeRun()
                    appState.startSession(config)
                },
                onEdit: { appState.startWizard(editing: config) },
                onDuplicate: { duplicate(config) },
                onDelete: { deleteTarget = config; showDeleteConfirm = true },
                isPinned: appState.pinnedTimerIDs.contains(config.id),
                onPin: { appState.togglePin(config.id) },
                onTap: { appState.startWizard(editing: config) }
            )
            .listRowBackground(Color.bg)
            .listRowSeparator(.hidden)
            .listRowInsets(insets)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    deleteTarget = config
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            // Presets — no swipe, no edit/delete, but pin is supported.
            // Gated by the separate preset free pool.
            TimerCard(
                config: config,
                onStart: {
                    guard StoreManager.shared.canRunPreset() else {
                        showPaywall = true
                        return
                    }
                    StoreManager.shared.recordPresetRun()
                    appState.startSession(config)
                },
                onEdit: nil,
                onDuplicate: { duplicate(config) },
                onDelete: nil,
                isPinned: appState.pinnedTimerIDs.contains(config.id),
                onPin: { appState.togglePin(config.id) }
            )
            .listRowBackground(Color.bg)
            .listRowSeparator(.hidden)
            .listRowInsets(insets)
        }
    }

    // MARK: - Filtering

    private var allConfigs: [TimerConfig] {
        sessions.compactMap { $0.config() }
    }

    /// Categories that have at least one personal (non-preset) practice,
    /// ordered to match Category.allCases so the pills stay in a consistent sequence.
    private var personalCategories: [Category] {
        let used = Set(allConfigs.filter { !$0.isPreset }.map { $0.category })
        return Category.allCases.filter { used.contains($0) }
    }

    private var filteredConfigs: [TimerConfig] {
        var results = allConfigs.filter { config in
            guard config.isPreset == (appState.selectedTab == .presets) else { return false }
            if let cat = selectedCategory, config.category != cat { return false }
            if !searchText.isEmpty {
                if !config.matches(query: searchText) { return false }
            }
            return true
        }
        if appState.selectedTab == .presets {
            let order = appState.shuffledPresetIDs
            results.sort {
                let lPinned = appState.pinnedTimerIDs.contains($0.id)
                let rPinned = appState.pinnedTimerIDs.contains($1.id)
                if lPinned != rPinned { return lPinned }
                return (order.firstIndex(of: $0.id) ?? Int.max) <
                       (order.firstIndex(of: $1.id) ?? Int.max)
            }
        } else if appState.selectedTab == .personal {
            results.sort {
                let lPinned = appState.pinnedTimerIDs.contains($0.id)
                let rPinned = appState.pinnedTimerIDs.contains($1.id)
                if lPinned != rPinned { return lPinned }
                return $0.createdAt < $1.createdAt
            }
        }
        return results
    }

    // MARK: - Actions

    private func duplicate(_ config: TimerConfig) {
        var copy = config
        copy.id = UUID()
        copy.name = config.name + " " + NSLocalizedString("Copy", comment: "")
        copy.isPreset = false
        copy.createdAt = Date()
        copy.blocks = config.blocks.map { block in
            var b = block; b.id = UUID(); return b
        }
        modelContext.insert(PersistedSession(config: copy))
        appState.startWizard(editing: copy)
    }

    private func delete(_ config: TimerConfig) {
        if let ps = sessions.first(where: { $0.id == config.id }) {
            modelContext.delete(ps)
        }
    }

    private func deleteSelected() {
        for id in selectedIDs {
            if let ps = sessions.first(where: { $0.id == id }) {
                modelContext.delete(ps)
            }
        }
        selectedIDs = []
        isSelecting = false
    }
}

// MARK: - Supporting types
// LibraryTab is defined in AppState.swift

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.textTertiary)
            TextField("Search", text: $text)
                .font(.system(size: 14))
                .foregroundStyle(.textPrimary)
                .tint(.accent)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(Color.borderDefault, lineWidth: 0.5)
        )
    }
}
