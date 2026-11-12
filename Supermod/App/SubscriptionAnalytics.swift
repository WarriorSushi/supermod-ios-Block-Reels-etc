import Foundation
import OSLog
import RevenueCat

/// RevenueCat observes our verified StoreKit 2 transactions. StoreKit remains the
/// access authority, so analytics outages never prevent a paid user from entering.
@MainActor
enum SubscriptionAnalytics {
    private static let logger = Logger(subsystem: "app.supermod.ios", category: "RevenueCat")
    static func configure() {
        guard !Purchases.isConfigured,
              ProcessInfo.processInfo.environment["SUPERMOD_LOCAL_STOREKIT"] != "1",
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              !ProcessInfo.processInfo.arguments.contains("--ui-test-reset"),
              let key = Bundle.main.object(forInfoDictionaryKey: "RevenueCatPublicAPIKey") as? String,
              key.hasPrefix("appl_"), key.count > 10 else { return }
        Purchases.logLevel = .warn
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--subscription-diagnostics") {
            Purchases.logLevel = .debug
            Purchases.logHandler = { level, message in
                print("RevenueCat [\(level)]: \(message)")
            }
        }
#endif
        Purchases.configure(with: .init(withAPIKey: key)
            .with(purchasesAreCompletedBy: .myApp, storeKitVersion: .storeKit2))
    }

    static func syncVerifiedPurchases() async {
        guard Purchases.isConfigured else { return }
        do { _ = try await Purchases.shared.syncPurchases() }
        catch { logger.error("Subscription analytics sync failed: \(error.localizedDescription, privacy: .public)") }
    }
}
