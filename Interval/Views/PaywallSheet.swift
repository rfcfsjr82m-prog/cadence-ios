import SwiftUI
import StoreKit

struct PaywallSheet: View {
    var onPurchased: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var store = StoreManager.shared

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // ── Header ───────────────────────────────────────────────
                    VStack(spacing: 12) {
                        Image("AppIconImage")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.top, 36)

                        Text("Cadence Pro")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        Text("Run your timers as much as you want — no limits.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 32)

                    // ── Plans ────────────────────────────────────────────────
                    Group {
                        if store.isLoadingProducts && !store.hasProducts {
                            ProgressView()
                                .controlSize(.large)
                                .tint(Color.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 48)
                        } else if !store.hasProducts {
                            productLoadErrorView
                        } else {
                            plansView
                        }
                    }
                    .padding(.horizontal, 20)

                    // ── Error ────────────────────────────────────────────────
                    if let error = store.purchaseError {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 12)
                    }

                    // ── Restore ──────────────────────────────────────────────
                    Button {
                        Task {
                            await store.restorePurchases()
                            if store.isPro { finishAndSave() }
                        }
                    } label: {
                        Text("Restore purchases")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding(.top, 20)

                    // ── Legal ────────────────────────────────────────────────
                    Text("Subscription renews automatically. Cancel anytime in Settings.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 10)

                    HStack(spacing: 16) {
                        Link("Privacy Policy",
                             destination: URL(string: "https://cadence-interval-timer.app/app-privacy.html")!)
                        Text("·")
                        Link("Terms of Use (EULA)",
                             destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Color.bg)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(Color.accent)
            }
        }
        .task { await store.loadProducts() }
    }

    // MARK: - Plans

    private var plansView: some View {
        VStack(spacing: 12) {
            if let annual = store.annual {
                PlanRow(
                    product: annual,
                    label: NSLocalizedString("Annual", comment: ""),
                    badge: NSLocalizedString("7-day free trial", comment: ""),
                    detail: perMonthString(annual),
                    isHighlighted: true,
                    isLoading: store.isLoading
                ) {
                    Task { await purchase(annual) }
                }
            }

            if let monthly = store.monthly {
                PlanRow(
                    product: monthly,
                    label: NSLocalizedString("Monthly", comment: ""),
                    badge: nil,
                    detail: nil,
                    isHighlighted: false,
                    isLoading: store.isLoading
                ) {
                    Task { await purchase(monthly) }
                }
            }

            if let lifetime = store.lifetime {
                PlanRow(
                    product: lifetime,
                    label: NSLocalizedString("Lifetime", comment: ""),
                    badge: NSLocalizedString("One-time", comment: ""),
                    detail: NSLocalizedString("Pay once, keep forever", comment: ""),
                    isHighlighted: false,
                    isLoading: store.isLoading
                ) {
                    Task { await purchase(lifetime) }
                }
            }
        }
    }

    private var productLoadErrorView: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 30))
                .foregroundStyle(Color.textTertiary)

            Text("Couldn’t load subscription options.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)

            Text("Please check your internet connection and try again.")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await store.loadProducts() }
            } label: {
                Text("Retry")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.accent, in: Capsule())
            }
            .disabled(store.isLoadingProducts)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: - Helpers

    private func purchase(_ product: StoreKit.Product) async {
        await store.purchase(product)
        if store.isPro { finishAndSave() }
    }

    private func finishAndSave() {
        dismiss()
        onPurchased?()
    }

    private func perMonthString(_ product: StoreKit.Product) -> String? {
        guard let subscription = product.subscription,
              subscription.subscriptionPeriod.unit == .year else { return nil }
        let monthly = (product.price / 12).formatted(
            .currency(code: product.priceFormatStyle.currencyCode)
        )
        return String(format: NSLocalizedString("%@ / month", comment: "Price per month, e.g. 3,99 € / month"), monthly)
    }
}

// MARK: - Plan Row

private struct PlanRow: View {
    let product: StoreKit.Product
    let label: String
    let badge: String?
    let detail: String?
    let isHighlighted: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(label)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isHighlighted ? Color.white : Color.textPrimary)

                        if let badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(isHighlighted ? Color.accent : Color.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    isHighlighted
                                        ? Color.white.opacity(0.2)
                                        : Color.accent.opacity(0.12),
                                    in: Capsule()
                                )
                        }
                    }

                    if let detail {
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundStyle(isHighlighted ? Color.white.opacity(0.75) : Color.textTertiary)
                    }
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isHighlighted ? Color.white : Color.textPrimary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                isHighlighted ? Color.accent : Color.surface,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isHighlighted ? Color.clear : Color.borderDefault,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}
