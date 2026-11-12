import SwiftUI
import WebKit

struct YouTubeScreen: View {
    @Bindable var store: LocalStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scene
    let session: WebSession
    @State private var showsModifications = false
    @State private var confirmingClear = false
    @State private var clearing = false

    private var locked: Bool { store.preferences.lock?.isActive(at: Date()) == true }

    private var showsShorts: Bool { store.preferences.youtubeShowsShorts == true }

    var body: some View {
        SocialScreen(session: session, locked: locked, home: { dismiss() },
                     mods: { showsModifications = true }, grayscale: store.preferences.grayscale == true, timerStore: store,
                     browserVisibility: { _ in })
            .onChange(of: showsShorts, initial: true) {
                session.update(hidden: store.preferences.filtered(showsShorts ? [] : [.reels]), locked: locked)
            }
            .onChange(of: scene) {
                if scene == .background { session.setSuspended(false) }
                if scene == .active { applyFilters() }
            }
            .onChange(of: store.preferences.lock) { applyFilters() }
            .task {
                session.update(hidden: store.preferences.filtered(showsShorts ? [] : [.reels]), locked: locked)
                session.open()
            }
            .task(id: store.preferences.shortVideoBreak?.endsAt) {
                guard let end = store.preferences.shortVideoBreak?.endsAt else { return }
                do { try await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow))) } catch { return }
                store.preferences.finishScrollTimer()
                session.update(hidden: store.preferences.filtered(showsShorts ? [] : [.reels]), locked: locked)
            }
            .onChange(of: store.preferences.shortVideoBreak) {
                session.update(hidden: store.preferences.filtered(showsShorts ? [] : [.reels]), locked: locked)
            }
            .onChange(of: session.status) {
                if case .blocked(let mod) = session.status, let timer = store.preferences.shortVideoBreak,
                   timer.features.contains(mod), timer.finishedAt != nil, !timer.isActive(at: Date()) { session.recover() }
            }
            .sheet(isPresented: $showsModifications) {
                NavigationStack {
                    Form {
                        Section { ScrollTimerCard(store: store) }
                        Section {
                            Toggle("Hide Shorts", isOn: Binding(
                                get: { !showsShorts },
                                set: { Haptics.selection(); store.preferences.youtubeShowsShorts = !$0 }
                            )).disabled(locked)
                        } footer: {
                            Text("Hides Shorts shelves and shortcuts. Regular videos and search remain available.")
                        }
                        Button("Clear YouTube session", role: .destructive) { Haptics.selection(); confirmingClear = true }
                            .disabled(clearing)
                    }
                    .navigationTitle("YouTube modifications")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { Haptics.selection(); showsModifications = false }
                                .disabled(clearing)
                        }
                    }
                    .confirmationDialog("Clear YouTube session?", isPresented: $confirmingClear, titleVisibility: .visible) {
                        Button("Clear YouTube session", role: .destructive) { Haptics.selection();
                            guard !clearing else { return }
                            clearing = true
                            Task {
                                await session.clear()
                                session.open()
                                clearing = false
                                showsModifications = false
                            }
                        }
                    } message: {
                        Text("This signs you out of YouTube in Supermod.")
                    }
                    .interactiveDismissDisabled(clearing)
                }
            }
    }
    private func applyFilters() {
        session.update(hidden: store.preferences.filtered(showsShorts ? [] : [.reels]), locked: locked)
    }

}
