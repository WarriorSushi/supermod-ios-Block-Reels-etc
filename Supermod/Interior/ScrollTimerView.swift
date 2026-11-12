import SwiftUI

/// Shared entry point on Home and in each app's controls.
struct ScrollTimerCard: View {
    let store: LocalStore
    @State private var showingTimer = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let timer = store.preferences.shortVideoBreak
            let active = timer?.isActive(at: context.date) == true
            Button { Haptics.selection(); showingTimer = true } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        if let timer, active {
                            CountdownRing(timer: timer, date: context.date).frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "timer").font(.title2).frame(width: 32)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(active ? "Scroll timer is running" : "Scroll timer").font(.headline)
                            if let timer, active {
                                Text("\(timer.featureNames) hide in \(countdown(timer, at: context.date))")
                                    .font(.subheadline).monospacedDigit()
                            } else {
                                Text(timer?.finishedAt != nil ? "Time’s up. Your selected features are hidden." : "Scroll for a little. Then it hides.")
                                    .font(.subheadline).foregroundStyle(Palette.muted)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }
                    if !active {
                        Text("Choose what to scroll and for how long.")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                        Text("Set scroll timer").font(.subheadline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 24))
                .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(Palette.line) }
                .contentShape(RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("timer.open")
        }
        .sheet(isPresented: $showingTimer) { ScrollTimerSheet(store: store) }
    }
}

struct ScrollTimerSheet: View {
    let store: LocalStore
    @Environment(\.dismiss) private var dismiss
    @State private var features: Set<Mod> = [.reels]
    @State private var minutes = 10

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let timer = store.preferences.shortVideoBreak
                let locked = store.preferences.lock?.isActive(at: context.date) == true
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if locked, let lock = store.preferences.lock {
                            InfoLine(icon: "lock.fill", title: "Your filters are locked", detail: "You can start a timer after \(lock.end.formatted(date: .omitted, time: .shortened)).")
                        } else {
                            if let timer, timer.isActive(at: context.date) {
                                HStack(spacing: 16) {
                                    CountdownRing(timer: timer, date: context.date).frame(width: 40, height: 40)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(countdown(timer, at: context.date)).font(.title.monospacedDigit().bold())
                                        Text("Time left · selected features hide at zero").font(.caption).foregroundStyle(Palette.muted)
                                    }
                                }
                                Text("You can add Stories or change your choices below. The timer keeps the same end time.")
                                    .font(.subheadline).foregroundStyle(Palette.muted)
                            } else {
                                Text("Choose a feature. Use it until the timer ends. Then Supermod hides it automatically.")
                                    .font(.subheadline).foregroundStyle(Palette.muted)
                            }
                            featurePicker
                            if let timer, timer.isActive(at: context.date) {
                                PrimaryButton(title: features == timer.features ? "Choices saved" : "Save choices", icon: "checkmark") {
                                    store.preferences.updateScrollTimerFeatures(features)
                                    Haptics.selection(); dismiss()
                                }
                                .disabled(features.isEmpty || features == timer.features)
                                .accessibilityIdentifier("timer.save")
                                Button("End now & hide") {
                                    Haptics.selection(); store.preferences.finishScrollTimer()
                                }.frame(maxWidth: .infinity, minHeight: 44)
                                    .accessibilityIdentifier("timer.end")
                            } else {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("2. How long?").font(.headline)
                                    HStack(spacing: 8) {
                                        ForEach([5, 10, 15, 30], id: \.self) { duration in
                                            Button("\(duration) min") { Haptics.selection(); minutes = duration }
                                                .font(.subheadline.weight(.semibold))
                                                .frame(maxWidth: .infinity, minHeight: 44)
                                                .background(minutes == duration ? Palette.selection : Palette.surface, in: Capsule())
                                                .overlay { Capsule().strokeBorder(minutes == duration ? Palette.ink : Palette.line) }
                                                .accessibilityAddTraits(minutes == duration ? .isSelected : [])
                                        }
                                    }
                                    Stepper(minutes == 1 ? "1 minute" : "\(minutes) minutes", value: $minutes, in: 1...60)
                                        .monospacedDigit().accessibilityIdentifier("timer.minutes")
                                }
                                PrimaryButton(title: "Start \(minutes)-minute timer", icon: "play.fill") {
                                    var draft = ShortVideoBreak(minutes: minutes)
                                    draft.selection = features
                                    store.preferences.startScrollTimer(draft)
                                    Haptics.selection(); dismiss()
                                }
                                .disabled(features.isEmpty)
                                .accessibilityIdentifier("timer.start")
                            }
                        }
                        Text("Only inside Supermod. The countdown continues when you leave the app. Your other filters stay on.")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }.padding(24)
                }.background(Palette.canvas)
            }
            .navigationTitle("Scroll timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .foregroundStyle(Palette.ink).tint(Palette.ink)
        .onAppear {
            let saved = store.preferences.shortVideoBreak
            features = saved?.features ?? [.reels]
            minutes = min(60, max(1, saved?.minutes ?? store.preferences.setup.breakMinutes ?? 10))
        }
    }

    private var featurePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("1. What do you want to scroll?").font(.headline).padding(.bottom, 8)
            ForEach(ShortVideoBreak.choices) { mod in
                Button {
                    Haptics.selection()
                    if features.contains(mod) { features.remove(mod) } else { features.insert(mod) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: mod.symbol).frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(mod == .reels ? "Reels & Shorts" : mod.title).font(.body.weight(.medium))
                            Text(availability(mod)).font(.caption).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Image(systemName: features.contains(mod) ? "checkmark.circle.fill" : "circle").font(.title3)
                    }.padding(.vertical, 10).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(features.contains(mod) ? .isSelected : [])
                .accessibilityIdentifier("timer.feature.\(mod.rawValue)")
            }
        }
    }

    private func availability(_ mod: Mod) -> String {
        switch mod {
        case .reels: "Instagram · Facebook · YouTube"
        case .stories: "Instagram · Facebook"
        default: "Instagram"
        }
    }
}

struct CountdownRing: View {
    let timer: ShortVideoBreak
    let date: Date
    var body: some View {
        ZStack {
            Circle().stroke(Palette.line, lineWidth: 3)
            Circle().trim(from: 0, to: timer.fractionRemaining(at: date))
                .stroke(Palette.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }.accessibilityHidden(true)
    }
}

/// A tiny draining ring around the existing floating controls avoids another overlay.
struct TimerMenuRing: View {
    let timer: ShortVideoBreak
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if timer.isActive(at: context.date) {
                CountdownRing(timer: timer, date: context.date).frame(width: 46, height: 46)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

private func countdown(_ timer: ShortVideoBreak, at date: Date) -> String {
    let seconds = Int(ceil(timer.remaining(at: date)))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
}

struct FilterLockButton: View {
    let store: LocalStore
    var onLock: () -> Void = {}
    @State private var showingLock = false
    var body: some View {
        Button { showingLock = true } label: {
            Label("Lock my filters", systemImage: "lock")
                .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityIdentifier("filters.lock")
        .sheet(isPresented: $showingLock) { FilterLockSheet(store: store, onLock: onLock) }
    }
}

private struct FilterLockSheet: View {
    let store: LocalStore
    let onLock: () -> Void
    @State private var minutes = 30
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if let lock = store.preferences.lock, lock.isActive(at: context.date) {
                            InfoLine(icon: "lock.fill", title: "Your filters are locked", detail: "You can change them again at \(lock.end.formatted(date: .omitted, time: .shortened)).")
                            Text("Keep using your apps with the same filters. You can start a new scroll timer when the lock ends.")
                        } else {
                            Text("Keep your current filters on. You won’t be able to change them or start a scroll timer until the lock ends.")
                            Text("If a scroll timer is running, locking ends it now and hides its selected features.")
                                .font(.subheadline).foregroundStyle(Palette.muted)
                            Picker("Lock duration", selection: $minutes) {
                                ForEach([15, 30, 60], id: \.self) { Text("\($0) min").tag($0) }
                            }.pickerStyle(.segmented)
                            PrimaryButton(title: "Lock filters for \(minutes) minutes", icon: "lock.fill") {
                                store.preferences.startFilterLock(minutes: minutes)
                                onLock(); Haptics.selection()
                            }.accessibilityIdentifier("filters.lock.start")
                        }
                        Text("Only inside Supermod. This doesn’t lock your phone or other apps. Clearing Supermod’s local data resets the lock.")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }.padding(24)
                }.background(Palette.canvas)
            }
            .navigationTitle("Lock my filters").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.foregroundStyle(Palette.ink).tint(Palette.ink)
    }
}
