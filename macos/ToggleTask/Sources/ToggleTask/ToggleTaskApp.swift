import SwiftUI

@main
struct ToggleTaskApp: App {
    @StateObject private var store = TimerStore()
    @State private var menuBar = MenuBarController()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store).task { menuBar.install(store: store) }
        }.commands {
            CommandGroup(after: .appInfo) {
                Button("Iniciar / parar temporizador") { store.toggleTimer() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
    }
}

