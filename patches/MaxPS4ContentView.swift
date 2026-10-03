import SwiftUI

/// MaxPS4's new top-level interface.
/// Kept as a drop-in replacement for the upstream ContentView so the emulator,
/// JIT/setup flow and existing Library/Console/Settings screens remain intact.
struct ContentView: View {
    @State private var setupVerified = false
    @State private var selectedTab: MaxPS4Tab = .library
    @Environment(EmulatorProcess.self) private var emulator

    private enum MaxPS4Tab: Hashable {
        case library, console, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                LibraryView()
                    .navigationTitle("MaxPS4")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Image(systemName: "gamecontroller.fill")
                                .foregroundStyle(.blue)
                                .accessibilityLabel("MaxPS4")
                        }
                    }
            }
            .tag(MaxPS4Tab.library)
            .tabItem { Label("Jeux", systemImage: "square.grid.2x2.fill") }

            NavigationStack {
                ConsoleView()
                    .navigationTitle("Console")
            }
            .tag(MaxPS4Tab.console)
            .tabItem { Label("Console", systemImage: "terminal.fill") }

            NavigationStack {
                SettingsView()
                    .navigationTitle("Réglages")
            }
            .tag(MaxPS4Tab.settings)
            .tabItem { Label("Réglages", systemImage: "gearshape.fill") }
        }
        .tint(.blue)
        .fullScreenCover(isPresented: Binding(get: { !setupVerified }, set: { _ in })) {
            SetupCheckView(onPassed: {
                setupVerified = true
                emulator.resumeIfRestartPending()
            })
        }
    }
}
