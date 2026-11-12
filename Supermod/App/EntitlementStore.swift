import StoreKit
import SwiftUI
import OSLog

enum Plan: String, CaseIterable, Identifiable {
    case monthly, annual
    var id: String { "app.supermod.ios.\(rawValue)" }
    var title: String { self == .annual ? "Annual" : "Monthly" }
    var period: String { self == .annual ? "year" : "month" }
}

@MainActor @Observable
final class EntitlementStore {
    private(set) var products: [Product] = []
    private(set) var entitled = false
    private(set) var checked = false
    private(set) var busy = false
    private(set) var loading = false
    private(set) var message: String?
    private var expiryTask: Task<Void, Never>?
    private var refreshRevision = 0
    private let logger = Logger(subsystem: "app.supermod.ios", category: "StoreKit")
    private let defaults: UserDefaults
    private(set) var testerAccess: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-reset") {
            defaults.removeObject(forKey: "supermod.developmentAccess")
        }
        testerAccess = defaults.bool(forKey: "supermod.developmentAccess")
        #else
        testerAccess = false
        #endif
    }

    var canAccess: Bool { entitled || testerAccess }
    var allowsTesterAccess: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    func setTesterAccess(_ enabled: Bool) {
        #if DEBUG
        testerAccess = enabled
        defaults.set(enabled, forKey: "supermod.developmentAccess")
        #endif
    }


    func listen() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result, Plan.allCases.contains(where: { $0.id == transaction.productID }) {
                await refresh()
                await transaction.finish()
                Task { await SubscriptionAnalytics.syncVerifiedPurchases() }
            }
        }
    }

    func refresh() async {
        refreshRevision += 1
        let revision = refreshRevision
        var expiration: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil,
                  !transaction.isUpgraded,
                  Plan.allCases.contains(where: { $0.id == transaction.productID }) else { continue }
            let now = Date()
            var date = transaction.expirationDate ?? now
            if let status = await transaction.subscriptionStatus,
               case .verified(let latest) = status.transaction,
               case .verified(let renewal) = status.renewalInfo {
                // A refund can update verified status before currentEntitlements drops
                // its cached transaction. Terminal states must win over that stale entry.
                guard latest.revocationDate == nil, !latest.isUpgraded,
                      Plan.allCases.contains(where: { $0.id == latest.productID }),
                      status.state == .subscribed || status.state == .inGracePeriod else { continue }
                if status.state == .inGracePeriod,
                   let graceEnd = renewal.gracePeriodExpirationDate, graceEnd > now {
                    date = graceEnd
                }
            }
            // currentEntitlements includes billing grace after the paid period ends.
            // Missing renewal timing calls for a bounded recheck, not a busy loop or lockout.
            if date <= now { date = now.addingTimeInterval(60) }
            expiration = max(expiration ?? date, date)
        }
        guard revision == refreshRevision else { return }
        expiryTask?.cancel()
        entitled = expiration != nil
        checked = true
        if let expiration {
            expiryTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(max(0, expiration.timeIntervalSinceNow)))
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }

    func product(_ plan: Plan) -> Product? { products.first { $0.id == plan.id } }

    func loadProducts() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        message = nil
        do {
            products = try await Product.products(for: Plan.allCases.map(\.id))
            logger.info("Loaded \(self.products.count) of \(Plan.allCases.count) subscription products")
            if products.isEmpty {
                #if DEBUG
                message = "Test plans aren’t ready yet. Retry after sandbox setup, or continue without paying below."
                #else
                message = "Plans are unavailable right now. Please try again later."
                #endif
            }
        } catch {
            logger.error("Product request failed: \(error.localizedDescription, privacy: .public)")
            message = "Plans couldn’t load. Check your connection and try again."
        }
    }

    func purchase(_ plan: Plan) async {
        guard !busy, let product = product(plan) else { return }
        busy = true
        message = nil
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await refresh()
                await transaction.finish()
                Task { await SubscriptionAnalytics.syncVerifiedPurchases() }
                if !entitled { message = "Apple finished the purchase. Restore to check your access." }
            case .success(.unverified):
                message = "Apple returned a purchase Supermod couldn’t verify."
            case .pending:
                message = "Your purchase is pending approval from Apple."
            case .userCancelled:
                message = "Purchase canceled."
            @unknown default:
                message = "Apple returned an unknown purchase status."
            }
        } catch {
            message = "The purchase couldn’t finish. Try again or restore an existing subscription."
        }
    }

    func restore() async {
        guard !busy else { return }
        busy = true
        message = nil
        defer { busy = false }
        do {
            if !(await usesLocalTransactions()) {
                try await AppStore.sync()
            }
            await refresh()
            Task { await SubscriptionAnalytics.syncVerifiedPurchases() }
            if !entitled { message = "No active Supermod subscription was found for this Apple Account." }
        } catch {
            message = "Restore couldn’t finish. Check your Apple Account and try again."
        }
    }
    private func usesLocalTransactions() async -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["SUPERMOD_LOCAL_STOREKIT"] == "1" { return true }
        for await result in Transaction.all {
            if case .verified(let transaction) = result,
               transaction.environment == .xcode,
               Plan.allCases.contains(where: { $0.id == transaction.productID }) {
                return true
            }
        }
        #endif
        return false
    }

}

struct SubscriptionOption: View {
    let plan: Plan
    let product: Product
    let savings: String?
    let selected: Bool
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.supermodReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: { Haptics.selection(); action() }) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle().strokeBorder(selected ? PaywallPalette.accent : Palette.muted, lineWidth: 1.3)
                    if selected {
                        Circle().fill(PaywallPalette.button)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 6) { planName; price }
                } else {
                    planName
                    Spacer(minLength: 6)
                    price.multilineTextAlignment(.trailing)
                }
            }
            .padding(.horizontal, 15).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .background(selected ? PaywallPalette.selection : Palette.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(selected ? PaywallPalette.outline : Palette.line, lineWidth: selected ? 2 : 1)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: selected)
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(planDescription)
    }

    private var planDescription: String {
        let price = "\(plan.title), \(product.displayPrice) per \(plan.period)"
        guard let savings else { return price }
        return "\(price), save \(savings) compared with paying monthly for a year"
    }

    private var planName: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(plan.title).font(.headline)
            if let savings {
                Text("Save \(savings) vs. monthly")
                    .font(.caption2.weight(.bold))
                    .fixedSize(horizontal: !typeSize.isAccessibilitySize, vertical: true)
                    .foregroundStyle(PaywallPalette.plum)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(PaywallPalette.blush, in: Capsule())
            } else {
                Text(plan == .annual ? "Billed yearly" : "Billed monthly")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }

    private var price: some View {
        VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
            Text(product.displayPrice)
                .font(.title3.weight(.bold)).monospacedDigit()
                .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(typeSize.isAccessibilitySize ? 1 : 0.76)
            Text("per \(plan.period)").font(.caption).foregroundStyle(Palette.muted)
        }
    }
}

enum PolicyPage: String, Identifiable {
    case privacy = "Privacy", terms = "Terms", help = "Help"
    var id: Self { self }
    var copy: String {
        switch self {
        case .privacy:
            "Supermod stores setup, filters, and aggregate in-app usage on this device. Instagram, Facebook, and YouTube handle activity on their websites. Apple handles purchases. When connected, RevenueCat processes a pseudonymous app-user ID and subscription transaction data for subscription analytics. It does not receive your social passwords, messages, or browsing content from Supermod. Settings can remove local sessions and preferences."
        case .terms:
            "A subscription unlocks Instagram, Facebook, and YouTube inside Supermod. Apple displays purchase and renewal terms before checkout. Availability and features depend on each service’s website."
        case .help:
            "Find help with browsing, filters, and subscriptions."
        }
    }
}

struct PolicySheet: View {
    let page: PolicyPage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if page == .help {
                    help
                } else {
                    Text(page.copy).font(.body).lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(24)
                }
                if page == .terms {
                    Link("Apple Standard End User License Agreement",
                         destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 24)
                }
            }
            .background(Palette.canvas)
            .navigationTitle(page.rawValue)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { Haptics.selection(); dismiss() } } }
        }
    }

    private var help: some View {
        let answers = [
            ("Where do filters apply?", "Open a service from Supermod Home. The filters apply to the pages inside Supermod."),
            ("Why did something get through?", "Websites change how they label and display content. Open Modifications to confirm the switch is on. Sponsored content detection can miss posts."),
            ("Can I watch regular YouTube videos?", "Yes. Hide Shorts affects Shorts routes, shelves, and shortcuts. Public videos and search remain available."),
            ("How do quiet hours work?", "Set a daily start and end time in Settings. Supermod prevents opening a feed during that window."),
            ("How do I restore access?", "Open Settings and tap Restore purchases while signed in with the Apple Account used for your subscription.")
        ]
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(answers, id: \.0) { question, answer in
                DisclosureGroup {
                    Text(answer).font(.subheadline)
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 7)
                } label: {
                    Text(question).font(.body.weight(.semibold)).frame(minHeight: 44)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 7)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 15))
            }
        }
        .padding(24)
    }
}

struct PaywallContent: View {
    let purchases: EntitlementStore
    @Binding var selection: Plan
    @State private var policy: PolicyPage?
    @Environment(\.onboardingHeight) private var availableHeight
    @Environment(\.supermodReduceMotion) private var reduceMotion
    private var compact: Bool { availableHeight < 540 }

    private var annualSavings: String? {
        guard let annual = purchases.product(.annual), let monthly = purchases.product(.monthly),
              let annualPeriod = annual.subscription?.subscriptionPeriod,
              let monthlyPeriod = monthly.subscription?.subscriptionPeriod,
              annualPeriod.unit == .year, annualPeriod.value == 1,
              monthlyPeriod.unit == .month, monthlyPeriod.value == 1,
              annual.priceFormatStyle.currencyCode == monthly.priceFormatStyle.currencyCode,
              let annualAmount = displayedAmount(for: annual),
              let monthlyAmount = displayedAmount(for: monthly),
              annualAmount > 0, monthlyAmount > 0 else { return nil }
        let savings = 1 - annualAmount / (monthlyAmount * 12)
        guard savings >= Decimal(5) / 1000, savings < Decimal(995) / 1000 else { return nil }
        return savings.formatted(.percent.precision(.fractionLength(0)))
    }

    private func displayedAmount(for product: Product) -> Decimal? {
        let format = product.priceFormatStyle
        if format.format(product.price) == product.displayPrice { return product.price }
        // Local StoreKit can return a truncated numeric price for a grouped amount.
        // Show savings only when the amount matches the displayed charge.
        guard let amount = try? Decimal(product.displayPrice, format: format, lenient: false),
              format.format(amount) == product.displayPrice else { return nil }
        return amount
    }

    var body: some View {
        VStack(spacing: compact ? 6 : 9) {
            PaywallHero(compact: compact)
            Text("The original apps stay unchanged.")
                .font(.caption.weight(.medium)).foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
            VStack(spacing: 8) {
                if purchases.loading && purchases.products.isEmpty {
                    ProgressView("Loading plans…").frame(maxWidth: .infinity, minHeight: 76)
                }
                ForEach([Plan.annual, .monthly]) { plan in
                    if let product = purchases.product(plan) {
                        SubscriptionOption(plan: plan, product: product,
                                           savings: plan == .annual ? annualSavings : nil,
                                           selected: selection == plan) { selection = plan }
                    }
                }
            }
            if let message = purchases.message {
                Label(message, systemImage: "info.circle")
                    .font(.footnote).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(11)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
            }
            if purchases.allowsTesterAccess {
                Label("Development build · test purchases only", systemImage: "testtube.2")
                    .font(.caption.weight(.medium)).foregroundStyle(Palette.muted)
            }
            if !purchases.products.isEmpty {
                Text("Renews automatically. Manage or cancel in Apple subscription settings.")
                    .font(.footnote).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            }
            HStack(spacing: 22) {
                Button("Restore") { Haptics.selection(); Task { await purchases.restore() } }
                    .frame(minHeight: 44).disabled(purchases.busy).accessibilityLabel("Restore purchases")
                Button("Terms") { Haptics.selection(); policy = .terms }.frame(minHeight: 44)
                Button("Privacy") { Haptics.selection(); policy = .privacy }.frame(minHeight: 44)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(PaywallPalette.accent)
            .buttonStyle(.plain)
        }
        .task {
            if purchases.products.isEmpty { await purchases.loadProducts() }
            if purchases.product(selection) == nil,
               let firstAvailable = Plan.allCases.first(where: { purchases.product($0) != nil }) {
                selection = firstAvailable
            }
        }
        .sheet(item: $policy) { PolicySheet(page: $0) }
    }

}

private struct PaywallHero: View {
    let compact: Bool
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var revealed: Bool { appeared || reduceMotion }

    var body: some View {
        VStack(spacing: compact ? 5 : 9) {
            artwork
            Text("Make your feeds yours.")
                .font((compact ? Font.title2 : .title).weight(.bold))
                .tracking(-0.8)
                .accessibilityAddTraits(.isHeader)
            Text("Instagram, YouTube and Facebook, filtered inside Supermod.")
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(Color(hex: 0x73535C))
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(PaywallPalette.plum)
        .padding(.horizontal, 15)
        .padding(.top, compact ? 8 : 13)
        .padding(.bottom, compact ? 12 : 16)
        .frame(maxWidth: .infinity)
        .background {
            ZStack(alignment: .top) {
                LinearGradient(colors: [Color(hex: 0xFFE9DA), Color(hex: 0xF8DCE1), Color(hex: 0xF4D5DC)],
                               startPoint: .topTrailing, endPoint: .bottomLeading)
                RadialGradient(colors: [PaywallPalette.peach.opacity(0.48), .clear],
                               center: .topTrailing, startRadius: 4, endRadius: 200)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .task {
            guard !revealed else { return }
            do { try await Task.sleep(for: .milliseconds(90)) } catch { return }
            appeared = true
        }
    }

    private var artwork: some View {
        ZStack {
            ForEach(0..<3) { ring in
                Ellipse().strokeBorder(PaywallPalette.accent.opacity(0.16 - Double(ring) * 0.03))
                    .frame(width: CGFloat(106 + ring * 47), height: CGFloat((compact ? 34 : 42) + ring * 12))
                    .rotationEffect(.degrees(-10))
                    .scaleEffect(revealed ? 1 : 0.7)
                    .opacity(revealed ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.55), value: revealed)
            }

            tile(.instagram, x: -78, y: 4, rotation: -14, delay: 0.02)
            tile(.youtube, x: 77, y: 10, rotation: 12, delay: 0.14)
            tile(.facebook, x: 54, y: -25, rotation: 10, delay: 0.08)
            Circle()
                .fill(RadialGradient(colors: [PaywallPalette.peach.opacity(0.53), .clear],
                                     center: .center, startRadius: 0, endRadius: 63))
                .frame(width: 126, height: 126)
                .scaleEffect(revealed ? 1 : 0.45)
                .opacity(revealed ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.8), value: revealed)
            sparkle(x: -49, y: -18, size: 12, delay: 0.20)
            sparkle(x: 51, y: 20, size: 9, delay: 0.29)
            BrandMascot(size: compact ? 51 : 68)
                .rotationEffect(.degrees(revealed ? -4 : 5))
                .scaleEffect(revealed ? 1 : 0.68)
                .offset(y: revealed ? 0 : 9)
                .shadow(color: .black.opacity(0.28), radius: 8, y: 5)
                .animation(reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.67), value: revealed)
        }
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 60 : 76)
        .accessibilityHidden(true)
    }

    private func sparkle(x: CGFloat, y: CGFloat, size: CGFloat, delay: Double) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Color(hex: 0xB46E80))
            .scaleEffect(revealed ? 1 : 0.15)
            .opacity(revealed ? 0.85 : 0)
            .offset(x: revealed ? x : x * 0.6, y: revealed ? y : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 0.68).delay(delay), value: revealed)
    }

    private func tile(_ platform: SocialPlatform, x: CGFloat, y: CGFloat, rotation: Double, delay: Double) -> some View {
        platform.emblem
            .scaleEffect(revealed ? (compact ? 0.61 : 0.76) : 0.42)
            .rotationEffect(.degrees(revealed ? rotation : 0))
            .offset(x: revealed ? x : x * 0.45, y: (revealed ? y : y + 11) * (compact ? 0.73 : 1))
            .opacity(revealed ? 1 : 0)
            .shadow(color: .black.opacity(0.24), radius: 7, y: 3)
            .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.72).delay(delay), value: revealed)
    }
}
