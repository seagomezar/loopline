import Combine
import Foundation
import StoreKit

public enum LooplinePaywallTrigger: Identifiable, Equatable, Sendable {
    case general
    case fourthVoice
    case proLayout(String)
    case proExportFormat(resolution: String, format: String)
    case removeWatermark
    case syncAssist
    case unlimitedSessions

    public var id: String {
        switch self {
        case .general: "general"
        case .fourthVoice: "fourthVoice"
        case let .proLayout(title): "proLayout.\(title)"
        case let .proExportFormat(res, fmt): "proExport.\(res).\(fmt)"
        case .removeWatermark: "removeWatermark"
        case .syncAssist: "syncAssist"
        case .unlimitedSessions: "unlimitedSessions"
        }
    }

    public var eyebrow: String {
        switch self {
        case .general: "OVERDUBLY PRO"
        case .fourthVoice: "4 OR MORE VOICES"
        case .proLayout: "ALL 16 LAYOUTS"
        case .proExportFormat: "4K EXPORT"
        case .removeWatermark: "NO BADGE"
        case .syncAssist: "SYNC ASSIST"
        case .unlimitedSessions: "UNLIMITED SESSIONS"
        }
    }

    public var headline: String {
        switch self {
        case .general:
            "Own your multitrack studio forever."
        case .fourthVoice:
            "Record quartets, quintets, and full ensembles."
        case let .proLayout(layoutTitle):
            "Export with \(layoutTitle) and all 16 frame layouts."
        case .proExportFormat:
            "Export sharper videos and smaller files."
        case .removeWatermark:
            "Export a clean video without the Overdubly badge."
        case .syncAssist:
            "Line up every voice in one tap."
        case .unlimitedSessions:
            "Keep as many sessions as you want."
        }
    }

    public var subtitle: String {
        switch self {
        case .general:
            "Pay once and keep it forever. No account needed."
        case .fourthVoice:
            "Free includes up to 3 voices. Go Pro to record 4 or more."
        case .proLayout:
            "Try any layout for free. Go Pro to export with all of them."
        case .proExportFormat:
            "1080p is always free. Go Pro for 4K and smaller files."
        case .removeWatermark:
            "Remove the \"Made with Overdubly\" badge so your video is all yours."
        case .syncAssist:
            "Adjusting timing by hand is always free. Go Pro to line up parts automatically."
        case .unlimitedSessions:
            "Free includes up to 2 sessions. Go Pro for unlimited sessions."
        }
    }

    public var isFromExportAttempt: Bool {
        switch self {
        case .proLayout, .proExportFormat, .removeWatermark:
            true
        default:
            false
        }
    }
}

@MainActor
public final class LooplineStoreService: ObservableObject {
    nonisolated public static let lifetimeProductID = "com.seagomezar.loopline.pro.lifetime"
    nonisolated public static let allProductIDs: [String] = [lifetimeProductID]

    nonisolated public static let freeMaxTracks = 3
    nonisolated public static let freeMaxProjects = 2

    nonisolated public static let termsOfUseURL = URL(string: "https://seagomezar.github.io/loopline/terms-and-conditions.html")!
    nonisolated public static let privacyPolicyURL = URL(string: "https://seagomezar.github.io/loopline/privacy-policy.html")!
    nonisolated public static let supportURL = URL(string: "https://seagomezar.github.io/loopline/support.html")!

    nonisolated private static let cachedEntitlementDefaultsKey = "com.seagomezar.loopline.pro.entitlementCache"

    @Published public private(set) var products: [Product] = []
    @Published public private(set) var purchasedProductIDs: Set<String> = []
    @Published public private(set) var isLoadingProducts = false
    @Published public private(set) var isPurchasing = false
    @Published public var statusMessage: String?
    @Published public var errorMessage: String?

    private let userDefaults: UserDefaults
    private var updatesTask: Task<Void, Never>?
    private var debugOverrideProUnlocked: Bool?

    public init(userDefaults: UserDefaults = .standard, startStoreKitListeners: Bool = true) {
        self.userDefaults = userDefaults
        if userDefaults.bool(forKey: Self.cachedEntitlementDefaultsKey) {
            self.purchasedProductIDs.insert(Self.lifetimeProductID)
        }
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-LooplineTestFreeTier") {
            self.debugOverrideProUnlocked = false
            self.purchasedProductIDs.removeAll()
        } else if args.contains("-LooplineHarnessMode") || args.contains("-LooplineTestProTier") {
            self.debugOverrideProUnlocked = true
        }
        #endif
        if startStoreKitListeners {
            updatesTask = listenForTransactions()
            Task { [weak self] in
                await self?.refreshEntitlements()
                await self?.loadProducts()
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    public var isProUnlocked: Bool {
        if let override = debugOverrideProUnlocked {
            return override
        }
        return !purchasedProductIDs.isEmpty
    }

    public var lifetimeProduct: Product? {
        products.first { $0.id == Self.lifetimeProductID }
    }

    public var lifetimeDisplayPrice: String {
        lifetimeProduct?.displayPrice ?? "$0.99"
    }

    public func setDebugProUnlocked(_ unlocked: Bool?) {
        debugOverrideProUnlocked = unlocked
        if let unlocked {
            if unlocked {
                purchasedProductIDs.insert(Self.lifetimeProductID)
            } else {
                purchasedProductIDs.removeAll()
            }
        }
        objectWillChange.send()
    }

    public func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let fetched = try await Product.products(for: Self.allProductIDs)
            products = fetched.sorted { lhs, rhs in
                if lhs.id == Self.lifetimeProductID { return true }
                if rhs.id == Self.lifetimeProductID { return false }
                return lhs.price < rhs.price
            }
        } catch {
            // Keep offline capability intact when device is in Airplane Mode.
        }
    }

    @discardableResult
    public func purchase(_ product: Product) async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        errorMessage = nil
        statusMessage = nil
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                let transaction = try Self.checkVerified(verification)
                updateEntitlement(for: transaction)
                await transaction.finish()
                statusMessage = "Overdubly Pro is unlocked."
                return true
            case .userCancelled:
                return false
            case .pending:
                statusMessage = "Your purchase is waiting for approval. Pro unlocks automatically once it's approved."
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    public func restorePurchases() async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        errorMessage = nil
        statusMessage = nil
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if isProUnlocked {
                statusMessage = "Your Overdubly Pro purchase has been restored."
                return true
            } else {
                statusMessage = "No previous Overdubly Pro purchases were found for this Apple Account."
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    public func refreshEntitlements() async {
        var verifiedIDs: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }
            if transaction.revocationDate == nil, Self.allProductIDs.contains(transaction.productID) {
                verifiedIDs.insert(transaction.productID)
            }
        }
        if !verifiedIDs.isEmpty {
            purchasedProductIDs = verifiedIDs
            userDefaults.set(true, forKey: Self.cachedEntitlementDefaultsKey)
        } else if userDefaults.bool(forKey: Self.cachedEntitlementDefaultsKey) {
            // Preserve offline entitlement if verified previously and not revoked
            purchasedProductIDs = [Self.lifetimeProductID]
        } else {
            purchasedProductIDs.removeAll()
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case let .verified(transaction) = result {
                    self.updateEntitlement(for: transaction)
                    await transaction.finish()
                }
            }
        }
    }

    private func updateEntitlement(for transaction: Transaction) {
        guard Self.allProductIDs.contains(transaction.productID) else { return }
        if transaction.revocationDate == nil {
            purchasedProductIDs.insert(transaction.productID)
            userDefaults.set(true, forKey: Self.cachedEntitlementDefaultsKey)
            if debugOverrideProUnlocked == false {
                debugOverrideProUnlocked = true
            }
        } else {
            purchasedProductIDs.remove(transaction.productID)
            if purchasedProductIDs.isEmpty {
                userDefaults.set(false, forKey: Self.cachedEntitlementDefaultsKey)
            }
        }
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
