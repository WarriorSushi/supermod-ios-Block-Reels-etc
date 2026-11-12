import SwiftUI
import UIKit

struct EstimateSlider: View {
    @Binding var hours: Double?
    @Environment(\.supermodReduceMotion) private var reduceMotion
    private let average = 4.8
    var body: some View {
        VStack(spacing: 0) {
            Text("\((hours ?? average).formatted(.number.precision(.fractionLength(1)))) hours")
                .font(.system(size: 34,weight: .bold)).monospacedDigit().contentTransition(.numericText())
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: hours)
            Text("per day").font(.caption).foregroundStyle(Palette.muted).padding(.top, 6)
            GeometryReader { g in
                VStack(spacing: 0) {
                    Text("Average usage").font(.system(size: 10,weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 5).background(Color(hex: 0xF33035),in: Capsule())
                    Rectangle().fill(Color(hex: 0xF33035)).frame(width: 1,height: 16)
                }.position(x: 14 + (g.size.width - 28) * (average - 1) / 7, y: 18)
            }.frame(height: 36).padding(.top, 22)
            Slider(value: Binding(get: { hours ?? average },set: { hours = $0 }),in: 1...8,step: 0.1)
                .tint(Palette.ink)
                .accessibilityLabel("Estimated daily scrolling")
                .accessibilityValue("\((hours ?? average).formatted()) hours per day")
            HStack { Text("1 hr"); Spacer(); Text("8+ hrs") }.font(.caption2).foregroundStyle(Palette.muted).padding(.top, 8)
            Text("Your daily average: adjust the estimate to match your own day.")
                .font(.caption2).foregroundStyle(Palette.muted).multilineTextAlignment(.center).padding(.top, 30)
        }.padding(.top, 38).sensoryFeedback(.selection, trigger: hours)
    }
}

struct LifeProjection {
    let age: Int
    let hours: Double
    init(setup: Setup) { age = min(100,max(13,setup.age ?? 18)); hours = min(16,max(0,setup.hours ?? 4.8)) }
    var horizon: Int { max(80,age + 1) }
    var remainingYears: Double { Double(horizon - age) }
    var livedFraction: Double { Double(age) / Double(horizon) }
    var asleepFraction: Double { (1 - livedFraction) / 3 }
    var scrollingFraction: Double { (1 - livedFraction) * hours / 24 }
    var wakingPercent: Double { hours / 16 * 100 }
    var minutes: Double { remainingYears * 365.25 * hours * 60 }
    var scrollingYears: Double { remainingYears * hours / 24 }
}

struct LifeWeeksView: View {
    let setup: Setup
    let phase: Int
    @Environment(\.onboardingHeight) private var availableHeight
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @State private var revealed = -1.0
    private var projection: LifeProjection { LifeProjection(setup: setup) }
    var body: some View {
        ZStack {
            if phase < 5 {
                VStack(spacing: 14) {
                    Heading(title: "This is your life\nin weeks",centered: true)
                    GeometryReader { g in
                        WeekDots(projection: projection, reveal: reduceMotion ? Double(min(phase, 3)) : revealed)
                        let scrollingHeight = g.size.height * projection.scrollingFraction
                        let scrollingCenter = g.size.height * (projection.livedFraction + projection.asleepFraction + projection.scrollingFraction / 2)
                        Color.clear
                            .frame(width: g.size.width, height: scrollingHeight)
                            .anchorPreference(key: ScrollingWeeksOriginKey.self, value: .bounds) { $0 }
                            .position(x: g.size.width / 2, y: scrollingCenter)
                        if phase >= 1 { gridLabel("Already lived",color: .gray).position(x: g.size.width / 2,y: g.size.height * projection.livedFraction / 2) }
                        if phase >= 2 { gridLabel("Asleep",color: Color(hex: 0x6862AF)).position(x: g.size.width / 2,y: g.size.height * (projection.livedFraction + projection.asleepFraction / 2)) }
                        if phase >= 3 { gridLabel("Scrolling",color: Color(hex: 0xF33035)).position(x: g.size.width / 2,y: scrollingCenter) }
                    }
                    .frame(maxWidth: 282)
                    .frame(height: min(460, max(200, availableHeight - 168)))
                    .accessibilityHidden(true)
                    Text(["Every square is one week of your life.","Already lived","Spent asleep","Spent scrolling","Spent scrolling"][min(phase,4)])
                        .font(.subheadline.weight(phase == 0 ? .regular : .semibold))
                    Text("Illustration to age \(projection.horizon) · 8 hours of sleep a day")
                        .font(.caption2).foregroundStyle(Palette.muted)
                }
                .opacity(phase == 4 ? 0 : 1)
                .animation(reduceMotion ? nil : .easeIn(duration: 0.32), value: phase == 4)
                .transition(.opacity)
            } else {
                VStack(spacing: 12) {
                    Text("\(projection.wakingPercent.formatted(.number.precision(.fractionLength(0))))%")
                        .font(.system(size: 78,weight: .bold)).tracking(-3)
                    Text("of your future waking hours\nat this daily pace.")
                        .font(.body).multilineTextAlignment(.center)
                    Text("An illustration, not a prediction.")
                        .font(.caption).padding(.top, 20).opacity(0.8)
                }.foregroundStyle(.white).frame(maxWidth: .infinity,minHeight: 540)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }.frame(maxWidth: .infinity)
        .task(id: phase) {
            guard phase < 4 else {
                revealed = 3
                return
            }
            withAnimation(reduceMotion ? nil : .linear(duration: phase == 0 ? 0.95 : 0.70)) {
                revealed = Double(phase)
            }
            let tick = UIImpactFeedbackGenerator(style: .light)
            tick.prepare()
            for index in 0..<(reduceMotion ? 1 : 5) {
                do { try await Task.sleep(for: .milliseconds(67)) } catch { return }
                tick.impactOccurred(intensity: 0.35 + CGFloat(index) * 0.09)
                tick.prepare()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.life.\(phase)")
    }
    private func gridLabel(_ text: String,color: Color) -> some View { Text(text).font(.system(size: 11,weight: .semibold)).foregroundStyle(.white).padding(.horizontal,9).padding(.vertical,4).background(color,in: Capsule()) }
}

private struct WeekDots: View, Animatable {
    let projection: LifeProjection
    var reveal: Double
    var animatableData: Double {
        get { reveal }
        set { reveal = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let columns = 52
            let total = columns * projection.horizon
            let dx = size.width / Double(columns)
            let dy = size.height / Double(projection.horizon)
            let livedEnd = projection.livedFraction
            let sleepEnd = livedEnd + projection.asleepFraction
            let scrollingEnd = sleepEnd + projection.scrollingFraction
            let livedReveal = livedEnd * progress(through: 0)
            let sleepReveal = livedEnd + projection.asleepFraction * progress(through: 1)
            let scrollingReveal = sleepEnd + projection.scrollingFraction * progress(through: 2)
            let visible = Int(Double(total) * progress(through: -1))
            let neutral = Color(hex: 0xDADAD7)
            let lived = Color(hex: 0x9E9E99)
            let asleep = Color(hex: 0xB5B1E7)
            let scrolling = Color(hex: 0xF33035)
            var paths = [Path(), Path(), Path(), Path()]

            for index in 0..<visible {
                let fraction = Double(index) / Double(total)
                let category: Int
                switch fraction {
                case 0..<livedReveal: category = 1
                case livedEnd..<sleepReveal: category = 2
                case sleepEnd..<min(scrollingEnd, scrollingReveal): category = 3
                default: category = 0
                }
                let dot = CGRect(x: Double(index % columns) * dx + 0.5, y: Double(index / columns) * dy + 0.5,
                                 width: max(1, dx - 1), height: max(1, dy - 1))
                paths[category].addRoundedRect(in: dot, cornerSize: CGSize(width: 1.2, height: 1.2))
            }
            for (path, color) in zip(paths, [neutral, lived, asleep, scrolling]) {
                context.fill(path, with: .color(color))
            }
        }
    }

    private func progress(through start: Double) -> Double { min(1, max(0, reveal - start)) }
}

struct LifetimeEstimate: View {
    let setup: Setup
    @State private var shown = false
    @Environment(\.supermodReduceMotion) private var reduceMotion
    private var p: LifeProjection { LifeProjection(setup: setup) }
    var body: some View {
        VStack(spacing: 9) {
            Text("⏰").font(.system(size: 104)).saturation(0).shadow(color: .black.opacity(0.12),radius: 5,y: 8).padding(.bottom, 17)
            Text((shown ? p.minutes : 0).formatted(.number.precision(.fractionLength(0))))
                .font(.system(size: 43,weight: .bold)).minimumScaleFactor(0.6).lineLimit(1).monospacedDigit().contentTransition(.numericText())
            Text("minutes spent scrolling").font(.caption).foregroundStyle(Palette.muted)
            Text("or \(p.scrollingYears.formatted(.number.precision(.fractionLength(1)))) years")
                .font(.system(size: 29,weight: .semibold)).foregroundStyle(.white).padding(.horizontal,18).padding(.vertical,10)
                .background(Color(hex: 0xF33035),in: RoundedRectangle(cornerRadius: 10)).rotationEffect(.degrees(-3)).padding(.top, 10)
            Text("between age \(p.age) and \(p.horizon), at your current estimate.")
                .font(.caption).foregroundStyle(Palette.muted).multilineTextAlignment(.center).padding(.top, 12)
        }.frame(maxWidth: .infinity).padding(.vertical, 65)
            .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 1.3)) { shown = true } }
    }
}

struct AnimatedWarning: View {
    @State private var revealed = false
    @Environment(\.supermodReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading,spacing: 17) {
            Text("You’re not alone.\nBut those hours add up.").font(.system(size: 28,weight: .bold)).tracking(-0.7)
            Text("If you keep going at this pace, here’s what scrolling could add up to.")
                .font(.subheadline).foregroundStyle(Palette.muted).opacity(revealed ? 1 : 0).offset(y: revealed ? 0 : 8)
        }.frame(maxWidth: .infinity,alignment: .leading).padding(.top, 35)
            .task { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.6).delay(0.35)) { revealed = true } }
    }
}

struct TimePossibilities: View {
    let hours: Double
    @State private var index = 0
    @Environment(\.supermodReduceMotion) private var reduceMotion
    private let pictures = ["goal-focus","preview-mountains","goal-people","goal-movement"]
    private let captions = ["30-minute chapters, read","two-hour walks outside","unhurried hours with your people","one-hour workouts"]
    private let durations: [Double] = [0.5,2,1,1]
    var body: some View {
        VStack(spacing: 24) {
            Heading(title: "A little less scrolling.\nA little more life.", detail: "30 minutes less each day adds up to 182.5 hours a year.",centered: true)
            Image(pictures[index]).resizable().scaledToFill().frame(width: 270,height: 245).clipped()
                .mask { LinearGradient(stops: [.init(color: .clear,location: 0),.init(color: .black,location: 0.15),.init(color: .black,location: 0.75),.init(color: .clear,location: 1)],startPoint: .top,endPoint: .bottom) }
                .id(index).transition(.opacity)
            Text((hours / durations[index]).formatted(.number.precision(.fractionLength(0))))
                .font(.system(size: 52,weight: .bold)).contentTransition(.numericText())
            Text(captions[index]).font(.subheadline).multilineTextAlignment(.center)
            HStack(spacing: 6) { ForEach(0..<4) { i in Capsule().fill(i == index ? Palette.ink : Palette.line).frame(width: i == index ? 16 : 5,height: 5) } }
            Text("Illustrative uses of that time, not a promise of time saved.")
                .font(.caption2).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 20)
            .task {
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(2.7)) } catch { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) { index = (index + 1) % 4 }
                }
            }
    }
}

struct CommitOriginKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct CommitControl: View {
    let expanded: Bool
    @Binding var charge: Double
    let action: () -> Void
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scene
    @State private var pressing = false
    @State private var hintDown = false
    private let holdDuration = 1.7

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(expanded && !reduceMotion ? Color.white : Palette.ink)
                Circle().trim(from: 0, to: expanded ? 1 : charge)
                    .stroke(PaywallPalette.blush, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90)).padding(3)
                BrandMascot(size: 67)
            }
            .clipShape(Circle())
            .frame(width: 126, height: 126)
            .anchorPreference(key: CommitOriginKey.self, value: .bounds) { $0 }
            .overlay(alignment: .bottomTrailing) {
                if !pressing && !expanded {
                    Image(systemName: "hand.point.up.left.fill").font(.system(size: 37))
                        .foregroundStyle(PaywallPalette.outline)
                        .offset(x: hintDown ? 13 : 36, y: hintDown ? 16 : 45)
                        .scaleEffect(hintDown ? 0.85 : 1)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: holdDuration, maximumDistance: 24) {
                confirm()
            } onPressingChanged: { updatePress($0) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Hold to commit")
            .accessibilityHint("Activate to confirm your goal. No hold is needed with VoiceOver.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { confirm() }
            Text(expanded ? "Locked in" : pressing ? "Keep holding…" : "Hold to lock it in")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .blendMode(.difference)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity).frame(height: 205)
        .task {
            guard !reduceMotion else { return }
            for _ in 0..<3 {
                withAnimation(.easeInOut(duration: 0.7)) { hintDown = true }
                do { try await Task.sleep(for: .seconds(1.1)) } catch { return }
                withAnimation(.easeInOut(duration: 0.5)) { hintDown = false }
                do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
            }
        }
        .onChange(of: scene) { if scene != .active { updatePress(false) } }
        .onDisappear { updatePress(false) }
        .task(id: pressing) {
            guard pressing else { return }
            let tick = UIImpactFeedbackGenerator(style: .light)
            tick.prepare()
            for intensity in [0.38, 0.55, 0.72] {
                do { try await Task.sleep(for: .milliseconds(420)) } catch { return }
                tick.impactOccurred(intensity: intensity)
                tick.prepare()
            }
        }
    }

    private func updatePress(_ value: Bool) {
        guard !expanded else { return }
        if value && !pressing { Haptics.selection() }
        pressing = value
        withAnimation(reduceMotion ? nil : .linear(duration: value ? holdDuration : 0.22)) {
            charge = value ? 1 : 0
        }
    }

    private func confirm() {
        // Navigation owns deduplication. Do not latch an activation it may reject
        // while the incoming page is still settling (including VoiceOver).
        guard scene == .active else { return }
        action()
    }
}


struct ScrollingWeeksOriginKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct RedBlobFill: View {
    static let duration = 2.3
    let source: CGRect?
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @State private var progress = 0.0

    var body: some View {
        BubblingLiquid(source: source, progress: reduceMotion ? 1 : progress)
            .allowsHitTesting(false).accessibilityHidden(true)
            .task {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 2.08)) { progress = 1 }
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.prepare()
                for delay in [0.20, 0.32, 0.40] {
                    do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                    impact.impactOccurred(intensity: 0.67)
                    impact.prepare()
                }
            }
    }
}

// Animatable rendering is driven by SwiftUI's presentation clock. A TimelineView
// inside an anchor-preference background can retain a stale timeline date.
private struct BubblingLiquid: View, Animatable {
    let source: CGRect?
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    private let red = Color(hex: 0xF33035)
    var body: some View {
        Canvas { context, size in
            let t = min(1, max(0, progress)) * 2.08
            if progress >= 1 {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(red))
                return
            }
            let band = source ?? CGRect(x: size.width * 0.16, y: size.height * 0.57,
                                        width: size.width * 0.68, height: 12)
            let growth = progress * progress * (3 - 2 * progress)
            let centerY = min(size.height - 40, max(40, band.midY))
            let left = band.minX + (-95 - band.minX) * growth
            let right = band.maxX + (size.width + 95 - band.maxX) * growth
            let top = centerY - band.height / 2 - (centerY + 145) * growth
            let bottom = centerY + band.height / 2 + (size.height - centerY + 145) * growth
            let energy = sin(progress * .pi)
            // Blur and threshold join the rising lobes into one opaque liquid surface.
            // Its body expands from the scrolling band, including below the home indicator.
            context.addFilter(.alphaThreshold(min: 0.42, color: red))
            context.addFilter(.blur(radius: 9))
            context.drawLayer { liquid in
                let body = CGRect(x: left, y: top - 22 * energy,
                                  width: right - left, height: max(4, bottom - top + 44 * energy))
                liquid.fill(Path(roundedRect: body, cornerRadius: 24 + 48 * growth), with: .color(.white))
                for index in 0..<9 {
                    let position = (Double(index) + 0.5) / 9
                    let x = left + (right - left) * position
                    let phase = Double(index) * 1.91
                    let bounce = sin(t * 10.5 + phase) * energy
                    let radius = (18 + Double(index % 3) * 7) * min(1, t * 5) + 21 * growth
                    let lift = (18 + 24 * sin(position * .pi)) * energy
                    let y = top - lift + bounce * 16
                    liquid.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                                       width: radius * 2, height: radius * 2)), with: .color(.white))
                    let lowerY = bottom + lift * 0.6 - bounce * 12
                    liquid.fill(Path(ellipseIn: CGRect(x: x - radius, y: lowerY - radius,
                                                       width: radius * 2, height: radius * 2)), with: .color(.white))
                }
                // Three small bubbles leap just ahead of the crest and rejoin it.
                for index in 0..<3 {
                    let launch = max(0, min(1, (t - 0.18 - Double(index) * 0.16) / 0.65))
                    let arc = sin(launch * .pi)
                    let radius = (12 + Double(index) * 4) * arc
                    let x = band.midX + Double(index - 1) * size.width * 0.19
                    let y = top - arc * 70
                    liquid.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                                       width: radius * 2, height: radius * 2)), with: .color(.white))
                }
            }
        }
    }
}

struct TimeBackScene: View {
    @Environment(\.onboardingHeight) private var availableHeight
    let dailyHours: Double
    @Binding var minutes: Double?
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @State private var appeared = false
    private var maximum: Double { min(120, max(10, dailyHours * 60)) }
    private var selected: Double { min(maximum, max(5, minutes ?? 30)) }
    private var annualHours: Double { selected * 365 / 60 }
    private var diameter: Double { min(285, max(170, availableHeight - 320)) }

    var body: some View {
        VStack(spacing: 16) {
            Heading(title: "Get time back.", detail: "How much less could you scroll each day?", centered: true)
            ZStack {
                Circle().stroke(PaywallPalette.selection, lineWidth: 20)
                Circle().trim(from: 0, to: appeared ? selected / maximum : 0)
                    .stroke(PaywallPalette.plum, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(selected.formatted(.number.precision(.fractionLength(0))))
                        .font(.system(size: diameter * 0.29, weight: .bold)).tracking(-3)
                        .monospacedDigit().contentTransition(.numericText())
                    Text("minutes less a day").font(.subheadline)
                }
            }.frame(width: diameter, height: diameter).padding(.vertical, 15)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Scroll \(Int(selected)) minutes less each day")
            Slider(value: Binding(get: { selected }, set: { minutes = $0 }), in: 5...maximum, step: 5)
                .tint(.black).accessibilityLabel("Daily scrolling reduction")
            HStack { Text("5 min"); Spacer(); Text("\(Int(maximum)) min") }
                .font(.caption).foregroundStyle(Palette.muted)
            VStack(spacing: 4) {
                Text("You could get").font(.subheadline).foregroundStyle(Palette.muted)
                Text("\(annualHours.formatted(.number.precision(.fractionLength(0)))) hours a year")
                    .font(.system(size: 30, weight: .bold)).monospacedDigit().contentTransition(.numericText())
                    .minimumScaleFactor(0.7).lineLimit(1)
                Text("If you do it each day.").font(.caption).foregroundStyle(Palette.muted)
            }.padding(.top, 2)
        }.frame(maxWidth: .infinity)
            .animation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.85), value: selected)
            .sensoryFeedback(.selection, trigger: selected)
            .task {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.2)) { appeared = true }
            }
    }
}
