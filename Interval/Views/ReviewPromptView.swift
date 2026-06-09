import SwiftUI

struct ReviewPromptView: View {
    let onDismiss: () -> Void

    @State private var selectedStars: Int = 0

    var body: some View {
        ZStack {
            // Tap outside to dismiss — snoozes for 10 sessions
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture { dismiss(reviewed: false, permanent: false) }

            VStack(spacing: 24) {

                // Icon
                Image(systemName: "heart.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.accent)

                // Copy
                VStack(spacing: 8) {
                    Text("I need your help.")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text("If Cadence is useful to you, a quick App Store review would mean a lot and help others discover the app.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                // Stars
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= selectedStars ? "star.fill" : "star")
                            .font(.system(size: 32))
                            .foregroundStyle(star <= selectedStars ? Color.yellow : Color.textTertiary)
                            .onTapGesture {
                                selectedStars = star
                                handleStarSelection(star)
                            }
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: selectedStars)

                // Buttons
                VStack(spacing: 10) {
                    if selectedStars > 0 && selectedStars <= 3 {
                        Button(action: { openAppStore() }) {
                            Text("Send feedback")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: { dismiss(reviewed: false, permanent: false) }) {
                        Text("Maybe later")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Button(action: { dismiss(reviewed: false, permanent: true) }) {
                        Text("No, I don't want to help")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(28)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.borderDefault, lineWidth: 0.5)
            )
            .padding(.horizontal, 32)
            // Prevent taps on the card from hitting the background dismiss
            .onTapGesture {}
        }
    }

    private func handleStarSelection(_ stars: Int) {
        if stars >= 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                openAppStore()
            }
        }
    }

    private func openAppStore() {
        let url = URL(string: "https://titleconverter.app/")!
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        dismiss(reviewed: true, permanent: true)
    }

    private func dismiss(reviewed: Bool, permanent: Bool) {
        if permanent {
            ReviewManager.shared.markReviewed()
        } else {
            ReviewManager.shared.snooze()
        }
        onDismiss()
    }
}
