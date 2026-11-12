import SwiftUI

extension Animation {
    static let onboardingSpring = Animation.spring(response: 0.5, dampingFraction: 0.9)
}

enum Palette {
    static let canvas = adaptive(0xFAFAF8, 0x101110)
    static let ink = adaptive(0x121212, 0xF5F5F0)
    static let muted = adaptive(0x696966, 0xAEAEA8)
    static let surface = adaptive(0xF1F1EE, 0x1C1E1B)
    static let line = adaptive(0xDEDEDA, 0x353832)
    static let lime = Color(hex: 0xF0CFD6)
    static let selection = adaptive(0xF5ECEC, 0x34282D)
    static let forest = Color(hex: 0x31252A)

    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light) })
    }
}

enum PaywallPalette {
    static let canvas = Palette.adaptive(0xFCFAF8, 0x151315)
    static let selection = Palette.adaptive(0xFFF0EE, 0x35242C)
    static let accent = Palette.adaptive(0x282126, 0xF6E4E9)
    static let outline = Palette.adaptive(0xD6A0AA, 0xCA939F)
    static let button = Color.black
    static let blush = Color(hex: 0xFFD5DC)
    static let peach = Color(hex: 0xFFD1AA)
    static let plum = Color(hex: 0x471329)
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255, alpha: 1)
    }
}

extension Color {
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }
}

struct PrimaryButton: View {
    let title: String
    var icon: String? = "arrow.right"
    var enabled = true
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        Button(action: { Haptics.selection(); action() }) {
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, textSize.isAccessibilitySize ? 24 : 40)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 56)
                .overlay(alignment: .trailing) {
                    if let icon, !textSize.isAccessibilitySize {
                        Image(systemName: icon)
                            .font(.subheadline.weight(.semibold))
                            .padding(.trailing, 20)
                            .accessibilityHidden(true)
                    }
                }
                .foregroundStyle(enabled ? Color.white : Palette.muted)
                .background {
                    Capsule().fill(enabled ? Color.black : Palette.surface)
                        .overlay {
                            if enabled {
                                Capsule().fill(LinearGradient(stops: [
                                    .init(color: .white.opacity(0.12), location: 0),
                                    .init(color: .clear, location: 0.48)
                                ], startPoint: .top, endPoint: .bottom))
                                Capsule().strokeBorder(LinearGradient(colors: [
                                    .white.opacity(0.58), .white.opacity(0.08), Color(hex: 0xD9C9CB).opacity(0.34)
                                ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                            }
                        }
                }
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
    }
}

struct PressStyle: ButtonStyle {
    @Environment(\.supermodReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct CircleButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: { Haptics.selection(); action() }) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(Palette.surface, in: Circle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

struct BrandMascot: View {
    let size: CGFloat

    var body: some View {
        Image("BrandMascot")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.23))
            .accessibilityHidden(true)
    }
}

struct Brand: View {
    var body: some View {
        HStack(spacing: 8) {
            BrandMascot(size: 33)
            Text("Supermod").font(.headline.weight(.bold)).tracking(-0.5)
        }
        .accessibilityElement(children: .combine)
    }
}

struct BrandLaunchView: View {
    var body: some View {
        ZStack {
            Color("LaunchCream").ignoresSafeArea()
            Image("LaunchMascot-layer").resizable().scaledToFit().frame(width: 144,height: 144)
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}

struct Heading: View {
    let title: String
    var detail: String? = nil
    var centered = false
    var hero = false
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize = 36.0
    @ScaledMetric(relativeTo: .title) private var titleSize = 28.0

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 10) {
            Text(title)
                .font(.system(size: hero ? heroSize : titleSize, weight: .bold))
                .tracking(hero ? -1.9 : -1)
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(detail).font(.body).foregroundStyle(Palette.muted).lineSpacing(3)
            }
        }
        .multilineTextAlignment(centered ? .center : .leading)
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct SelectionRow: View {
    let title: String
    var detail: String?
    var symbol: String?
    let selected: Bool
    let action: () -> Void
    @Environment(\.supermodReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: { Haptics.selection(); action() }) {
            HStack(spacing: 13) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.body.weight(.medium))
                        .frame(width: 37, height: 37)
                        .background(Palette.canvas, in: Circle())
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.body.weight(.semibold))
                    if let detail { Text(detail).font(.subheadline).foregroundStyle(Palette.muted) }
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Palette.ink : Palette.muted)
                    .accessibilityHidden(true)
            }
            .multilineTextAlignment(.leading)
            .padding(14)
            .frame(minHeight: 55)
            .background(selected ? PaywallPalette.selection : Palette.surface, in: RoundedRectangle(cornerRadius: 17))
            .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(selected ? PaywallPalette.outline : Palette.line) }
        }
        .buttonStyle(PressStyle())
        .animation(reduceMotion ? nil : .onboardingSpring, value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ProgressTrack: View {
    let step: Step
    var body: some View {
        GeometryReader { proxy in
            Capsule().fill(Palette.line).overlay(alignment: .leading) {
                Capsule().fill(PaywallPalette.accent)
                    .frame(width: proxy.size.width * Double(step.journeyIndex) / Double(Step.journey.count - 1))
            }
        }
        .frame(height: 3)
        .accessibilityLabel("Setup progress")
        .accessibilityValue("Step \(step.journeyIndex + 1) of \(Step.journey.count)")
    }
}

struct OnboardingScaffold<Content: View, Footer: View>: View {
    let step: Step
    let back: () -> Void
    let content: (CGFloat) -> Content
    let footer: Footer
    let forward: Bool
    let commitExpanded: Bool
    let commitProgress: Double
    let liquidFill: Bool
    @Environment(\.supermodReduceMotion) private var reduceMotion

    init(step: Step, forward: Bool = true, commitExpanded: Bool = false, commitProgress: Double = 0, liquidFill: Bool = false, back: @escaping () -> Void, @ViewBuilder content: @escaping (CGFloat) -> Content, @ViewBuilder footer: () -> Footer) {
        self.step = step
        self.forward = forward
        self.commitExpanded = commitExpanded
        self.commitProgress = commitProgress
        self.liquidFill = liquidFill
        self.back = back
        self.content = content
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 15) {
                if step == .welcome {
                    Color.clear.frame(height: 6)
                } else {
                    CircleButton(symbol: "chevron.left", label: "Back", action: back)
                    ProgressTrack(step: step)
                }
            }
            .frame(minHeight: step == .welcome ? 6 : 48)
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 2)
            .opacity(commitProgress > 0 ? 0 : 1)
            .allowsHitTesting(commitProgress == 0 && !commitExpanded)
            GeometryReader { geometry in
                ZStack {
                    ScrollView {
                        content(geometry.size.height)
                            .frame(maxWidth: 500)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 18)
                            .frame(maxWidth: .infinity,
                                   minHeight: centeredStage ? geometry.size.height : nil,
                                   alignment: centeredStage ? .center : .top)
                    }
                    .scrollIndicators(.hidden)
                    .id(step)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .opacity.combined(with: .offset(x: forward ? 30 : -30, y: 8)),
                        removal: .opacity.combined(with: .offset(x: forward ? -18 : 18))
                    ))
                }
                .clipped()
            }
            footer
                .frame(maxWidth: 500)
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .opacity(commitProgress > 0 ? 0 : 1)
                .allowsHitTesting(commitProgress == 0 && !commitExpanded)
        }
        .backgroundPreferenceValue(CommitOriginKey.self) { anchor in
            GeometryReader { geometry in
                if let anchor, step == .commit, !reduceMotion {
                    let origin = geometry[anchor]
                    let radius = hypot(max(origin.midX, geometry.size.width - origin.midX),
                                       max(origin.midY, geometry.size.height - origin.midY)) + 2
                    Circle().fill(.black)
                        .frame(width: origin.width, height: origin.height)
                        .scaleEffect(1 + (radius * 2 / max(1, origin.width) - 1) * commitProgress)
                        .position(x: origin.midX, y: origin.midY)
                }
            }
            .ignoresSafeArea()
        }
        .foregroundStyle(Palette.ink)
        .backgroundPreferenceValue(ScrollingWeeksOriginKey.self) { anchor in
            if liquidFill {
                GeometryReader { geometry in
                    RedBlobFill(source: anchor.map { geometry[$0] })
                }
                .ignoresSafeArea()
            }
        }
        .background(PaywallPalette.canvas.ignoresSafeArea())
    }

    private var centeredStage: Bool {
        [.welcome, .personalize, .possibilities, .reassurance, .commit, .saved].contains(step)
    }
}

struct InfoLine: View {
    let icon: String
    let title: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .frame(width: 36, height: 36)
                .background(Palette.selection, in: RoundedRectangle(cornerRadius: 11))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.semibold))
                if let detail { Text(detail).font(.subheadline).foregroundStyle(Palette.muted) }
            }
            .padding(.top, 3)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingHeightKey: EnvironmentKey { static let defaultValue: CGFloat = 650 }
extension EnvironmentValues {
    var onboardingHeight: CGFloat {
        get { self[OnboardingHeightKey.self] }
        set { self[OnboardingHeightKey.self] = newValue }
    }
}

extension EnvironmentValues {
    var supermodReduceMotion: Bool {
        #if DEBUG
        accessibilityReduceMotion || ProcessInfo.processInfo.arguments.contains("--ui-test-reduce-motion")
        #else
        accessibilityReduceMotion
        #endif
    }
}

/// Reuse the feedback engine and coalesce duplicate events from nested controls.
@MainActor
enum Haptics {
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static var lastSelection: TimeInterval = 0

    static func selection() {
        guard UIApplication.shared.applicationState == .active else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastSelection > 0.06 else { return }
        lastSelection = now
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }
}
