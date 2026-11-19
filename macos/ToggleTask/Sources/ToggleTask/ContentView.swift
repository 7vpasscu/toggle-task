import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: TimerStore
    @State private var selection = "timer"
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Timer", systemImage: "stopwatch").tag("timer")
                Label("Actividad", systemImage: "list.bullet.rectangle").tag("activity")
                Section("Espacio personal") { Label("Proyectos", systemImage: "folder"); Label("Preferencias", systemImage: "gearshape") }
            }.navigationTitle("Toggle Task")
        } detail: { if selection == "activity" { ActivityView() } else { TimerView() } }
        .frame(minWidth: 900, minHeight: 600)
    }
}

struct TimerView: View {
    @EnvironmentObject var store: TimerStore
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("Hoy").font(.title2.weight(.semibold)); Spacer(); Text(store.syncState).font(.caption).foregroundStyle(.secondary); Button("Sincronizar") { Task { await store.sync() } }.buttonStyle(.bordered) }.padding(24)
            VStack(spacing: 18) {
                TextField("¿En qué estás trabajando?", text: $store.activityDescription).textFieldStyle(.plain).font(.title3).padding(.horizontal, 18).padding(.top, 18)
                HStack { Picker("Proyecto", selection: $store.selectedProjectID) { ForEach(store.projects) { project in Text(project.name).tag(project.id) } }.labelsHidden().frame(maxWidth: 390); Spacer(); Text(store.formattedElapsed).font(.system(size: 28, weight: .medium, design: .monospaced)); Button(store.isRunning ? "Parar" : "Iniciar") { store.toggleTimer() }.buttonStyle(.borderedProminent).tint(store.isRunning ? .red : .accentColor).keyboardShortcut(.return, modifiers: [.command]) }.padding(.horizontal, 18).padding(.bottom, 18)
            }.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14)).padding(24)
            HStack { Text("Sesiones recientes").font(.headline); Spacer(); Text("Esta semana").font(.caption).foregroundStyle(.secondary) }.padding(.horizontal, 24).padding(.bottom, 8)
            List(store.sessions) { session in HStack { Circle().fill(Color.accentColor).frame(width: 8, height: 8); VStack(alignment: .leading) { Text(session.description.isEmpty ? "Sin descripción" : session.description); Text(session.projectName).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(TimerStore.format(seconds: session.durationSeconds)).font(.system(.body, design: .monospaced)); Text(session.startedAt, style: .time).foregroundStyle(.secondary) } }.listStyle(.inset)
        }
    }
}

struct ActivityView: View { @EnvironmentObject var store: TimerStore; var body: some View { List { ForEach(store.sessions) { session in Text(session.projectName).badge(TimerStore.format(seconds: session.durationSeconds)) } }.navigationTitle("Actividad") } }
struct MenuBarView: View { @EnvironmentObject var store: TimerStore; var body: some View { VStack(alignment: .leading, spacing: 14) { Text(store.isRunning ? "Temporizador activo" : "Listo para registrar").font(.headline); Text(store.selectedProject?.name ?? "Sin proyecto").font(.subheadline).foregroundStyle(.secondary); Text(store.formattedElapsed).font(.system(size: 30, design: .monospaced)); Button(store.isRunning ? "Parar temporizador" : "Iniciar temporizador") { store.toggleTimer() }.buttonStyle(.borderedProminent) }.padding(20) } }
