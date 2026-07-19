import SwiftUI
import SwiftData
import WidgetKit

@main
struct IntervalApp: App {

    @State private var appState = AppState()

    init() {
        // Users who installed before onboarding shipped skip it:
        // firstLaunchDate already exists but the onboarding flag doesn't.
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "hasSeenOnboarding") == nil,
           defaults.object(forKey: "firstLaunchDate") != nil {
            defaults.set(true, forKey: "hasSeenOnboarding")
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([PersistedSession.self, SessionHistoryEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .modelContainer(sharedModelContainer)
        }
    }
}

// MARK: - Root router

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [PersistedSession]
    @AppStorage("preferredScheme") private var preferredScheme: Int = 0  // 0 system, 1 dark, 2 light
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    /// Dismissal for the current launch when the always-show testing flag is on.
    @State private var onboardingDismissedThisLaunch = false

    var body: some View {
        ZStack {
            switch appState.route {
            case .library:
                LibraryView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)))
            case .wizardStep1:
                ConfigureSequenceView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)))
            case .wizardStep2:
                OpeningClosingView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)))
            case .activeTimer:
                if let session = appState.activeSession {
                    ActiveTimerView(config: session)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)))
                }
            case .settings:
                SettingsView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)))
            }
        }
        .animation(.easeInOut(duration: 0.32), value: appState.route)
        .overlay {
            let shouldShow = FeatureFlags.alwaysShowOnboarding
                ? !onboardingDismissedThisLaunch
                : !hasSeenOnboarding
            if shouldShow {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        hasSeenOnboarding = true
                        onboardingDismissedThisLaunch = true
                    }
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(preferredScheme == 1 ? .dark : preferredScheme == 2 ? .light : nil)
        .onAppear {
            // Record first launch date for trial calculation
            if UserDefaults.standard.object(forKey: "firstLaunchDate") == nil {
                UserDefaults.standard.set(Date(), forKey: "firstLaunchDate")
            }

            let configs = sessions.compactMap { $0.config() }
            seedPresetsIfNeeded(existing: configs, insert: { config in
                modelContext.insert(PersistedSession(config: config))
            }, update: { config in
                if let ps = sessions.first(where: { $0.id == config.id }) {
                    ps.update(with: config)
                }
            })

            // Fetch remote presets (new or updated) and merge into SwiftData
            RemotePresetsManager.shared.loadAndSync(
                insert: { config in
                    modelContext.insert(PersistedSession(config: config))
                },
                update: { config in
                    if let ps = sessions.first(where: { $0.id == config.id }) {
                        ps.update(with: config)
                    }
                },
                existingIDs: {
                    Set(sessions.compactMap { $0.config() }.map(\.id))
                }
            )

            // Sync timer data to the shared App Group so the widget and
            // Watch app always reflect the latest state after the app launches.
            let allConfigs = sessions.compactMap { $0.config() }
            appState.syncPinnedSnapshots(allConfigs: allConfigs)
            SharedDefaults.writeAllTimers(allConfigs)
            SharedDefaults.writeAllSnapshots(allConfigs.map { PinnedTimerSnapshot(from: $0) })
            WatchSyncManager.shared.sync(allConfigs)
        }
        .onChange(of: appState.pinnedTimerIDs) { _, _ in
            let allConfigs = sessions.compactMap { $0.config() }
            appState.syncPinnedSnapshots(allConfigs: allConfigs)
        }
        .onChange(of: sessions) { _, _ in
            let allConfigs = sessions.compactMap { $0.config() }
            SharedDefaults.writeAllTimers(allConfigs)
            SharedDefaults.writeAllSnapshots(allConfigs.map { PinnedTimerSnapshot(from: $0) })
            WidgetCenter.shared.reloadAllTimelines()
            WatchSyncManager.shared.sync(allConfigs)
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchSyncManager.completionNotification)) { note in
            guard let configData   = note.userInfo?["configData"]    as? Data,
                  let elapsed      = note.userInfo?["elapsed"]        as? Int,
                  let wasCompleted = note.userInfo?["wasCompleted"]   as? Bool,
                  let config       = try? JSONDecoder().decode(TimerConfig.self, from: configData)
            else { return }
            let entry = SessionHistoryEntry(config: config, wasCompleted: wasCompleted, elapsedSeconds: elapsed)
            modelContext.insert(entry)
            // If a program unit was completed, refresh AppState
            if wasCompleted {
                appState.markUnitCompleted(config.id)
            }
        }
        .onOpenURL { url in
            guard url.scheme == "cadence" else { return }

            if url.host == "widget-setup" {
                // Deep link from widget empty state → open widget timer picker
                appState.showWidgetPicker = true
                return
            }

            // cadence://start/<UUID>
            guard url.host == "start",
                  let idString = url.pathComponents.last,
                  let id = UUID(uuidString: idString)
            else { return }

            let allConfigs = sessions.compactMap { $0.config() }
            if let config = allConfigs.first(where: { $0.id == id }) {
                if config.isPreset {
                    appState.startSession(config)
                } else {
                    // Custom timers are Pro-gated — don't start directly from
                    // the widget. Land on the Start & End step, whose start
                    // button enforces the free-run limit.
                    appState.wizardSession = config
                    appState.editingSessionID = config.id
                    appState.navigate(to: .wizardStep2)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { appState.showWidgetPicker },
            set: { appState.showWidgetPicker = $0 }
        )) {
            WidgetTimerPickerView()
        }
    }
}
