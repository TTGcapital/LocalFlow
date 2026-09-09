import SwiftUI
import ServiceManagement

struct LocalSettingsView: View {
    @EnvironmentObject var s: Store
    var section = "System"
    @State var devices = AudioHardware.inputs
    @State var input = AudioHardware.defaultInput
    @State var login = SMAppService.mainApp.status == .enabled
    func preference(_ key: WritableKeyPath<Preferences, Bool?>, default value: Bool) -> Binding<Bool> {
        Binding(get: { s.preferences[keyPath: key] ?? value }, set: { s.preferences[keyPath: key] = $0; s.save(); s.applySystemPreferences() })
    }
    var body: some View {
        if section == "General" || section == "System" {
        GroupBox(section == "General" ? "Microphone" : "App settings") {
            VStack(alignment: .leading, spacing: 14) {
                if section == "General" {
                HStack {
                    Picker("Microphone (Mac input)", selection: $input) { ForEach(devices) { Text($0.name).tag($0.id) } }.onChange(of: input) {
                        if input != AudioHardware.defaultInput && !AudioHardware.setInput(input) { s.error = "Could not select this microphone."; input = AudioHardware.defaultInput }
                    }.disabled(s.recording)
                    Button("Refresh") { devices = AudioHardware.inputs; input = AudioHardware.defaultInput }
                }
                Text("Uses your Mac’s selected input device. Changing it here also changes the Mac input setting.").font(.caption).foregroundStyle(.secondary)
                } else {
                Toggle("Mute Mac sound while dictating", isOn: preference(\.muteWhileDictating, default: true))
                Text("Only the microphone records during dictation. Your previous output mute/volume is restored when recording ends. Notetaker keeps call audio audible.").font(.caption).foregroundStyle(.secondary)
                Toggle("Launch at login", isOn: $login).onChange(of: login) {
                    Task {
                        do { if login { try SMAppService.mainApp.register() } else { try await SMAppService.mainApp.unregister() } }
                        catch { s.error = error.localizedDescription; login = SMAppService.mainApp.status == .enabled }
                    }
                }
                Picker("Floating widget", selection: Binding(get: { s.preferences.showWidgetAlways == false ? "recording" : s.preferences.autoHideWidget == false ? "always" : "subtle" }, set: { value in s.preferences.showWidgetAlways = value != "recording"; s.preferences.autoHideWidget = value == "subtle"; s.save(); s.applySystemPreferences() })) {
                    Text("Subtle edge handle · expand on hover").tag("subtle")
                    Text("Always visible").tag("always")
                    Text("Only while recording or processing").tag("recording")
                }
                Toggle("Show app in Dock", isOn: preference(\.showDock, default: true))
                Toggle("Play completion sounds", isOn: preference(\.sounds, default: false))
                Picker("Scratchpad opens", selection: Binding(get: { s.preferences.scratchpadBehavior ?? "Resume last note" }, set: { s.preferences.scratchpadBehavior = $0; s.save() })) { Text("Resume last note").tag("Resume last note"); Text("New note (save previous)").tag("New note") }
                }
            }.padding(12)
        }
        }
        if section == "Notetaker" {
        GroupBox("Notetaker behavior") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Open notepad when recording a note", isOn: preference(\.openNotepad, default: true))
                Picker("Maximum recording length", selection: Binding(get: { s.preferences.maxNoteMinutes ?? 120 }, set: { s.preferences.maxNoteMinutes = $0; s.save() })) {
                    ForEach([30, 60, 120, 180, 240], id: \.self) { Text("\($0) minutes").tag($0) }
                }
                Text("Option M starts or stops a note. Recording stops automatically at the selected limit.").font(.caption).foregroundStyle(.secondary)
                Button("Import saved notes (.txt / .md)") { s.importTextNotes() }
            }.padding(12)
        }
        }
    }
}
extension Store {
    func applySystemPreferences() {
        NSApp.setActivationPolicy(preferences.showDock == false ? .accessory : .regular)
        floating?.updateVisibility()
    }
    func importTextNotes() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.plainText]; panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        var failures: [String] = []
        for url in panel.urls {
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                entries.insert(Entry(title: url.deletingPathExtension().lastPathComponent, kind: "Notetaker", transcript: text), at: 0)
            } catch { failures.append(url.lastPathComponent) }
        }
        save(); showPage("Notetaker")
        if !failures.isEmpty { error = "Could not read: " + failures.joined(separator: ", ") }
    }
}
