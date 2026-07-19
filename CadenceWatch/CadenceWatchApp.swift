import SwiftUI

@main
struct CadenceWatchApp: App {
    // Initialise early so WCSession is activated before TimerListView appears
    @ObservedObject private var connectivity = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            TimerListView()
        }
    }
}
