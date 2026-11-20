import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var store: TimerStore
    @EnvironmentObject var activity: AppActivityMonitor
    @State private var tab = 0
    @State private var date = Date.now
    @State private var manualStart = Date.now.addingTimeInterval(-1800)
    @State private var manualEnd = Date.now
    @State private var editing: TimeSession?
    @State private var settings = false
    @Environment(\.colorScheme) private var scheme
    private var surface: Color { scheme == .dark ? Color(red: 0.13, green: 0.12, blue: 0.15) : Color(red: 0.95, green: 0.93, blue: 0.97) }
    private var accent: Color { scheme == .dark ? Color(red: 0.82, green: 0.74, blue: 1) : Color(red: 0.40, green: 0.31, blue: 0.64) }
    private var onAccent: Color { scheme == .dark ? Color(red: 0.22, green: 0.12, blue: 0.45) : .white }
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Toggle("Modo manual (⌘D)", isOn: $store.manualMode).toggleStyle(.switch).controlSize(.mini).font(.caption)
                    Spacer()
                    Button { settings.toggle() } label: { Image(systemName: "ellipsis") }.buttonStyle(.plain).accessibilityLabel("Ajustes y actividad")
                }
                HStack(spacing: 12) {
                    TextField("¿En qué estás trabajando?", text: $store.activityDescription).textFieldStyle(.plain).disabled(store.isRunning && !store.manualMode)
                    Text(store.formattedElapsed).monospacedDigit().foregroundStyle(.secondary)
                    Button(action: submit) { Image(systemName: store.manualMode ? "checkmark" : store.isRunning ? "stop.fill" : "play.fill").foregroundStyle(onAccent).frame(width: 48, height: 48).background(accent, in: RoundedRectangle(cornerRadius: store.isRunning ? 24 : 16)) }
                        .buttonStyle(.plain).accessibilityLabel(store.manualMode ? "Guardar sesión manual" : store.isRunning ? "Parar" : "Iniciar")
                }
                Picker("Proyecto", selection: $store.selectedProjectID) { ForEach(store.projects) { Text($0.name).tag($0.id) } }.labelsHidden().disabled(store.isRunning && !store.manualMode)
                if store.manualMode { DatePicker("Inicio", selection: $manualStart); DatePicker("Fin", selection: $manualEnd) }
                HStack(spacing: 4) {
                    ForEach(0..<2) { index in
                        Button { tab = index } label: { HStack { if tab == index { Image(systemName: "checkmark") }; Text(index == 0 ? "Lista" : "Calendario") }.frame(maxWidth: .infinity).frame(height: 40).background(tab == index ? accent.opacity(0.22) : Color.secondary.opacity(0.08), in: Capsule()) }.buttonStyle(.plain).accessibilityAddTraits(tab == index ? .isSelected : [])
                    }
                }
            }.padding(20).background(surface)
            Divider()
            if tab == 0 { sessionList } else { calendar }
            Text(store.syncState).font(.caption2).foregroundStyle(.secondary).padding(8)
        }
        .frame(minWidth: 380, idealWidth: 420, minHeight: 580, idealHeight: 760)
        .background(scheme == .dark ? Color(red: 0.05, green: 0.03, blue: 0.06) : Color(nsColor: .windowBackgroundColor))
        .tint(accent)
        .popover(item: $editing) { SessionEditor(session: $0).environmentObject(store) }
        .sheet(isPresented: $settings) { activitySettings }
        .alert("No se pudo guardar", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("Aceptar") { store.error = nil } } message: { Text(store.error ?? "") }
    }
    private func submit() {
        if store.manualMode {
            if let s = store.makeSession(start: manualStart, end: manualEnd, description: store.activityDescription, projectID: store.selectedProjectID) { store.save(s) }
        } else { store.toggleTimer() }
    }
    private var days: [Date] { Array(Set(store.sessions.map { Calendar.current.startOfDay(for: $0.startedAt) })).sorted(by: >) }
    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if store.sessions.isEmpty { Text("No hay sesiones para este perfil.").foregroundStyle(.secondary).padding(40) }
                ForEach(days, id: \.self) { day in
                    let records = store.sessions.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: day) }
                    VStack(spacing: 0) {
                        HStack { Text(Calendar.current.isDateInToday(day) ? "Hoy" : day.formatted(date: .abbreviated, time: .omitted)); Spacer(); Text(TimerStore.format(seconds: records.reduce(0) { $0 + $1.durationSeconds })).monospacedDigit() }.font(.subheadline.weight(.semibold)).padding(14)
                        ForEach(records) { session in
                            HStack(spacing: 10) {
                                Button { editing = session } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(session.description.isEmpty ? "+ Añadir descripción" : session.description).foregroundStyle(.primary)
                                        HStack(spacing: 5) { Circle().fill(.mint).frame(width: 7, height: 7); Text(session.projectName).foregroundStyle(.secondary).font(.caption) }
                                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                Text(TimerStore.format(seconds: session.durationSeconds)).font(.caption).monospacedDigit()
                                Button { store.resume(session) } label: { Image(systemName: "play.fill") }.buttonStyle(.plain).foregroundStyle(accent).disabled(store.isRunning).accessibilityLabel("Continuar sesión")
                            }.padding(14)
                            Divider()
                        }
                    }.background(surface, in: RoundedRectangle(cornerRadius: 20))
                }
            }.padding(10)
        }
    }
    private var calendar: some View {
        let day = Calendar.current.dateInterval(of: .day, for: date)!
        let records = store.sessions.filter { SessionPolicy.overlap($0, day: day) > 0 }
        return VStack(spacing: 0) {
            HStack {
                Button { date = Calendar.current.date(byAdding: .day, value: -1, to: date)! } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Día anterior")
                DatePicker("Día", selection: $date, displayedComponents: .date).labelsHidden()
                Button { date = Calendar.current.date(byAdding: .day, value: 1, to: date)! } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Día siguiente")
                Button("Hoy") { date = .now }
                Spacer()
                Text(TimerStore.format(seconds: Int(records.reduce(0) { $0 + SessionPolicy.overlap($1, day: day) }))).font(.caption).monospacedDigit()
            }.controlSize(.small).padding(12)
            ScrollView {
                ZStack(alignment: .topLeading) {
                    ForEach(0..<Int(day.duration / 3600), id: \.self) { hour in
                        HStack(alignment: .top) { Text(day.start.addingTimeInterval(Double(hour) * 3600), style: .time).font(.caption2).foregroundStyle(.secondary).frame(width: 55); Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1) }.offset(y: CGFloat(hour * 60))
                    }
                    ForEach(records) { session in
                        Button { editing = session } label: { Text(session.description.isEmpty ? session.projectName : session.description).font(.caption).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(5).background(accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 4)) }
                            .buttonStyle(.plain).frame(height: max(12, SessionPolicy.overlap(session, day: day) / 60)).padding(.leading, 65).padding(.trailing, 10)
                            .offset(y: max(0, session.startedAt.timeIntervalSince(day.start) / 60))
                    }
                }.frame(height: day.duration / 60).frame(maxWidth: .infinity)
            }
        }
    }
    private var activitySettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Actividad de aplicaciones").font(.headline); Spacer(); Button("Cerrar") { settings = false } }
            Toggle("Registrar aplicaciones en primer plano", isOn: Binding(get: { activity.enabled }, set: { activity.setEnabled($0) }))
            Text("Solo nombres de apps e intervalos, guardados aquí durante 7 días. Se pausa tras 2 minutos de inactividad. Revisa cada sugerencia antes de registrarla.").font(.caption).foregroundStyle(.secondary)
            Text("Sugerencias · perfil local").font(.headline)
            if activity.suggestions.isEmpty { Text("Activa el seguimiento, utiliza otra app al menos 15 segundos y vuelve aquí.").foregroundStyle(.secondary) }
            ScrollView { ForEach(activity.suggestions) { item in
                HStack {
                    VStack(alignment: .leading) { Text(item.appName); Text(item.start, style: .time).font(.caption); Text(TimerStore.format(seconds: item.seconds)).monospacedDigit() }
                    Spacer()
                    Button("Revisar") {
                        let session = store.makeSession(start: item.start, end: item.end, description: item.appName, projectID: store.selectedProjectID, id: "activity-" + item.id, source: "activity")
                        settings = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { editing = session }
                    }
                    Button("Descartar") { activity.dismiss(item.id) }
                }.padding(.vertical, 8)
            } }
            Button("Borrar mi actividad local", role: .destructive) { activity.clear() }
            Text("Perfil local · autenticación de Notion pendiente.").font(.caption2).foregroundStyle(.secondary)
        }.padding(24).frame(width: 460, height: 440)
    }
}

struct SessionEditor: View {
    @EnvironmentObject var store: TimerStore
    @Environment(\.dismiss) private var dismiss
    @State var session: TimeSession
    @State private var duration = ""
    @State private var message = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DETALLES").font(.headline)
            TextField("Descripción", text: $session.description)
            Picker("Proyecto", selection: $session.projectID) { ForEach(store.projects) { Text($0.name).tag($0.id) } }
            TextField("Duración HH:MM:SS", text: $duration).onSubmit { applyDuration() }
            DatePicker("Inicio", selection: $session.startedAt)
            DatePicker("Fin", selection: Binding(get: { session.endedAt ?? .now }, set: { session.endedAt = $0 }))
            if !message.isEmpty { Text(message).foregroundStyle(.red).font(.caption) }
            Divider()
            HStack {
                Button("Eliminar", role: .destructive) { store.delete(session); dismiss() }
                Spacer(); Button("Cancelar") { dismiss() }
                Button("Guardar") { guard applyDuration() else { return }; session.projectName = store.projects.first { $0.id == session.projectID }?.name ?? session.projectName; if store.save(session) { dismiss() } else { message = store.error ?? "No se pudo guardar"; store.error = nil } }.buttonStyle(.borderedProminent)
            }
        }.padding(20).frame(width: 340)
        .onAppear { refreshDuration() }
        .onChange(of: session.startedAt) { _ in refreshDuration() }
        .onChange(of: session.endedAt) { _ in refreshDuration() }
    }
    private func refreshDuration() { duration = TimerStore.format(seconds: Int((session.endedAt ?? .now).timeIntervalSince(session.startedAt))) }
    @discardableResult private func applyDuration() -> Bool {
        let parts = duration.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 3, parts[0] >= 0, (0..<60).contains(parts[1]), (0..<60).contains(parts[2]), parts[0] < 100000 else { message = "Usa HH:MM:SS."; return false }
        session.endedAt = session.startedAt.addingTimeInterval(Double(parts[0] * 3600 + parts[1] * 60 + parts[2])); return true
    }
}

struct MenuBarView: View {
    @EnvironmentObject var store: TimerStore
    var body: some View { VStack(alignment: .leading, spacing: 14) { Text("Task Track").font(.headline); Text(store.active?.description ?? "Listo para registrar"); Text(store.formattedElapsed).font(.system(size: 30, design: .monospaced)); Button(store.isRunning ? "Parar temporizador" : "Iniciar temporizador") { store.toggleTimer() }.buttonStyle(.borderedProminent) }.padding(20) }
}
