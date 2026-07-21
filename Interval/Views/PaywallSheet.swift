import SwiftUI
import StoreKit

// MARK: - Paywall
//
// Deliberately minimal — one decision on one screen:
//   context-aware headline → plan selection (annual pre-selected,
//   lifetime behind "View all plans") → big CTA → risk-reversal line
//   → "Not now" and legal at the bottom.
//
// Shown full-screen once after the first completed session (primary
// day-0 placement), as a sheet at the free-run gates, and from Settings
// or the onboarding Pro slide.

struct PaywallSheet: View {
    enum Context {
        /// Shown once after the user's first completed session.
        case sessionComplete
        /// A free-run gate was hit — "You've used your free runs".
        case gate
        /// Opened from Settings or the onboarding Pro slide.
        case general
    }

    var context: Context = .general
    var onPurchased: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var store = StoreManager.shared
    @State private var selectedProductID: String? = nil
    /// True when the annual "billed monthly" commitment plan is the selected
    /// row. It shares the annual product ID, so it can't be keyed off
    /// `selectedProductID` — while it's selected, `selectedProductID` is nil.
    @State private var commitmentSelected = false
    @State private var showAllPlans = false
    @State private var showDownsell = false

    /// Which plan is selected on the downsell screen. Defaults to the
    /// monthly-commitment plan when it's available (the gentler entry point),
    /// otherwise lifetime.
    private enum DownsellChoice { case monthlyCommitment, lifetime }
    @State private var downsellChoice: DownsellChoice = .lifetime

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            if showDownsell {
                downsellView
                    .transition(.opacity)
            } else {
                mainContent
                    .transition(.opacity)
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Color.bg)
        .task {
            await store.loadProducts()
            if selectedProductID == nil {
                selectedProductID = store.annual?.id ?? store.monthly?.id
            }
        }
    }

    private var mainContent: some View {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                header
                    .padding(.bottom, 20)

                reviewLine
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)

                Group {
                    if store.isLoadingProducts && !store.hasProducts {
                        ProgressView()
                            .controlSize(.large)
                            .tint(Color.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if !store.hasProducts {
                        productLoadErrorView
                    } else {
                        plansView
                    }
                }
                .padding(.horizontal, 24)

                if isAnnualSelected {
                    trialInfo
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                }

                Spacer(minLength: 0)

                ctaBar
            }
    }

    // MARK: - Header

    private var headline: String {
        switch context {
        case .sessionComplete:
            return NSLocalizedString("Keep your practice going", comment: "Paywall headline after first completed session")
        case .gate:
            return String(format: NSLocalizedString("You’ve used your %d free runs", comment: "Paywall headline at free-run gate"),
                          StoreManager.freeRunLimit)
        case .general:
            return "Cadence Pro"
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(verbatim: "Cadence")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(verbatim: "PRO")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.bg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.textPrimary, in: Capsule())
            }

            Text(headline)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
    }

    private var subtitle: String {
        switch context {
        case .sessionComplete:
            // Most first sessions are presets, which stay free — say so, then
            // sell what Pro actually adds.
            return NSLocalizedString("Presets stay free forever. Pro adds unlimited custom timers and every program.", comment: "Paywall subtitle after first completed session")
        case .gate, .general:
            return NSLocalizedString("Unlimited timers for everything you practice — with Cadence Pro.", comment: "Paywall subtitle")
        }
    }

    // MARK: - Social proof

    private var reviewLine: some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "F5A623"))
                }
            }

            Text(NSLocalizedString("“Finally an interval timer that covers many areas of life. Love the unique features like using a flashlight or vibration as a cue.”", comment: "Paywall review quote"))
                .font(.system(size: 13).italic())
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: "— Chris")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - Trial clarity (shown while the annual plan is selected)

    private var isAnnualSelected: Bool {
        guard let annualID = store.annual?.id else { return false }
        return selectedProductID == annualID
    }

    private var trialInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            trialInfoRow(NSLocalizedString("7-day free trial — no payment due now", comment: "Trial clarity line"))
            trialInfoRow(NSLocalizedString("We’ll remind you on day 5, before your trial ends", comment: "Trial clarity line"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trialInfoRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.accent)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Plans

    private var savingsPercent: Int? {
        guard let annual = store.annual, let monthly = store.monthly else { return nil }
        let yearAtMonthly = monthly.price * 12
        guard yearAtMonthly > annual.price else { return nil }
        let fraction = (yearAtMonthly - annual.price) / yearAtMonthly
        let percent = (fraction as NSDecimalNumber).doubleValue * 100
        return Int(percent.rounded())
    }

    private var plansView: some View {
        VStack(spacing: 10) {
            if let annual = store.annual {
                // The trial is communicated by the CTA and the reassurance
                // line — the row only carries the savings badge.
                let badge = savingsPercent.map {
                    String(format: NSLocalizedString("SAVE %d%%", comment: "Savings badge on annual plan"), $0)
                }
                PlanRow(
                    product: annual,
                    label: NSLocalizedString("Annual", comment: ""),
                    badge: badge,
                    detail: perMonthString(annual),
                    isSelected: selectedProductID == annual.id
                ) {
                    selectedProductID = annual.id
                    commitmentSelected = false
                }
            }

            if let monthly = store.monthly {
                PlanRow(
                    product: monthly,
                    label: NSLocalizedString("Monthly", comment: ""),
                    badge: nil,
                    detail: nil,
                    isSelected: selectedProductID == monthly.id
                ) {
                    selectedProductID = monthly.id
                    commitmentSelected = false
                }
            }

            // "View all plans" reveals the pay-once Lifetime option and, where
            // Apple offers it, the annual plan billed monthly over a 12-month
            // commitment (self-hiding: `annualMonthlyCommitment` is nil in the
            // US/Singapore and below iOS 26.4).
            let hasMorePlans = store.lifetime != nil || store.annualMonthlyCommitment != nil
            if hasMorePlans {
                if showAllPlans {
                    if let commitment = store.annualMonthlyCommitment, let annual = store.annual {
                        PlanRow(
                            product: annual,
                            label: NSLocalizedString("Annual, billed monthly", comment: "Monthly-commitment plan label in the all-plans list"),
                            badge: nil,
                            detail: String(format: NSLocalizedString("for 12 months · %@ total", comment: "Monthly-commitment plan detail"),
                                           commitment.totalDisplayPrice),
                            priceText: commitment.perPeriodDisplayPrice,
                            isSelected: commitmentSelected
                        ) {
                            commitmentSelected = true
                            selectedProductID = nil
                        }
                    }

                    if let lifetime = store.lifetime {
                        PlanRow(
                            product: lifetime,
                            label: NSLocalizedString("Lifetime", comment: ""),
                            badge: NSLocalizedString("One-time", comment: ""),
                            detail: NSLocalizedString("Pay once, keep forever", comment: ""),
                            isSelected: selectedProductID == lifetime.id
                        ) {
                            selectedProductID = lifetime.id
                            commitmentSelected = false
                        }
                    }
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showAllPlans = true }
                    } label: {
                        Text(NSLocalizedString("View all plans", comment: "Reveals the lifetime plan"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }

            if let error = store.purchaseError {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - CTA + footer

    private var ctaTitle: String {
        if commitmentSelected {
            return NSLocalizedString("Start monthly plan", comment: "Downsell CTA for the monthly-commitment plan")
        }
        if let annualID = store.annual?.id, selectedProductID == annualID {
            return NSLocalizedString("Start my 7-day free trial", comment: "Paywall CTA for the annual plan with trial")
        }
        return NSLocalizedString("Continue", comment: "")
    }

    /// Shown under the CTA for the non-trial plans only — while annual is
    /// selected the trial-clarity block already covers it.
    private var reassuranceText: String? {
        if commitmentSelected {
            return NSLocalizedString("Billed monthly · 12-month commitment", comment: "Reassurance under the monthly-commitment CTA")
        }
        if isAnnualSelected { return nil }
        if let lifetimeID = store.lifetime?.id, selectedProductID == lifetimeID {
            return NSLocalizedString("One-time purchase — no subscription", comment: "Reassurance under CTA")
        }
        return NSLocalizedString("Cancel anytime", comment: "Reassurance under CTA")
    }

    private var ctaBar: some View {
        VStack(spacing: 10) {
            Button {
                Task { await purchaseSelected() }
            } label: {
                HStack(spacing: 8) {
                    if store.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(ctaTitle)
                            .font(.system(size: 17, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(store.isLoading || (selectedProduct == nil && !commitmentSelected))
            .opacity((selectedProduct == nil && !commitmentSelected) ? 0.5 : 1)

            if let reassuranceText {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                    Text(reassuranceText)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.textSecondary)
            }

            Button {
                if shouldOfferDownsell {
                    downsellChoice = store.annualMonthlyCommitment != nil ? .monthlyCommitment : .lifetime
                    withAnimation(.easeInOut(duration: 0.25)) { showDownsell = true }
                } else {
                    dismiss()
                }
            } label: {
                Text(NSLocalizedString("Not now", comment: ""))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)

            legalFooter
                .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
    }

    private var legalFooter: some View {
        VStack(spacing: 5) {
            Text(commitmentSelected
                 ? NSLocalizedString("Billed monthly for a 12-month commitment, then renews automatically. Cancel anytime after the commitment.", comment: "Monthly-commitment legal terms")
                 : NSLocalizedString("Subscription renews automatically. Cancel anytime.", comment: ""))
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            HStack(spacing: 12) {
                Button {
                    Task {
                        await store.restorePurchases()
                        if store.isPro { finishAndSave() }
                    }
                } label: {
                    Text(NSLocalizedString("Restore purchases", comment: ""))
                }
                .buttonStyle(.plain)
                Text("·")
                Link(NSLocalizedString("Privacy Policy", comment: ""),
                     destination: URL(string: "https://cadence-interval-timer.app/app-privacy.html")!)
                Text("·")
                Link(NSLocalizedString("Terms of Use (EULA)", comment: ""),
                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - Downsell exit offer
    //
    // Shown once when the user declines the main paywall at a gate or after
    // the first session — but only if they never expanded "View all plans".
    // Offers gentler ways in than the up-front annual: the monthly-commitment
    // billing plan (annual billed monthly; iOS 26.4+, not US/Singapore) and/or
    // the lifetime one-time purchase. A second "No thanks" dismisses for real.

    private var shouldOfferDownsell: Bool {
        (context == .gate || context == .sessionComplete)
            && !showAllPlans
            && (store.lifetime != nil || store.annualMonthlyCommitment != nil)
    }

    private var downsellView: some View {
        let commitment = store.annualMonthlyCommitment
        return VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text(verbatim: "Cadence")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(verbatim: "PRO")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.bg)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.textPrimary, in: Capsule())
                }

                Text(commitment != nil
                     ? NSLocalizedString("A gentler way in", comment: "Downsell headline when monthly-commitment is available")
                     : NSLocalizedString("Prefer to pay once?", comment: "Lifetime exit offer headline"))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Text(commitment != nil
                     ? NSLocalizedString("Spread it across the year, or unlock everything for good.", comment: "Downsell subtitle when monthly-commitment is available")
                     : NSLocalizedString("Skip the subscription — get every Pro feature forever with a single purchase.", comment: "Lifetime exit offer subtitle"))
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            .padding(.bottom, 28)

            VStack(spacing: 10) {
                if let commitment {
                    downsellCard(
                        title: NSLocalizedString("Monthly", comment: "Monthly-commitment plan label"),
                        price: commitment.perPeriodDisplayPrice,
                        detail: String(format: NSLocalizedString("for 12 months · %@ total", comment: "Monthly-commitment plan detail"),
                                       commitment.totalDisplayPrice),
                        isSelected: downsellChoice == .monthlyCommitment
                    ) { downsellChoice = .monthlyCommitment }
                }

                if let lifetime = store.lifetime {
                    downsellCard(
                        title: NSLocalizedString("Lifetime", comment: ""),
                        price: lifetime.displayPrice,
                        detail: NSLocalizedString("Pay once, keep forever", comment: ""),
                        isSelected: downsellChoice == .lifetime
                    ) { downsellChoice = .lifetime }
                }
            }
            .padding(.horizontal, 24)

            if let error = store.purchaseError {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Button {
                    Task { await purchaseDownsell() }
                } label: {
                    HStack(spacing: 8) {
                        if store.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(downsellCTATitle)
                                .font(.system(size: 17, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(store.isLoading)

                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                    Text(downsellReassurance)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.textSecondary)

                Button {
                    dismiss()
                } label: {
                    Text(NSLocalizedString("No thanks", comment: "Dismisses the lifetime exit offer"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)

                downsellLegalFooter
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
        }
    }

    private var downsellCTATitle: String {
        switch downsellChoice {
        case .monthlyCommitment:
            return NSLocalizedString("Start monthly plan", comment: "Downsell CTA for the monthly-commitment plan")
        case .lifetime:
            return NSLocalizedString("Get lifetime access", comment: "Lifetime exit offer CTA")
        }
    }

    private var downsellReassurance: String {
        switch downsellChoice {
        case .monthlyCommitment:
            return NSLocalizedString("Billed monthly · 12-month commitment", comment: "Reassurance under the monthly-commitment CTA")
        case .lifetime:
            return NSLocalizedString("One-time purchase — no subscription", comment: "Reassurance under CTA")
        }
    }

    private func purchaseDownsell() async {
        switch downsellChoice {
        case .monthlyCommitment:
            if #available(iOS 26.4, *) {
                await store.purchaseAnnualMonthlyCommitment()
            }
        case .lifetime:
            guard let lifetime = store.lifetime else { return }
            await store.purchase(lifetime)
        }
        if store.isPro { finishAndSave() }
    }

    private func downsellCard(title: String, price: String, detail: String,
                              isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .foregroundStyle(isSelected ? Color.accent : Color.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                Text(price)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(
                isSelected ? Color.accent.opacity(0.08) : Color.surface,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? Color.accent : Color.borderDefault,
                                  lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    /// Legal footer for the downsell. Shows the subscription-renewal terms only
    /// when the monthly-commitment (a subscription) is the selected plan;
    /// lifetime is a one-time purchase with no renewal.
    private var downsellLegalFooter: some View {
        VStack(spacing: 5) {
            if downsellChoice == .monthlyCommitment {
                Text(NSLocalizedString("Billed monthly for a 12-month commitment, then renews automatically. Cancel anytime after the commitment.", comment: "Monthly-commitment legal terms"))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            HStack(spacing: 12) {
                Button {
                    Task {
                        await store.restorePurchases()
                        if store.isPro { finishAndSave() }
                    }
                } label: {
                    Text(NSLocalizedString("Restore purchases", comment: ""))
                }
                .buttonStyle(.plain)
                Text("·")
                Link(NSLocalizedString("Privacy Policy", comment: ""),
                     destination: URL(string: "https://cadence-interval-timer.app/app-privacy.html")!)
                Text("·")
                Link(NSLocalizedString("Terms of Use (EULA)", comment: ""),
                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - Product load error

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
                Task {
                    await store.loadProducts()
                    if selectedProductID == nil {
                        selectedProductID = store.annual?.id ?? store.monthly?.id
                    }
                }
            } label: {
                Text("Retry")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(store.isLoadingProducts)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Helpers

    private var selectedProduct: StoreKit.Product? {
        [store.annual, store.monthly, store.lifetime]
            .compactMap { $0 }
            .first { $0.id == selectedProductID }
    }

    private func purchaseSelected() async {
        if commitmentSelected {
            if #available(iOS 26.4, *) { await store.purchaseAnnualMonthlyCommitment() }
            if store.isPro { finishAndSave() }
            return
        }
        guard let product = selectedProduct else { return }
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
    /// Overrides the displayed price. Used by the annual "billed monthly"
    /// commitment row, whose price isn't `product.displayPrice` (that's the
    /// up-front annual) but the per-month billing price.
    var priceText: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .foregroundStyle(isSelected ? Color.accent : Color.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(label)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)

                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.accent, in: Capsule())
                                .lineLimit(1)
                        }
                    }

                    if let detail {
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                Spacer()

                Text(priceText ?? product.displayPrice)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(
                isSelected ? Color.accent.opacity(0.08) : Color.surface,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? Color.accent : Color.borderDefault,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
