import SwiftUI

@main
@MainActor
struct ToggleTaskApp: App {
    @StateObject private var store = TimerStore()
    @StateObject private var activity = AppActivityMonitor(workerID: "local-demo")
    @State private var menuBar = MenuBarController()
    var body: some Scene {
        WindowGroup("Task Track") {
            ContentView().environmentObject(store).environmentObject(activity).task { menuBar.install(store: store) }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in activity.flush() }
        }.defaultSize(width: 420, height: 760).commands {
            CommandGroup(after: .appInfo) {
                Button(store.manualMode ? "Modo temporizador" : "Modo manual") { store.manualMode.toggle() }
                    .keyboardShortcut("d", modifiers: .command)
                Button("Iniciar / parar temporizador") { store.toggleTimer() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
    }
}

