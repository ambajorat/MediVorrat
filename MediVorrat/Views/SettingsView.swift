import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var notificationStatus: UNAuthorizationStatus?
    @Environment(\.openURL) private var openURL
    @State private var connecting = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $store.settings.patientName)
                        .submitLabel(.done)
                        .textContentType(.name)
                    TextField("Geburtsdatum (TT.MM.JJJJ)", text: $store.settings.birthDate)
                        .submitLabel(.done)
                } header: {
                    Text("Für die Rezeptanfrage")
                } footer: {
                    Text("Viele Praxen brauchen das Geburtsdatum, um dich zuzuordnen.")
                }

                Section("Praxis") {
                    TextField("Name der Praxis", text: $store.settings.practiceName)
                        .submitLabel(.done)
                    TextField("E-Mail der Praxis", text: $store.settings.practiceEmail)
                        .submitLabel(.done)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("Um E-Rezept bitten", isOn: $store.settings.askForERezept)
                }

                Section {
                    Stepper("Vorlauf: \(store.settings.leadDays) Tage", value: $store.settings.leadDays, in: 3...42)
                    Stepper("„Bald“: \(store.settings.soonDays) Tage vorher", value: $store.settings.soonDays, in: 1...21)
                    Stepper("Erinnerung um \(store.settings.reminderHour) Uhr", value: $store.settings.reminderHour, in: 6...21)
                    switch notificationStatus {
                    case .notDetermined:
                        Button("Mitteilungen erlauben") {
                            Task {
                                _ = await Notifications.requestPermission()
                                notificationStatus = await Notifications.status()
                                store.save()
                            }
                        }
                    case .denied:
                        Button("Mitteilungen in den iOS-Einstellungen erlauben") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }
                        Text("Ohne Mitteilungen kann MediVorrat dich nicht erinnern, wenn die App geschlossen ist.")
                            .font(.footnote)
                            .foregroundStyle(Color.statusRed)
                    case nil:
                        EmptyView()
                    default:
                        LabeledContent("Mitteilungen") { Text("Erlaubt") }
                    }
                } header: {
                    Text("Planung")
                } footer: {
                    Text("Der Vorlauf ist die Zeit, die Praxis und Apotheke zusammen brauchen. Die Erinnerungen kommen auch, wenn du die App nicht öffnest: am Anfordern-Tag, danach alle 3 Tage, und 3 Tage bevor der Vorrat endet.")
                }

                if HealthSync.shared.isAvailable || store.settings.healthConnected {
                    Section {
                        Toggle("Apple Health nutzen", isOn: Binding(
                            get: { store.settings.healthConnected },
                            set: { on in Task { await setHealth(on) } }
                        ))
                        .disabled(connecting || (!HealthSync.shared.isAvailable && !store.settings.healthConnected))
                        if store.settings.healthConnected {
                            if let d = store.lastHealthSync {
                                LabeledContent("Letzter Abgleich") { Text(d.formatted(date: .omitted, time: .shortened)) }
                            }
                            Button("Jetzt abgleichen") { Task { await store.refresh() } }
                            Button("Freigegebene Medikamente ändern") { Task { await setHealth(true, force: true) } }
                        }
                        if let e = store.healthError {
                            Text(e).font(.footnote).foregroundStyle(Color.statusRed)
                        }
                    } header: {
                        Text("Apple Health")
                    } footer: {
                        Text(store.settings.healthConnected
                             ? "Abgezogen wird, was du in Health als „genommen“ protokollierst. Die App liest nur und sieht nur die Medikamente, die du freigibst."
                             : "Aus: Die App rechnet mit deinem Einnahmeplan (Stück pro Tag). Beim Umschalten wird der aktuelle Bestand übernommen.")
                    }
                }

                Section {
                    Toggle("Über iCloud synchronisieren", isOn: Binding(
                        get: { store.cloudSyncOn },
                        set: { store.setCloudSync($0) }
                    ))
                    .disabled(!CloudSync.shared.isAccountAvailable && !store.cloudSyncOn)
                    if !CloudSync.shared.isAccountAvailable {
                        Text("Auf diesem Gerät ist kein iCloud-Konto angemeldet.")
                            .font(.footnote)
                            .foregroundStyle(Color.statusRed)
                    }
                    if store.cloudSyncOn, let d = store.lastCloudSync {
                        LabeledContent("Zuletzt abgeglichen") {
                            Text(d.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                } header: {
                    Text("iCloud")
                } footer: {
                    Text("Bestand, Medikamente, bekannte Packungen und Einstellungen gleichen sich zwischen deinen Geräten mit derselben Apple-ID ab. Es gilt der zuletzt geänderte Stand. Daten aus Apple Health werden nicht in iCloud gespeichert; Health bleibt pro Gerät eingestellt.")
                }

                infoSection
            }
            .navigationTitle("Einstellungen")
            .pageForm()
            .tint(Color.accent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .onChange(of: store.settings) { store.save() }
            .task { notificationStatus = await Notifications.status() }
        }
    }

    // MARK: Info

    private var infoSection: some View {
        Group {
            Section {
                LabeledContent("Version") { Text(AppInfo.version) }

                if let review = AppInfo.reviewURL {
                    Link(destination: review) {
                        linkRow("App bewerten", systemImage: "star.fill")
                    }
                }
                if let store = AppInfo.storeURL {
                    ShareLink(item: store,
                              message: Text("MediVorrat – Medikamentenvorrat im Blick, Rezepte rechtzeitig anfordern")) {
                        linkRow("App empfehlen", systemImage: "square.and.arrow.up")
                    }
                }
                Link(destination: AppInfo.privacyURL) {
                    linkRow("Datenschutzerklärung", systemImage: "hand.raised")
                }
                Link(destination: AppInfo.blogURL) {
                    linkRow("ploetzlich-querschnitt.de", systemImage: "globe", subtitle: "Mein Blog")
                }
            } header: {
                Text("Info")
            }

            Section {
                Link(destination: AppInfo.bdmStoreURL) {
                    linkRow("Blase & Darm Manager", systemImage: "drop.fill",
                            subtitle: "Blasen- und Darmmanagement, Katheter, Erinnerungen")
                }
                Link(destination: AppInfo.bdmWebURL) {
                    linkRow("blaseunddarm.de", systemImage: "globe")
                }
            } header: {
                Text("Auch von mir")
            } footer: {
                Text("Deine Daten liegen auf deinem Gerät und, wenn eingeschaltet, in deinem iCloud. Sie werden nicht an Dritte weitergegeben.\n© André M. Bajorat")
                    .font(.caption)
            }
        }
    }

    private func linkRow(_ title: String, systemImage: String, subtitle: String? = nil) -> some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(Color.subtleText)
                    }
                }
            } icon: {
                Image(systemName: systemImage).foregroundStyle(Color.accent)
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func setHealth(_ on: Bool, force: Bool = false) async {
        guard on else {
            store.setHealthEnabled(false)
            return
        }
        connecting = true
        defer { connecting = false }
        do {
            try await HealthSync.shared.requestAccess()
            if !store.settings.healthConnected || force {
                store.setHealthEnabled(true)
            }
            store.healthError = nil
            await store.refresh()
        } catch {
            store.healthError = error.localizedDescription
        }
    }
}
