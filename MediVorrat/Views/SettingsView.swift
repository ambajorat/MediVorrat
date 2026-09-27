import SwiftUI

struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsAllowed: Bool?
    @State private var connecting = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $store.settings.patientName)
                        .textContentType(.name)
                    TextField("Geburtsdatum (TT.MM.JJJJ)", text: $store.settings.birthDate)
                } header: {
                    Text("Für die Rezeptanfrage")
                } footer: {
                    Text("Viele Praxen brauchen das Geburtsdatum, um dich zuzuordnen.")
                }

                Section("Praxis") {
                    TextField("Name der Praxis", text: $store.settings.practiceName)
                    TextField("E-Mail der Praxis", text: $store.settings.practiceEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("Um E-Rezept bitten", isOn: $store.settings.askForERezept)
                }

                Section {
                    Stepper("Vorlauf: \(store.settings.leadDays) Tage", value: $store.settings.leadDays, in: 3...42)
                    Stepper("„Bald“: \(store.settings.soonDays) Tage vorher", value: $store.settings.soonDays, in: 1...21)
                    Stepper("Erinnerung um \(store.settings.reminderHour) Uhr", value: $store.settings.reminderHour, in: 6...21)
                    if notificationsAllowed != true {
                        Button("Mitteilungen erlauben") {
                            Task { notificationsAllowed = await Notifications.requestPermission(); store.save() }
                        }
                    }
                } header: {
                    Text("Planung")
                } footer: {
                    Text("Der Vorlauf ist die Zeit, die Praxis und Apotheke zusammen brauchen. Am Anfordern-Tag kommt eine Erinnerung.")
                }

                Section {
                    if store.settings.healthConnected {
                        LabeledContent("Status") { Text("Verbunden") }
                        if let d = store.lastHealthSync {
                            LabeledContent("Letzter Abgleich") { Text(d.formatted(date: .omitted, time: .shortened)) }
                        }
                        Button("Jetzt abgleichen") { Task { await store.refresh() } }
                        Button("Freigegebene Medikamente ändern") { Task { await connect() } }
                    } else {
                        Button(connecting ? "Verbinde …" : "Mit Apple Health verbinden") { Task { await connect() } }
                            .disabled(connecting || !HealthSync.shared.isAvailable)
                    }
                    if let e = store.healthError {
                        Text(e).font(.footnote).foregroundStyle(.red)
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Die App liest nur. Sie sieht ausschließlich die Medikamente, die du im Health-Dialog freigibst.")
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .onChange(of: store.settings) { store.save() }
        }
    }

    private func connect() async {
        connecting = true
        defer { connecting = false }
        do {
            try await HealthSync.shared.requestAccess()
            store.settings.healthConnected = true
            await store.refresh()
        } catch {
            store.healthError = error.localizedDescription
        }
    }
}
