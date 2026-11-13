import StoreKit
import SwiftUI

@MainActor
final class PracticeAccessStore: ObservableObject {
    static let trialID = "com.qkwl3306art.pitchlab.trial7"
    static let unlockID = "com.qkwl3306art.pitchlab.lifetime"

    @Published private(set) var access: PracticeAccess = .locked
    @Published private(set) var products: [Product] = []
    @Published private(set) var trialUsed = false
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    private var trialStarted: Date?
    private var purchased = false
    private var refreshVersion = 0
    private var expiry: Task<Void, Never>?

    func run() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-unlocked") {
            access = .unlocked
            return
        }
        #endif
        async let initialLoad: Void = load()
        for await result in StoreKit.Transaction.updates {
            if case .verified(let transaction) = result, Self.owns(transaction) {
                await refresh()
                await transaction.finish()
            }
        }
        await initialLoad
    }

    private static func owns(_ transaction: StoreKit.Transaction) -> Bool {
        transaction.productID == trialID || transaction.productID == unlockID
    }

    private func load() async {
        await refresh()
        await loadProducts()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: [Self.trialID, Self.unlockID])
            if products.isEmpty { message = String(localized: "access.unavailable") }
        } catch {
            message = String(localized: "access.unavailable")
        }
    }

    func refresh() async {
        refreshVersion += 1
        let version = refreshVersion
        var trial: Date?
        var unlocked = false
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil else { continue }
            if transaction.productID == Self.unlockID { unlocked = true }
            if transaction.productID == Self.trialID {
                trial = transaction.originalPurchaseDate
            }
        }
        guard !Task.isCancelled, version == refreshVersion else { return }
        trialStarted = trial
        purchased = unlocked
        trialUsed = trial != nil
        updateAccess()
    }

    func updateAccess() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-unlocked") { return }
        #endif
        expiry?.cancel()
        access = PracticeAccess.evaluate(trialStarted: trialStarted, purchased: purchased, now: Date())
        if case .trial(let end) = access {
            expiry = Task { [weak self] in
                try? await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow)))
                guard !Task.isCancelled else { return }
                self?.updateAccess()
            }
        }
    }

    func buy(_ product: Product) async {
        guard !busy else { return }
        busy = true
        message = nil
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await refresh()
                await transaction.finish()
            case .success(.unverified):
                message = String(localized: "access.unverified")
            case .pending:
                message = String(localized: "access.pending")
            case .userCancelled:
                break
            @unknown default:
                message = String(localized: "access.failed")
            }
        } catch {
            message = String(localized: "access.failed")
        }
    }

    func restore() async {
        guard !busy else { return }
        busy = true
        message = nil
        defer { busy = false }
        do {
            try await AppStore.sync()
            await refresh()
            message = String(localized: access.allowsPractice ? "access.restored" : "access.nothingToRestore")
        } catch {
            message = String(localized: "access.failed")
        }
    }
}
