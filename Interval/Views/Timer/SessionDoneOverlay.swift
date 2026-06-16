import SwiftUI
import HealthKit

enum SessionEndReason {
    case complete
    case stopped(elapsed: Int, total: Int)
}

struct SessionDoneOverlay: View {
    let reason: SessionEndReason
    let config: TimerConfig
    let startDate: Date
    let endDate: Date          // actual wall-clock time when the session ended
    let onResume: (() -> Void)?
    let onStartAgain: () -> Void
    let onBackToLibrary: () -> Void

    @State private var healthState: HealthState = .idle
    @State private var showShareSheet = false
    @AppStorage("saveToAppleHealth") private var saveToAppleHealth = false

    private enum HealthState { case idle, saving, saved, unavailable }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text(titleKey)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    subtitleView
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    // Continue button — only when session was stopped accidentally
                    if case .stopped = reason, let onResume {
                        Button(action: onResume) {
                            Text("Continue session")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    // Share button — only for completed sessions
                    if case .complete = reason {
                        Button { showShareSheet = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14))
                                Text("Share")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onStartAgain) {
                        Text("Start again")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    // Save to Health — only for completed sessions
                    if case .complete = reason {
                        if HealthKitManager.shared.isAvailable {
                            Button { saveToHealth() } label: {
                                HStack(spacing: 8) {
                                    if healthState == .saving {
                                        ProgressView()
                                            .tint(healthState == .saved ? Color.textSecondary : Color.accent)
                                            .scaleEffect(0.85)
                                    } else {
                                        Image(systemName: healthState == .saved
                                              ? "checkmark.circle.fill" : "heart.fill")
                                            .font(.system(size: 14))
                                    }
                                    Text(healthState == .saved ? "Saved to Health" : "Save to Health")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundStyle(healthState == .saved ? Color.textSecondary : Color.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.surface2)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        healthState == .saved ? Color.borderDefault : Color.accent.opacity(0.4),
                                        lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                            .disabled(healthState != .idle)
                        }
                    }

                    Button(action: onBackToLibrary) {
                        Text("Back to library")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.borderDefault, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
            }
        }
        .transition(.opacity)
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(config: config, startDate: startDate, endDate: endDate)
        }
        .task {
            // Auto-save to Apple Health when the user enabled it in Settings.
            if case .complete = reason,
               saveToAppleHealth,
               healthState == .idle,
               HealthKitManager.shared.isAvailable {
                saveToHealth()
            }
        }
    }

    // MARK: - Helpers

    private var titleKey: LocalizedStringKey {
        switch reason {
        case .complete: return "Session complete"
        case .stopped:  return "Session stopped"
        }
    }

    @ViewBuilder
    private var subtitleView: some View {
        switch reason {
        case .complete:
            Text("Well executed.")
        case .stopped(let elapsed, let total):
            Text(verbatim: "\(TimeFormatter.elapsed(elapsed)) of \(TimeFormatter.elapsed(total))")
        }
    }

    private func saveToHealth() {
        healthState = .saving
        Task {
            await HealthKitManager.shared.requestAuthorization()
            do {
                try await HealthKitManager.shared.save(
                    config: config,
                    startDate: startDate,
                    endDate: Date()
                )
                healthState = .saved
            } catch {
                healthState = .idle
            }
        }
    }
}
