import SwiftUI

struct ModsEditor: View {
    @Binding var mods: ModSettings
    var locked = false
    @Environment(\.supermodReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("Preset").font(.headline)
                Spacer()
                Menu {
                    ForEach(Preset.allCases) { preset in
                        Button { Haptics.selection();
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { mods.select(preset) }
                        } label: {
                            if mods.preset == preset { Label(preset.rawValue, systemImage: "checkmark") }
                            else { Text(preset.rawValue) }
                        }
                    }
                } label: {
                    Label(mods.preset.rawValue, systemImage: "chevron.up.chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 13)
                        .frame(minHeight: 44)
                        .background(Palette.surface, in: Capsule())
                }
                .accessibilityLabel("Modifications preset")
                .accessibilityValue(mods.preset.rawValue)
            }
            Text(mods.preset.detail).font(.subheadline).foregroundStyle(Palette.muted)
            VStack(spacing: 0) {
                ForEach(Mod.allCases) { mod in
                    ModToggleRow(mod: mod, isHidden: Binding {
                        mods.hidden.contains(mod)
                    } set: { value in
                        if value != mods.hidden.contains(mod) { mods.toggle(mod) }
                    })
                    if mod != Mod.allCases.last { Divider().padding(.leading, 52) }
                }
            }
            .padding(.horizontal, 13)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
        }
        .disabled(locked)
    }
}

struct ModToggleRow: View {
    let mod: Mod
    @Binding var isHidden: Bool

    var body: some View {
        Toggle(isOn: $isHidden) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: mod.symbol)
                    .font(.subheadline)
                    .frame(width: 26, height: 25)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hide \(mod.title)").font(.subheadline.weight(.semibold))
                    Text(mod.detail).font(.caption).foregroundStyle(Palette.muted)
                }
            }
            .padding(.vertical, 9)
        }
        .frame(minHeight: 52)
        .tint(PaywallPalette.button)
        .sensoryFeedback(.selection, trigger: isHidden)
    }
}

struct OnboardingModsPreview: View {
    @Binding var mods: ModSettings
    @Binding var animating: Bool
    var locked: Bool
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.onboardingHeight) private var availableHeight
    @Environment(\.supermodReduceMotion) private var reduceMotion
    var body: some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 20)) : AnyLayout(HStackLayout(spacing: 16))
        layout {
            GuidedPhoneDemo(hidden: mods.hidden, busy: $animating, height: min(430, max(305, availableHeight - 150)), liftX: textSize.isAccessibilitySize ? 0 : 60)
                .frame(width: min(204, max(145, (availableHeight - 150) / (864.0 / 410))))
                .zIndex(20)
            VStack(alignment: .leading, spacing: 5) {
                Text("TURN OFF").font(.system(size: 10, weight: .bold)).tracking(1.4).foregroundStyle(Palette.muted)
                ForEach(Mod.onboardingCases) { mod in
                    Toggle(isOn: Binding(get: { mods.hidden.contains(mod) }, set: { value in
                        if value != mods.hidden.contains(mod) { mods.toggle(mod) }
                    })) {
                        Text(mod == .sponsored ? "Ads" : mod == .feed ? "Feed" : mod == .suggestions ? "For you" : mod.title)
                            .font(.subheadline.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityLabel("Hide \(mod.title)")
                    .frame(minHeight: 49).tint(PaywallPalette.button)
                    .sensoryFeedback(.selection, trigger: mods.hidden.contains(mod))
                }
            }.opacity(animating ? 0.2 : 1)
        }.zIndex(10).disabled(locked || animating)
    }
}
