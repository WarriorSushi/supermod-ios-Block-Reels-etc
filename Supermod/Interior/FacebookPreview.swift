import SwiftUI
import WebKit

struct FacebookScreen: View {
    @Bindable var store: LocalStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scene
    let session: WebSession
    @State private var showsModifications = false

    private var locked: Bool { store.preferences.lock?.isActive(at: Date()) == true }

    private var hidden: Set<Mod> { store.preferences.facebookHidden ?? [] }

    var body: some View {
        SocialScreen(session: session, locked: locked, home: { dismiss() },
                     mods: { showsModifications = true }, messages: session.openFacebookMessages,
                     grayscale: store.preferences.grayscale == true, timerStore: store,
                     browserVisibility: { _ in })
            .preferredColorScheme(session.facebookChromeScheme)
            .onChange(of: hidden, initial: true) { session.update(hidden: store.preferences.filtered(hidden), locked: locked) }
            .onChange(of: scene) {
                if scene == .background { session.setSuspended(false) }
                if scene == .active { applyFilters() }
            }
            .onChange(of: store.preferences.lock) { applyFilters() }
            .task {
                session.update(hidden: store.preferences.filtered(hidden), locked: locked)
                session.open()
            }
            .task(id: store.preferences.shortVideoBreak?.endsAt) {
                guard let end = store.preferences.shortVideoBreak?.endsAt else { return }
                do { try await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow))) } catch { return }
                store.preferences.finishScrollTimer()
                session.update(hidden: store.preferences.filtered(hidden), locked: locked)
            }
            .onChange(of: store.preferences.shortVideoBreak) {
                session.update(hidden: store.preferences.filtered(hidden), locked: locked)
            }
            .onChange(of: session.status) {
                if case .blocked(let mod) = session.status, let timer = store.preferences.shortVideoBreak,
                   timer.features.contains(mod), timer.finishedAt != nil, !timer.isActive(at: Date()) { session.recover() }
            }
            .sheet(isPresented: $showsModifications) {
                NavigationStack {
                    FacebookModifications(store: store, session: session)
                }
            }
    }
    private func applyFilters() {
        session.update(hidden: store.preferences.filtered(hidden), locked: locked)
    }

}

private struct FacebookModifications: View {
    @Bindable var store: LocalStore
    let session: WebSession
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingClear = false
    @State private var clearing = false

    var body: some View {
        Form {
            Section { ScrollTimerCard(store: store) }
            Section("Facebook filters") {
                ForEach([Mod.sponsored, .reels, .stories]) { mod in
                    Toggle("Hide \(mod.title)", isOn: Binding {
                        store.preferences.facebookHidden?.contains(mod) == true
                    } set: { enabled in
                        Haptics.selection()
                        var hidden = store.preferences.facebookHidden ?? []
                        if enabled { hidden.insert(mod) } else { hidden.remove(mod) }
                        store.preferences.facebookHidden = hidden
                    })
                }
            }
            .disabled(store.preferences.lock?.isActive(at: Date()) == true)
            Button("Clear Facebook session", role: .destructive) { Haptics.selection(); confirmingClear = true }
                .disabled(clearing)
        }
        .navigationTitle("Facebook modifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { Haptics.selection(); dismiss() }
                    .disabled(clearing)
            }
        }
        .confirmationDialog("Clear Facebook session?", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Clear Facebook session", role: .destructive) { Haptics.selection();
                guard !clearing else { return }
                clearing = true
                Task {
                    await session.clear()
                    session.open()
                    clearing = false
                    dismiss()
                }
            }
        } message: {
            Text("This signs you out of Facebook in Supermod.")
        }
        .interactiveDismissDisabled(clearing)
    }
}
