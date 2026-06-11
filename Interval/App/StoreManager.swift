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

    private static let runsKey = "personalRunsUsed"
    private static let programRunsKey = "programRunsUsed"
    static let freeRunLimit = 2
    private(set) var personalRunsUsed: Int = UserDefaults.standard.integer(forKey: runsKey)
    private(set) var programRunsUsed: Int = UserDefaults.standard.integer(forKey: programRunsKey)

    func canRunPersonalTimer() -> Bool {
        isPro || personalRunsUsed < Self.freeRunLimit
    }

    func recordPersonalRun() {
        personalRunsUsed += 1
        UserDefaults.standard.set(personalRunsUsed, forKey: Self.runsKey)
    }

    func canRunProgramUnit() -> Bool {
        isPro || programRunsUsed < Self.freeRunLimit
    }

    func recordProgramRun() {
        programRunsUsed += 1
        UserDefaults.standard.set(programRunsUsed, forKey: Self.programRunsKey)
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
            // Products unavailable (e.g. no StoreKit config in simulator) — fail silently
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlement()
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
