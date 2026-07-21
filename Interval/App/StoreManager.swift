import StoreKit
import Observation

@Observable
@MainActor
final class StoreManager {
    static let shared = StoreManager()

    // Product IDs
    static let annualID   = "com.christiankasper.cadence.annual"
    static let monthlyID  = "com.christiankasper.cadence.monthly"
    static let lifetimeID = "com.christiankasper.cadence.lifetime"

    private(set) var annual:   Product?
    private(set) var monthly:  Product?
    private(set) var lifetime: Product?

    private(set) var isPro: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var purchaseError: String? = nil

    /// True while products are being fetched from the App Store.
    private(set) var isLoadingProducts: Bool = false
    /// True if the last product fetch returned nothing (no network, products
    /// not configured, Paid Apps Agreement not in effect, etc.).
    private(set) var productLoadFailed: Bool = false

    /// Whether any subscription product is available to display.
    var hasProducts: Bool { annual != nil || monthly != nil || lifetime != nil }

    // Single shared free-run pool across personal timers AND program units.
    private static let freeRunsKey = "freeRunsUsed"
    // Legacy per-category keys, migrated once into the shared pool below.
    private static let legacyPersonalRunsKey = "personalRunsUsed"
    private static let legacyProgramRunsKey = "programRunsUsed"
    static let freeRunLimit = 2
    private(set) var freeRunsUsed: Int = StoreManager.migratedFreeRunsUsed()

    /// Reads the shared counter, migrating the two legacy per-category counters
    /// into it the first time (so existing free users aren't given extra runs).
    private static func migratedFreeRunsUsed() -> Int {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: freeRunsKey) != nil {
            return defaults.integer(forKey: freeRunsKey)
        }
        let legacyTotal = defaults.integer(forKey: legacyPersonalRunsKey)
            + defaults.integer(forKey: legacyProgramRunsKey)
        let migrated = min(legacyTotal, freeRunLimit)
        defaults.set(migrated, forKey: freeRunsKey)
        defaults.removeObject(forKey: legacyPersonalRunsKey)
        defaults.removeObject(forKey: legacyProgramRunsKey)
        return migrated
    }

    /// Whether a free user may start any timer (personal or program unit).
    func canRunFreeTimer() -> Bool {
        isPro || freeRunsUsed < Self.freeRunLimit
    }

    /// Records one free run against the shared pool.
    func recordFreeRun() {
        freeRunsUsed += 1
        UserDefaults.standard.set(freeRunsUsed, forKey: Self.freeRunsKey)
    }

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        Task { await loadProducts() }
        Task { await refreshEntitlement() }
    }

    nonisolated func cancelTransactionListener() {
        Task { @MainActor in self.transactionListener?.cancel() }
    }

    // MARK: - Load products

    func loadProducts() async {
        isLoadingProducts = true
        defer {
            isLoadingProducts = false
            // An empty fetch (no agreement / no config) or a thrown error both
            // leave us with no products to show — surface that to the UI.
            productLoadFailed = !hasProducts
        }
        let ids: Set<String> = [Self.annualID, Self.monthlyID, Self.lifetimeID]
        do {
            let fetched = try await Product.products(for: ids)
            for product in fetched {
                switch product.id {
                case Self.annualID:   annual   = product
                case Self.monthlyID:  monthly  = product
                case Self.lifetimeID: lifetime = product
                default: break
                }
            }
        } catch {
            // Network or StoreKit failure — productLoadFailed is set in defer.
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product,
                  options: Set<Product.PurchaseOption> = [],
                  scheduleTrialReminder: Bool = true) async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        // Captured before purchasing — eligibility flips once the trial starts.
        // Suppressed for the monthly-commitment plan, which isn't sold on the
        // trial and must not fire a "your trial ends" reminder.
        let startsTrial: Bool
        if scheduleTrialReminder,
           product.id == Self.annualID,
           let subscription = product.subscription,
           subscription.introductoryOffer?.paymentMode == .freeTrial {
            startsTrial = await subscription.isEligibleForIntroOffer
        } else {
            startsTrial = false
        }

        do {
            let result = try await product.purchase(options: options)
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlement()
                // The paywall promises a day-5 reminder before the trial ends.
                if isPro && startsTrial {
                    TrialReminderManager.scheduleReminder()
                }
                if isPro {
                    logAttribution(for: product, startedTrial: startsTrial)
                }
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Attribution

    /// Logs the AppsFlyer conversion event for a completed purchase so Apple
    /// Search Ads installs can be attributed through to revenue.
    ///
    /// - A trial start (annual intro free-trial) logs `AFEventStartTrial` with
    ///   no revenue — money isn't due yet.
    /// - Any direct paid purchase (monthly / annual without trial / lifetime)
    ///   logs `af_purchase` with the product's price, currency, and tier.
    private func logAttribution(for product: Product, startedTrial: Bool) {
        let tier: Attribution.Tier
        switch product.id {
        case Self.annualID:   tier = .annual
        case Self.monthlyID:  tier = .monthly
        case Self.lifetimeID: tier = .lifetime
        default: return
        }

        let price = (product.price as NSDecimalNumber).doubleValue
        let currency = product.priceFormatStyle.currencyCode

        if startedTrial {
            Attribution.logTrialStart(tier: tier, price: price, currency: currency)
        } else {
            Attribution.logPurchase(tier: tier, revenue: price, currency: currency)
        }
    }

    // MARK: - Monthly-commitment billing plan (annual, paid monthly)
    //
    // Apple's "Monthly with a 12-Month Commitment" billing plan on the annual
    // subscription: same product ID as the up-front annual, billed monthly for
    // a year. Requires iOS 26.4+ and is NOT offered in the US or Singapore, so
    // `annualMonthlyCommitment` is nil for those users and the UI hides itself.

    /// A plain, version-agnostic snapshot of the commitment plan's pricing —
    /// so the rest of the app never touches iOS 26.4-only StoreKit types.
    struct CommitmentPlan {
        let perPeriodDisplayPrice: String   // e.g. "$1.99" (per month)
        let totalDisplayPrice: String       // e.g. "$23.88" (full 12-month commitment)
    }

    /// The annual plan's monthly-commitment billing option, if the current
    /// storefront + OS expose it. Reading this never affects the up-front annual.
    var annualMonthlyCommitment: CommitmentPlan? {
        guard #available(iOS 26.4, *),
              let subscription = annual?.subscription,
              let terms = subscription.pricingTerms.first(where: { $0.billingPlanType == .monthly })
        else { return nil }
        return CommitmentPlan(perPeriodDisplayPrice: terms.billingDisplayPrice,
                              totalDisplayPrice: terms.commitmentInfo.displayPrice)
    }

    /// Purchases the annual plan billed monthly over a 12-month commitment.
    @available(iOS 26.4, *)
    func purchaseAnnualMonthlyCommitment() async {
        guard let annual else { return }
        await purchase(annual,
                       options: [.billingPlanType(.monthly)],
                       scheduleTrialReminder: false)
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Entitlement

    func refreshEntitlement() async {
        var hasPro = false

        // Check lifetime (non-consumable)
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productID == Self.lifetimeID {
                    hasPro = true
                }
                if transaction.productID == Self.annualID || transaction.productID == Self.monthlyID {
                    hasPro = true
                }
            }
        }

        isPro = hasPro
    }

    // MARK: - Transaction listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if let transaction = try? checkVerified(result) {
                    await transaction.finish()
                    await refreshEntitlement()
                }
            }
        }
    }

    // MARK: - Verification helper

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value):      return value
        }
    }
}
