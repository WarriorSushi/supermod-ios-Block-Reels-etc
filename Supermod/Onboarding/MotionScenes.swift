import SwiftUI

/// A switch first frames its target, then applies the change, then returns home.
/// Desired and displayed filters are separate so removal never precedes the camera.
struct GuidedPhoneDemo: View {
    let hidden: Set<Mod>
    @Binding var busy: Bool
    var height: CGFloat = 440
    var liftX: CGFloat = 0
    @Environment(\.onboardingHeight) private var availableHeight
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @State private var displayed: Set<Mod> = []
    @State private var focus: Mod?
    @State private var scroll: CGFloat = 0
    @State private var initialized = false
    @State private var removing: Mod?
    @State private var burst = 0.0

    var body: some View {
        PhoneDemo(hidden: displayed, panel: displayed.contains(.feed) ? .messages : .feed,
                  width: height / (864 / 410), showsAd: true, feedOffset: scroll, removing: removing, removalProgress: burst)
            .environment(\.demoPhoneWidth, 1000)
            .frame(maxWidth: .infinity).frame(height: height)
            .scaleEffect(focus == nil ? 1 : min(1.5, max(1.08, (availableHeight - 100) / height)))
            .offset(x: focus == nil ? 0 : liftX, y: focus == nil ? 0 : -8)
            .shadow(color: .black.opacity(focus == nil ? 0 : 0.22), radius: 24, y: 15)
            .zIndex(20)
            .accessibilityValue("\(busy ? "Showing change. " : "")\(displayed.contains(.feed) ? "Your chats stay visible" : "Posts from friends stay visible")")
            .task(id: hidden) {
                if !initialized {
                    initialized = true; displayed = hidden; return
                }
                guard let changed = Mod.allCases.first(where: { hidden.contains($0) != displayed.contains($0) }) else { return }
                busy = true
                defer { busy = false }
                if reduceMotion { displayed = hidden; return }
                do {
                    withAnimation(.easeInOut(duration: 0.65)) {
                        if changed == .sponsored { scroll = 510 }
                        else if changed == .suggestions { scroll = 1020 + (displayed.contains(.sponsored) ? 0 : 486) }
                        else { scroll = 0 }
                        focus = changed
                    }
                    try await Task.sleep(for: .milliseconds(850))
                    if hidden.contains(changed) {
                        removing = changed; burst = 0
                        try await Task.sleep(for: .milliseconds(300))
                    }
                    withAnimation(.easeOut(duration: 0.65)) { burst = 1; displayed = hidden }
                    try await Task.sleep(for: .milliseconds(800))
                    removing = nil
                    withAnimation(.easeInOut(duration: 0.75)) { focus = nil; scroll = 0 }
                    try await Task.sleep(for: .milliseconds(750))
                } catch { return }
            }
    }
}

struct SwitchTourScene: View {
    @Binding var hidden: Set<Mod>
    @Binding var busy: Bool
    @Environment(\.onboardingHeight) private var availableHeight
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 5) {
                Text("More than one switch.").font(.system(size: 25, weight: .light)).tracking(-0.8)
                Text("Keep your friends. Lose the noise.").font(.subheadline.weight(.light)).foregroundStyle(Palette.muted)
            }.multilineTextAlignment(.center)
            GuidedPhoneDemo(hidden: hidden, busy: $busy, height: min(530, max(275, availableHeight - 170)))
            Text("TURN OFF").font(.system(size: 10, weight: .bold)).tracking(1.4).foregroundStyle(Palette.muted)
            HStack(alignment: .top, spacing: 12) {
                ForEach([Mod.sponsored, .stories, .suggestions]) { mod in
                    VStack(spacing: 5) {
                        Text(mod == .sponsored ? "Ads" : mod == .suggestions ? "For you" : "Stories").font(.caption)
                        Toggle("Turn off \(mod.title.lowercased())", isOn: Binding(get: { hidden.contains(mod) }, set: {
                            Haptics.selection()
                            if $0 { hidden.insert(mod) } else { hidden.remove(mod) }
                        }))
                        .labelsHidden().tint(.black)
                        .accessibilityIdentifier("demo.visible.\(mod.rawValue)")
                    }.frame(maxWidth: .infinity)
                }
            }.disabled(busy).opacity(busy ? 0.25 : 1)
        }.frame(maxWidth: .infinity)
    }
}

struct BreakDemoScene: View {
    @Binding var minutes: Int?
    @Environment(\.onboardingHeight) private var height
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @State private var elapsed = false
    @State private var progress = 0.0
    private var choice: Int { minutes ?? 10 }
    var body: some View {
        VStack(spacing: 14) {
            Heading(title: "Pick a time.\nReels stop for you.", detail: "Enjoy a short scroll. We hide Reels and Shorts when time is up.", centered: true)
            Picker("Scroll timer length", selection: Binding(get: { choice }, set: { Haptics.selection(); minutes = $0 })) {
                ForEach([5, 10, 15, 30], id: \.self) { Text("\($0) min").tag($0) }
            }.pickerStyle(.segmented).accessibilityIdentifier("onboarding.break.duration")
            ZStack(alignment: .topTrailing) {
                let width = min(224.0, max(145, (height - 260) / (864.0 / 410)))
                ReelPhonePreview(removed: elapsed)
                    .frame(width: 410, height: 864)
                    .scaleEffect(width / 410)
                    .frame(width: width, height: width * 864 / 410)
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 8)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(elapsed ? "Break over. Reels hidden; friends feed visible." : "Reels available during your break.")
                Text(elapsed ? "Reels hidden" : "\(choice) min left")
                    .font(.headline.monospacedDigit()).padding(12)
                    .background(PaywallPalette.blush, in: Capsule()).offset(x: 30, y: 30)
            }.frame(maxWidth: .infinity)
            GeometryReader { g in
                Capsule().fill(Palette.line)
                Capsule().fill(PaywallPalette.plum).frame(width: g.size.width * progress)
            }.frame(height: 7)
            Text(elapsed ? "Your friends stay. The endless scroll stops." : "Choose how long you want to scroll.")
                .font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
            Text("Preview only · start your Scroll timer on Home").font(.caption2).foregroundStyle(Palette.muted)
        }
        .task(id: choice) {
            elapsed = false; progress = 0
            if reduceMotion { elapsed = true; progress = 1; return }
            do {
                try await Task.sleep(for: .milliseconds(450))
                withAnimation(.linear(duration: 3.2)) { progress = 1 }
                try await Task.sleep(for: .seconds(3.2))
                withAnimation(.easeInOut(duration: 0.7)) { elapsed = true }
            } catch { return }
        }
    }
}

struct HowItWorksScene: View {
    @Environment(\.onboardingHeight) private var availableHeight
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @State private var gathered = false
    @State private var touching = false
    @State private var opened = false
    var body: some View {
        VStack(spacing: 20) {
            Heading(title: "How it works.", centered: true)
            ZStack {
                RoundedRectangle(cornerRadius: 39).fill(.black).frame(width: 210, height: 440)
                RoundedRectangle(cornerRadius: 32).fill(PaywallPalette.canvas).frame(width: 196, height: 426)
                if opened {
                    VStack(spacing: 19) {
                        BrandMascot(size: 55)
                        Text("Supermod").font(.headline)
                        ForEach(SocialPlatform.allCases, id: \.self) { platform in
                            HStack(spacing: 10) {
                                platform.emblem
                                Text(platform.title).font(.system(size: 14, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                                Spacer(); Image(systemName: "chevron.right").font(.caption)
                            }.padding(.horizontal, 13)
                        }
                    }.frame(width: 180).transition(.scale(scale: 0.75).combined(with: .opacity))
                } else {
                    BrandMascot(size: 84).padding(8)
                        .background(PaywallPalette.blush, in: RoundedRectangle(cornerRadius: 25))
                        .scaleEffect(touching ? 0.88 : 1)
                }
                Capsule().fill(.black).frame(width: 70, height: 17).offset(y: -198)
                Capsule().fill(.black).frame(width: 75, height: 4).offset(y: 206)
                ForEach(Array(SocialPlatform.allCases.enumerated()), id: \.offset) { index, platform in
                    platform.emblem.scaleEffect(gathered ? 0.2 : 1.4)
                        .offset(x: gathered ? 0 : [Double(-135), 135, 120][index], y: gathered ? 0 : [-100.0, -65, 125][index])
                        .opacity(gathered ? 0 : 1)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).delay(Double(index) * 0.22), value: gathered)
                }
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 44)).foregroundStyle(PaywallPalette.plum)
                    .offset(x: touching ? 42 : 95, y: touching ? 42 : 120)
                    .opacity(gathered && !opened ? 1 : 0)
            }.frame(height: 450)
                .scaleEffect(min(1, max(0.65, (availableHeight - 225) / 450)))
                .frame(height: 450 * min(1, max(0.65, (availableHeight - 225) / 450)))
                .accessibilityHidden(true)
            Text("Use Instagram, Facebook and YouTube\ninside Supermod.")
                .font(.headline).multilineTextAlignment(.center)
                .opacity(opened ? 1 : 0.25)
            Text("Your other apps stay as they are.")
                .font(.caption).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity)
            .task {
                if reduceMotion { gathered = true; opened = true; return }
                do {
                    try await Task.sleep(for: .milliseconds(650)); gathered = true
                    try await Task.sleep(for: .seconds(1.5))
                    withAnimation(.easeInOut(duration: 0.55)) { touching = true }
                    try await Task.sleep(for: .milliseconds(600))
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) { opened = true }
                } catch { return }
            }
    }
}

struct CommitScene: View {
    let goals: String
    let expanded: Bool
    @Binding var charge: Double
    let action: () -> Void
    @Environment(\.onboardingHeight) private var height
    var body: some View {
        VStack(spacing: 15) {
            Spacer(minLength: 30)
            VStack(spacing: 12) {
                Text("Lock it in.").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                Text(goals).font(.body)
            }.foregroundStyle(.white).blendMode(.difference)
            Spacer(minLength: 60)
            CommitControl(expanded: expanded, charge: $charge, action: action)
                .padding(.bottom, 25)
        }.multilineTextAlignment(.center).frame(maxWidth: .infinity).frame(minHeight: max(360, height - 40))
    }
}
