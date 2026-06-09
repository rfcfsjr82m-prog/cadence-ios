import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var audioSettings = AudioSettings.shared
    @AppStorage("isPremium") private var isPremium = false
    @State private var previewTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // MARK: - Audio
                    settingsSection(title: "Audio") {
                        VStack(spacing: 0) {
                            // Volume slider
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Cue Volume")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.textPrimary)
                                    Spacer()
                                    Text("\(Int(audioSettings.volume * 100))%")
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(Color.textSecondary)
                                }
                                HStack(spacing: 10) {
                                    Image(systemName: "speaker.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.textTertiary)
                                    Slider(value: $audioSettings.volume, in: 0...1)
                                        .tint(Color.accent)
                                        .onChange(of: audioSettings.volume) { _, _ in
                                            previewTask?.cancel()
                                            previewTask = Task {
                                                try? await Task.sleep(nanoseconds: 120_000_000)
                                                guard !Task.isCancelled else { return }
                                                SoundEngine.shared.preload(cues: [.bell])
                                                SoundEngine.shared.play(.bell)
                                            }
                                        }
                                    Image(systemName: "speaker.wave.3.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.textTertiary)
                                }
                            }
                            .padding(14)
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.borderDefault, lineWidth: 0.5))

                            // Duck others toggle
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Louder than music")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.textPrimary)
                                    Text("Lowers music volume while cues play")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.textTertiary)
                                }
                                Spacer()
                                Toggle("", isOn: $audioSettings.duckOthers)
                                    .labelsHidden()
                                    .tint(Color.accent)
                            }
                            .padding(14)
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.borderDefault, lineWidth: 0.5))
                            .padding(.top, 10)
                        }
                    }

                    // MARK: - Widget
                    settingsSection(title: "Widget") {
                        VStack(spacing: 0) {
                            NavigationSettingsRow(title: NSLocalizedString("Choose Widget Timers", comment: "")) {
                                WidgetTimerPickerView()
                            }
                        }
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.borderDefault, lineWidth: 0.5))
                    }

                    // MARK: - Activity
                    settingsSection(title: "Activity") {
                        VStack(spacing: 0) {
                            NavigationSettingsRow(title: "History") {
                                ActivityHistoryView()
                            }
                        }
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.borderDefault, lineWidth: 0.5))
                    }

                    // MARK: - Support
                    settingsSection(title: "Support") {
                        VStack(spacing: 0) {
                            NavigationSettingsRow(title: "FAQ") {
                                FAQView()
                            }
                            Divider().background(Color.borderDefault).padding(.horizontal, 14)
                            LinkSettingsRow(title: "Contact Support",
                                           icon: "envelope",
                                           url: URL(string: "https://cadence-interval-timer.app/contact.html")!)
                            Divider().background(Color.borderDefault).padding(.horizontal, 14)
                            LinkSettingsRow(title: "Subscription",
                                           icon: "crown",
                                           url: URL(string: "https://support.apple.com/en-us/118428?device-type=iphone")!)
                        }
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.borderDefault, lineWidth: 0.5))
                    }

                    // MARK: - Legal
                    settingsSection(title: "Legal") {
                        VStack(spacing: 0) {
                            LinkSettingsRow(title: "Privacy Policy",
                                           icon: "lock.shield",
                                           url: URL(string: "https://cadence-interval-timer.app/app-privacy.html")!)
                            Divider().background(Color.borderDefault).padding(.horizontal, 14)
                            LinkSettingsRow(title: "Terms and Conditions",
                                           icon: "doc.text",
                                           url: URL(string: "https://cadence-interval-timer.app/TermsandConditions.html")!)
                        }
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.borderDefault, lineWidth: 0.5))
                    }

                    // MARK: - Subscription badge
                    SubscriptionBadge(isPremium: isPremium)

                    // App version
                    Text("Interval · Version \(appVersion)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button { appState.navigate(to: .library) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .medium))
                        Text("Library")
                            .font(.system(size: 15))
                    }
                    .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Settings")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                // Balance the back button width
                Color.clear.frame(width: 70, height: 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.bg)
        }
    }

    // MARK: - Section builder

    @ViewBuilder
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - Row components

private struct NavigationSettingsRow<Destination: View>: View {
    let title: String
    @ViewBuilder let destination: () -> Destination

    @State private var navigate = false

    var body: some View {
        Button { navigate = true } label: {
            HStack {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $navigate) {
            destination()
                .presentationBackground(Color.bg)
        }
    }
}

private struct LinkSettingsRow: View {
    let title: String
    let icon: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Subscription badge

private struct SubscriptionBadge: View {
    let isPremium: Bool

    private var daysRemaining: Int {
        guard let first = UserDefaults.standard.object(forKey: "firstLaunchDate") as? Date else {
            return 7
        }
        let days = Calendar.current.dateComponents([.day], from: first, to: Date()).day ?? 0
        return max(0, 7 - days)
    }

    private var pillLabel: String {
        if isPremium { return NSLocalizedString("ACTIVE", comment: "") }
        if daysRemaining > 0 {
            return String(format: NSLocalizedString("%lldD LEFT", comment: ""), daysRemaining)
        }
        return NSLocalizedString("EXPIRED", comment: "")
    }

    private var subtitle: String {
        if isPremium { return NSLocalizedString("You have access to all features.", comment: "") }
        if daysRemaining > 0 {
            if daysRemaining == 1 {
                return NSLocalizedString("1 day remaining in your free trial.", comment: "")
            }
            return String(format: NSLocalizedString("%lld days remaining in your free trial.", comment: ""), daysRemaining)
        }
        return NSLocalizedString("Your free trial has expired.", comment: "")
    }

    private var pillColor: Color {
        if isPremium { return Color(hex: "F5A623") }
        return daysRemaining > 0 ? Color.accent : Color(hex: "FF6B6B")
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isPremium
                          ? Color(hex: "F5A623").opacity(0.18)
                          : Color.accent.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: isPremium ? "crown.fill" : "sparkles")
                    .font(.system(size: 18))
                    .foregroundStyle(isPremium ? Color(hex: "F5A623") : Color.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(isPremium ? "Interval Pro" : "Free Trial")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(verbatim: pillLabel)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(pillColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(pillColor.opacity(0.15))
                        .clipShape(Capsule())
                }
                Text(verbatim: subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isPremium
                    ? Color(hex: "F5A623").opacity(0.3)
                    : Color.accent.opacity(0.3),
                    lineWidth: 0.5)
        )
    }
}

// MARK: - FAQ

private struct FAQView: View {
    @Environment(\.dismiss) private var dismiss

    private var faqs: [(String, String)] {[
        (NSLocalizedString("faq.q1", comment: ""),
         NSLocalizedString("faq.a1", comment: "")),
        (NSLocalizedString("faq.q2", comment: ""),
         NSLocalizedString("faq.a2", comment: "")),
        (NSLocalizedString("faq.q3", comment: ""),
         NSLocalizedString("faq.a3", comment: "")),
        (NSLocalizedString("faq.q4", comment: ""),
         NSLocalizedString("faq.a4", comment: "")),
        (NSLocalizedString("faq.q5", comment: ""),
         NSLocalizedString("faq.a5", comment: "")),
        (NSLocalizedString("faq.q6", comment: ""),
         NSLocalizedString("faq.a6", comment: "")),
        (NSLocalizedString("faq.q7", comment: ""),
         NSLocalizedString("faq.a7", comment: "")),
        (NSLocalizedString("faq.q8", comment: ""),
         NSLocalizedString("faq.a8", comment: "")),
    ]}

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(faqs, id: \.0) { question, answer in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(question)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                Text(answer)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.textSecondary)
                                    .lineSpacing(3)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.borderDefault, lineWidth: 0.5))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("FAQ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.accent)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Legal text view

private struct LegalView: View {
    let title: String
    let content: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()
                ScrollView {
                    Text(content)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                        .lineSpacing(4)
                        .padding(20)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.accent)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Activity history

private struct ActivityHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SessionHistoryEntry.practisedAt, order: .reverse) private var history: [SessionHistoryEntry]
    @Query private var sessions: [PersistedSession]

    @State private var restoreTarget: SessionHistoryEntry? = nil
    @State private var showRestoreAlert = false
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()

                if history.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "clock")
                            .font(.system(size: 38))
                            .foregroundStyle(Color.textTertiary.opacity(0.5))
                        Text("No activity yet")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                        Text("Your sessions will appear here after you complete or stop a practice.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(history) { entry in
                                historyRow(entry)
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.accent)
                        .fontWeight(.semibold)
                }
                if !history.isEmpty {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Clear All") { showClearConfirm = true }
                            .foregroundStyle(Color.textTertiary)
                            .font(.system(size: 14))
                    }
                }
            }
            .alert("Practice deleted", isPresented: $showRestoreAlert) {
                Button("Restore & Start") {
                    guard let entry = restoreTarget, let config = entry.config() else { return }
                    var restored = config
                    restored.id = UUID()
                    restored.createdAt = Date()
                    restored.isPreset = false
                    modelContext.insert(PersistedSession(config: restored))
                    dismiss()
                    appState.startSession(restored)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This practice has been deleted. Do you want to restore and start it?")
            }
            .confirmationDialog("Clear all activity history?",
                                isPresented: $showClearConfirm,
                                titleVisibility: .visible) {
                Button("Clear History", role: .destructive) {
                    history.forEach { modelContext.delete($0) }
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    @ViewBuilder
    private func historyRow(_ entry: SessionHistoryEntry) -> some View {
        Button {
            if sessions.contains(where: { $0.id == entry.configID }) {
                guard let config = entry.config() else { return }
                dismiss()
                appState.startSession(config)
            } else {
                restoreTarget = entry
                showRestoreAlert = true
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.configName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                    Text(verbatim: durationLabel(entry))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(verbatim: dateLabel(entry.practisedAt))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                    Image(systemName: entry.wasCompleted ? "checkmark.circle.fill" : "stop.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(entry.wasCompleted ? Color.accent : Color.textTertiary)
                }
            }
            .padding(14)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.borderDefault, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func durationLabel(_ entry: SessionHistoryEntry) -> String {
        let elapsed = max(1, entry.elapsedSeconds / 60)
        let total   = max(1, entry.totalSeconds / 60)
        if entry.wasCompleted {
            return String(format: NSLocalizedString("%lld min · completed", comment: ""), total)
        } else {
            return String(format: NSLocalizedString("%lld of %lld min", comment: ""), elapsed, total)
        }
    }

    private func dateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return NSLocalizedString("Today · ", comment: "") + timeFormatter.string(from: date)
        } else if cal.isDateInYesterday(date) {
            return NSLocalizedString("Yesterday · ", comment: "") + timeFormatter.string(from: date)
        } else {
            return fullFormatter.string(from: date)
        }
    }

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    private let fullFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM · HH:mm"; return f
    }()
}

// MARK: - Placeholder legal text

private let privacyPolicyText = """
Last updated: January 2025

Interval ("we", "us", or "our") is committed to protecting your privacy.

Data We Collect
Interval does not collect, transmit, or share any personal data. All timer configurations and session data are stored locally on your device using Apple's SwiftData framework.

Apple Health
If you choose to save sessions to Apple Health, data is written directly to HealthKit on your device. We do not have access to this data and it is never transmitted to our servers.

Analytics
Interval does not use third-party analytics or tracking tools.

Changes to This Policy
We may update this Privacy Policy from time to time. Changes will be reflected in the app.

Contact
For questions about this policy, contact us at support@interval.app.
"""

private let termsOfServiceText = """
Last updated: January 2025

By using Interval, you agree to these Terms of Service.

Use of the App
Interval is provided for personal, non-commercial use. You may not reverse engineer, decompile, or create derivative works from the app.

Subscriptions
Interval may offer optional subscriptions for premium features. Subscriptions are managed through Apple's App Store and are subject to Apple's terms. You can cancel at any time through your App Store account settings.

Disclaimer of Warranties
Interval is provided "as is" without warranties of any kind. We do not guarantee that the app will be error-free or uninterrupted.

Limitation of Liability
To the maximum extent permitted by law, we are not liable for any indirect, incidental, or consequential damages arising from your use of the app.

Contact
For questions about these terms, contact us at support@interval.app.
"""
