import XCTest
import StoreKit
import StoreKitTest
@testable import Supermod

@MainActor
final class StoreKitTests: XCTestCase {
    func testTemporaryAccessDoesNotCreateAnEntitlementAndPersistsSeparately() async throws {
        let suite = "Supermod.TestAccess.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = EntitlementStore(defaults: defaults)
        XCTAssertFalse(store.canAccess)
        #if DEBUG
        store.setTesterAccess(true)
        XCTAssertTrue(store.canAccess)
        XCTAssertFalse(store.entitled)
        let restored = EntitlementStore(defaults: defaults)
        XCTAssertTrue(restored.testerAccess)
        XCTAssertFalse(restored.entitled)
        restored.setTesterAccess(false)
        XCTAssertFalse(restored.canAccess)
        #else
        defaults.set(true,forKey: "supermod.developmentAccess")
        let releaseStore = EntitlementStore(defaults: defaults)
        releaseStore.setTesterAccess(true)
        XCTAssertFalse(releaseStore.testerAccess)
        XCTAssertFalse(releaseStore.canAccess)
        XCTAssertFalse(releaseStore.allowsTesterAccess)
        #endif
    }

    func testBillingGracePeriodRetainsAccessUntilEntitlementEnds() async throws {
        let config = try XCTUnwrap(Bundle(for: StoreKitTests.self).url(forResource: "Supermod", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: config)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.timeRate = .oneRenewalEveryTenSeconds
        session.shouldEnterBillingRetryOnRenewal = true
        session.billingGracePeriodIsEnabled = true
        defer { session.clearTransactions(); session.resetToDefaultState() }

        let store = EntitlementStore()
        await store.loadProducts()
        await store.purchase(.monthly)
        XCTAssertTrue(store.entitled)
        let subscription = try XCTUnwrap(store.product(.monthly)?.subscription)
        var graceTransaction: StoreKit.Transaction?
        for _ in 0..<100 {
            let statuses = try await subscription.status
            if let grace = statuses.first(where: { $0.state == .inGracePeriod }),
               case .verified(let transaction) = grace.transaction {
                graceTransaction = transaction
                break
            }
            try await Task.sleep(for: .milliseconds(200))
        }
        _ = try XCTUnwrap(graceTransaction, "The local subscription must enter billing grace before testing access.")
        await store.refresh()
        XCTAssertTrue(store.entitled, "Apple's verified billing grace entitlement must retain access.")

        // Xcode can keep a transaction in currentEntitlements after the subscription
        // status becomes revoked. Verify that this stale entry cannot retain access.
        let failedRenewal = try XCTUnwrap(session.allTransactions().first(where: {
            $0.productIdentifier == Plan.monthly.id && $0.hasPurchaseIssue
        }))
        try session.refundTransaction(identifier: failedRenewal.identifier)
        var currentGrace: StoreKit.Transaction?
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let current) = result, current.productID == Plan.monthly.id {
                currentGrace = current
            }
        }
        let staleEntry = try XCTUnwrap(currentGrace, "The local test must expose a stale current entitlement after refund.")
        let revokedStatus = await staleEntry.subscriptionStatus
        XCTAssertEqual(revokedStatus?.state, .revoked)
        guard case .verified? = revokedStatus?.transaction else {
            XCTFail("The revoked subscription status must have a verified transaction.")
            return
        }
        await store.refresh()
        XCTAssertFalse(store.entitled, "Verified revocation must override a stale current entitlement.")

        // Now refund the actual paid transaction, not just the failed renewal attempt.
        let transaction = try XCTUnwrap(session.allTransactions().first(where: {
            $0.productIdentifier == Plan.monthly.id && $0.state == .purchased && !$0.hasPurchaseIssue
        }))
        try session.refundTransaction(identifier: transaction.identifier)
        var remainingEntitlements: [StoreKit.Transaction] = []
        for _ in 0..<20 {
            remainingEntitlements = []
            for await result in StoreKit.Transaction.currentEntitlements {
                if case .verified(let current) = result,
                   Plan.allCases.contains(where: { $0.id == current.productID }) {
                    remainingEntitlements.append(current)
                }
            }
            if remainingEntitlements.isEmpty { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(remainingEntitlements.isEmpty, "The paid transaction refund must remove StoreKit's current entitlement before testing app access.")
        await store.refresh()
        XCTAssertFalse(store.entitled, "Access must end when StoreKit removes the entitlement.")
    }

    func testLocalPurchaseRestoreAndRefund() async throws {
        let config = try XCTUnwrap(Bundle(for: StoreKitTests.self).url(forResource: "Supermod", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: config)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.storefront = "IND"
        session.locale = Locale(identifier: "en_IN")
        defer { session.clearTransactions(); session.resetToDefaultState() }

        let store = EntitlementStore()
        await store.loadProducts()
        XCTAssertEqual(Set(store.products.map(\.id)), Set(Plan.allCases.map(\.id)))
        XCTAssertFalse(store.entitled)
        await store.purchase(.annual)
        XCTAssertTrue(store.entitled)
        let fresh = EntitlementStore()
        await fresh.restore()
        XCTAssertTrue(fresh.entitled)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        for _ in 0..<20 {
            await fresh.refresh()
            if !fresh.entitled { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertFalse(fresh.entitled)
    }
}
