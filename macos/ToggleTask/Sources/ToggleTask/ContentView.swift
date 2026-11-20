import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var store: TimerStore
    @EnvironmentObject var activity: AppActivityMonitor
    @State private var tab = 0
    @State private var date = Date.now
    @State private var manualDuration = "00:30"
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
                    Toggle("Manual mode (⌘D)", isOn: $store.manualMode).toggleStyle(.switch).controlSize(.mini).font(.caption)
                    Spacer()
                    Button { settings.toggle() } label: { Image(systemName: "ellipsis") }.buttonStyle(.plain).accessibilityLabel("Settings and activity")
                }
                HStack(spacing: 12) {
                    TextField("What are you working on?", text: $store.activityDescription).textFieldStyle(.plain).disabled(store.isRunning && !store.manualMode)
                    if store.manualMode { TextField("Duration", text: $manualDuration).frame(width: 64).help("26 = 0:26 · 126 = 1:26") } else { Text(store.formattedElapsed).monospacedDigit().foregroundStyle(.secondary) }
                    Button(action: submit) { Image(systemName: store.manualMode ? "checkmark" : store.isRunning ? "stop.fill" : "play.fill").foregroundStyle(onAccent).frame(width: 48, height: 48).background(accent, in: RoundedRectangle(cornerRadius: store.isRunning ? 24 : 16)) }
                        .buttonStyle(.plain).accessibilityLabel(store.manualMode ? "Save manual entry" : store.isRunning ? "Stop" : "Start")
                }
                Picker("Project", selection: $store.selectedProjectID) { ForEach(store.projects) { Text($0.name).tag($0.id) } }.labelsHidden().disabled(store.isRunning && !store.manualMode)
                HStack(spacing: 4) {
                    ForEach(0..<2) { index in
                        Button { tab = index } label: { HStack { if tab == index { Image(systemName: "checkmark") }; Text(index == 0 ? "List" : "Calendar") }.frame(maxWidth: .infinity).frame(height: 40).background(tab == index ? accent.opacity(0.22) : Color.secondary.opacity(0.08), in: Capsule()) }.buttonStyle(.plain).accessibilityAddTraits(tab == index ? .isSelected : [])
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
        .alert("Could not save", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK") { store.error = nil } } message: { Text(store.error ?? "") }
    }
    private func submit() {
        if store.manualMode {
            guard let minutes = EntryDuration.minutes(manualDuration) else { store.error = "Enter a duration such as 26, 126 or 1:26."; return }
            let end = Date.now
            if let s = store.makeSession(start: end.addingTimeInterval(-Double(minutes * 60)), end: end, description: store.activityDescription, projectID: store.selectedProjectID) { store.save(s) }
        } else { store.toggleTimer() }
    }
    private var days: [Date] { Array(Set(store.sessions.map { Calendar.current.startOfDay(for: $0.startedAt) })).sorted(by: >) }
    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if store.sessions.isEmpty { Text("No sessions for this profile.").foregroundStyle(.secondary).padding(40) }
                ForEach(days, id: \.self) { day in
                    let records = store.sessions.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: day) }
                    VStack(spacing: 0) {
                        HStack { Text(Calendar.current.isDateInToday(day) ? "Today" : day.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "en_GB")))); Spacer(); Text(TimerStore.format(seconds: records.reduce(0) { $0 + $1.durationSeconds })).monospacedDigit() }.font(.subheadline.weight(.semibold)).padding(14)
                        ForEach(records) { session in
                            HStack(spacing: 10) {
                                Button { editing = session } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(session.description.isEmpty ? "+ Add description" : session.description).foregroundStyle(.primary)
                                        HStack(spacing: 5) { Circle().fill(.mint).frame(width: 7, height: 7); Text(session.projectName).foregroundStyle(.secondary).font(.caption) }
                                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                Text(TimerStore.format(seconds: session.durationSeconds)).font(.caption).monospacedDigit()
                                Button { store.resume(session) } label: { Image(systemName: "play.fill") }.buttonStyle(.plain).foregroundStyle(accent).disabled(store.isRunning).accessibilityLabel("Resume session")
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
                Button { date = Calendar.current.date(byAdding: .day, value: -1, to: date)! } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous day")
                DatePicker("Day", selection: $date, displayedComponents: .date).labelsHidden()
                Button { date = Calendar.current.date(byAdding: .day, value: 1, to: date)! } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next day")
                Button("Today") { date = .now }
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
            HStack { Text("App activity").font(.headline); Spacer(); Button("Close") { settings = false } }
            Toggle("Track foreground apps", isOn: Binding(get: { activity.enabled }, set: { activity.setEnabled($0) }))
            Text("App names and time intervals are stored on this device for 7 days. Tracking pauses after 2 idle minutes. Review a suggestion to log the time.").font(.caption).foregroundStyle(.secondary)
            Text("Suggestions for this profile").font(.headline)
            if activity.suggestions.isEmpty { Text("Turn on tracking and use another app for at least 15 seconds to see a suggestion.").foregroundStyle(.secondary) }
            ScrollView { ForEach(activity.suggestions) { item in
                HStack {
                    VStack(alignment: .leading) { Text(item.appName); Text(item.start, style: .time).font(.caption); Text(TimerStore.format(seconds: item.seconds)).monospacedDigit() }
                    Spacer()
                    Button("Review") {
                        let session = store.makeSession(start: item.start, end: item.end, description: item.appName, projectID: store.selectedProjectID, id: "activity-" + item.id, source: "activity")
                        settings = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { editing = session }
                    }
                    Button("Dismiss") { activity.dismiss(item.id) }
                }.padding(.vertical, 8)
            } }
            Button("Clear my activity history", role: .destructive) { activity.clear() }
            Text("Local profile · Notion disconnected").font(.caption2).foregroundStyle(.secondary)
        }.padding(24).frame(width: 460, height: 440)
    }
}

struct SessionEditor: View {
    @EnvironmentObject var store: TimerStore
    @Environment(\.dismiss) private var dismiss
    @State var session: TimeSession
    @State private var startDay = Date.now
    @State private var initialDuration = ""
    @State private var originalLength = 0.0
    @State private var duration = ""
    @State private var message = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DETAILS").font(.headline)
            TextField("Description", text: $session.description)
            Picker("Project", selection: $session.projectID) { ForEach(store.projects) { Text($0.name).tag($0.id) } }
            DatePicker("Start date", selection: $startDay, displayedComponents: .date)
            TextField("Duration", text: $duration).help("26 = 0:26 · 126 = 1:26")
            if !message.isEmpty { Text(message).foregroundStyle(.red).font(.caption) }
            Divider()
            HStack {
                Button("Delete", role: .destructive) { store.delete(session); dismiss() }
                Spacer(); Button("Cancel") { dismiss() }
                Button("Save") { guard prepareInterval() else { return }; session.projectName = store.projects.first { $0.id == session.projectID }?.name ?? session.projectName; if store.save(session) { dismiss() } else { message = store.error ?? "Could not save"; store.error = nil } }.buttonStyle(.borderedProminent)
            }
        }.padding(20).frame(width: 340)
        .onAppear {
            startDay = session.startedAt
            originalLength = (session.endedAt ?? .now).timeIntervalSince(session.startedAt)
            initialDuration = EntryDuration.format(seconds: max(60, Int(originalLength)))
            duration = initialDuration
        }
    }
    private func prepareInterval() -> Bool {
        guard let minutes = EntryDuration.minutes(duration) else {
            message = "Enter a duration such as 26, 126 or 1:26."
            return false
        }
        let length = duration == initialDuration ? originalLength : Double(minutes * 60)
        let original = session.startedAt
        if !Calendar.current.isDate(startDay, inSameDayAs: original) {
            let time = Calendar.current.dateComponents([.hour, .minute, .second], from: original)
            guard let moved = Calendar.current.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: startDay) else {return false}
            session.startedAt = moved
        }
        session.endedAt = session.startedAt.addingTimeInterval(length)
        return true
    }
}

struct MenuBarView: View {
    @EnvironmentObject var store: TimerStore
    var body: some View { VStack(alignment: .leading, spacing: 14) { Text("Task Track").font(.headline); Text(store.active?.description ?? "Ready to track"); Text(store.formattedElapsed).font(.system(size: 30, design: .monospaced)); Button(store.isRunning ? "Stop timer" : "Start timer") { store.toggleTimer() }.buttonStyle(.borderedProminent) }.padding(20) }
}
