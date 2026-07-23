import SwiftUI
import SwiftData
import WidgetKit
import AppsFlyerLib

// MARK: - AppsFlyer attribution
//
// AppsFlyer ties Apple Search Ads installs through to trial-starts and
// subscription purchases. Configuration lives here (app entry point); the
// two conversion events are logged from `StoreManager.purchase(_:)`.
//
// ATT: we deliberately never set `waitForATTUserAuthorization` and never touch
// AppTrackingTransparency — AppsFlyer attribution for ASA does not require ATT,
// so no tracking prompt is shown.

enum Attribution {
    /// AppsFlyer dev key (App Settings → Dev Key). Confirmed against the
    /// dashboard 2026-07-19.
    static let devKey = "cxSKhNTjZpEdkSDbBCPgC4"
    static let appleAppID = "6778636283"

    enum Tier: String { case monthly, annual, lifetime }

    /// Configure the SDK. Called once from `AppDelegate`.
    static func configure() {
        let af = AppsFlyerLib.shared()
        af.appsFlyerDevKey = devKey
        af.appleAppID = appleAppID
        #if DEBUG
        af.isDebug = true
        // Printed so you can register this device in AppsFlyer → Test devices.
        print("📊 AppsFlyer IDFV:", UIDevice.current.identifierForVendor?.uuidString ?? "nil")
        print("📊 AppsFlyer UID:", af.getAppsFlyerUID())
        #endif
    }

    /// Start reporting. Must run while the app is in the foreground, so it is
    /// driven off `scenePhase == .active`.
    static func start() {
        AppsFlyerLib.shared().start()
    }

    /// A free trial began (annual plan, intro free-trial offer).
    static func logTrialStart(tier: Tier, price: Double, currency: String) {
        AppsFlyerLib.shared().logEvent(AFEventStartTrial, withValues: [
            AFEventParamContentId: tier.rawValue,
            AFEventParamContentType: "subscription",
            AFEventParamPrice: price,
            AFEventParamCurrency: currency,
        ])
    }

    /// A paid subscription or lifetime unlock was purchased.
    static func logPurchase(tier: Tier, revenue: Double, currency: String) {
        AppsFlyerLib.shared().logEvent(AFEventPurchase, withValues: [
            AFEventParamRevenue: revenue,
            AFEventParamCurrency: currency,
            AFEventParamContentId: tier.rawValue,
            AFEventParamContentType: tier == .lifetime ? "lifetime" : "subscription",
        ])
    }
}

// AppsFlyer's setup expects a UIApplicationDelegate for launch + URL callbacks.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Attribution.configure()
        return true
    }

    // Forward deep links / universal links to AppsFlyer for deferred
    // deep-link attribution. SwiftUI's own `.onOpenURL` still fires for the
    // app's `cadence://` scheme — these callbacks coexist with it.
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        AppsFlyerLib.shared().handleOpen(url, options: options)
        return true
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        return true
    }
}

@main
struct IntervalApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

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
        // `.automatic` mirrors the local store to the user's private CloudKit
        // database, so custom timers and history survive delete/reinstall and
        // sync across the user's devices. Users not signed into iCloud still get
        // the plain local store — sync just no-ops for them.
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
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
        .onChange(of: scenePhase) { _, newPhase in
            // AppsFlyer's start() must fire in the foreground; the SDK is
            // already configured in AppDelegate.didFinishLaunching.
            if newPhase == .active {
                Attribution.start()
            }
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
            // Restore an in-progress session that outlived the app — e.g. iOS
            // suspended or terminated us in the background while the Live
            // Activity kept counting on the lock screen. Wall-clock anchoring
            // means we resume at the correct elapsed time.
            if appState.activeSession == nil, let snap = ActiveSessionStore.load() {
                if snap.currentElapsed < snap.config.totalDurationSeconds {
                    appState.restoreActiveSession(snap)
                } else {
                    ActiveSessionStore.clear()
                }
            }

            // Record first launch date for trial calculation
            if UserDefaults.standard.object(forKey: "firstLaunchDate") == nil {
                UserDefaults.standard.set(Date(), forKey: "firstLaunchDate")
            }

            // CloudKit mirroring dropped the `.unique` constraint on
            // PersistedSession.id, so two devices can each seed the same
            // built-in preset before syncing. Collapse any such duplicates,
            // keeping the most recently created record for each id.
            let byID = Dictionary(grouping: sessions, by: { $0.id })
            for (_, dupes) in byID where dupes.count > 1 {
                for extra in dupes.sorted(by: { $0.createdAt > $1.createdAt }).dropFirst() {
                    modelContext.delete(extra)
                }
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

            if url.host == "resume" {
                // Tapped the lock-screen Live Activity — return to the running
                // session (restoring it from disk if the app was terminated).
                if appState.activeSession != nil {
                    appState.navigate(to: .activeTimer)
                } else if let snap = ActiveSessionStore.load(),
                          snap.currentElapsed < snap.config.totalDurationSeconds {
                    appState.restoreActiveSession(snap)
                }
                return
            }

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
