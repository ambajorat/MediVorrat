import SwiftUI

struct PrescriptionView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<UUID> = []
    @State private var didPreselect = false
    @State private var showMail = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        let candidates = store.items.filter { $0.forecast.status != .paused }
        let text = store.prescriptionText(for: selected)

        NavigationStack {
            Form {
                if store.cardState != .off {
                    CardCheckSection()
                }

                Section {
                    ForEach(candidates) { item in
                        Toggle(isOn: binding(for: item.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.med.displayName)
                                StatusTag(status: item.forecast.status)
                            }
                        }
                    }
                } header: {
                    Text("Medikamente")
                } footer: {
                    Text("Vorausgewählt ist alles, was jetzt oder bald fällig ist.")
                }

                Section("Nachricht an die Praxis") {
                    Text(text)
                        .font(.callout)
                        .textSelection(.enabled)
                        .padding(.vertical, 4)
                        .foregroundStyle(.primary)
                }

                Section {
                    Button {
                        if MailComposer.canSend {
                            showMail = true
                        } else if let url = mailURL(text: text) {
                            openURL(url)
                        }
                    } label: {
                        Label("Als E-Mail an die Praxis", systemImage: "envelope")
                    }
                    .disabled(selected.isEmpty)
                    ShareLink(item: text, subject: Text(store.prescriptionSubject)) {
                        Label("Senden über …", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        store.markOrdered(selected)
                        dismiss()
                    } label: {
                        Label("Als angefragt markieren", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(LargeButtonStyle())
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .disabled(selected.isEmpty)
                } footer: {
                    Text("Wird die Mail aus der App gesendet, markiert MediVorrat die Medikamente automatisch als angefragt. Sie bleiben lila, bis die Packung eingebucht ist.")
                }
            }
            .navigationTitle("Rezept anfragen")
            .pageForm()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .tint(Color.accent)
            .sheet(isPresented: $showMail) {
                MailComposer(
                    recipients: store.settings.practiceEmail.isEmpty ? [] : [store.settings.practiceEmail],
                    subject: store.prescriptionSubject,
                    html: store.prescriptionHTML(for: selected)
                ) { result in
                    showMail = false
                    if result == .sent {
                        store.markOrdered(selected)
                        dismiss()
                    }
                }
                .ignoresSafeArea()
            }
            .onAppear {
                guard !didPreselect else { return }
                selected = Set(candidates.filter { $0.forecast.status.needsPrescription }.map(\.id))
                didPreselect = true
            }
        }
    }

    private func binding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { selected.contains(id) },
            set: { on in if on { selected.insert(id) } else { selected.remove(id) } }
        )
    }

    /// Ersatzweg ohne eingerichtetes Apple Mail (z. B. Gmail als Standard): nur Klartext möglich.
    private func mailURL(text: String) -> URL? {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#")
        func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s }
        let to = store.settings.practiceEmail.trimmingCharacters(in: .whitespaces)
        let body = text.replacingOccurrences(of: "\n", with: "\r\n")
        return URL(string: "mailto:\(enc(to))?subject=\(enc(store.prescriptionSubject))&body=\(enc(body))")
    }
}

// MARK: Gesundheitskarte

/// Stand der Gesundheitskarte im Quartal – in der Rezeptanfrage und in den Einstellungen.
struct CardCheckSection: View {
    @Environment(Store.self) private var store
    /// In den Einstellungen mit Schalter, in der Rezeptanfrage ohne
    var showsToggle = false

    var body: some View {
        @Bindable var store = store
        let state = store.cardState
        Section {
            if showsToggle {
                Toggle("Quartalsweise an die Karte erinnern", isOn: $store.settings.cardCheck)
            }
            if state != .off {
                statusRow(state)
                if let read = store.settings.cardReadDate {
                    DatePicker("Eingelesen am",
                               selection: Binding(get: { read }, set: { store.markCardRead($0) }),
                               in: ...Date.now,
                               displayedComponents: .date)
                }
                if !(store.settings.cardReadDate.map { Calendar.current.isDateInToday($0) } ?? false) {
                    Button {
                        store.markCardRead()
                    } label: {
                        Label("Heute in der Praxis eingelesen", systemImage: "creditcard")
                    }
                }
            }
        } header: {
            Text("Gesundheitskarte")
        } footer: {
            if showsToggle {
                Text("Bei Dauermedikation muss die Karte einmal pro Quartal in der Praxis eingelesen werden. MediVorrat prüft das bei der Rezeptanfrage und erwähnt es in den Erinnerungen. Privat versichert? Dann einfach ausschalten.")
            }
        }
    }

    @ViewBuilder
    private func statusRow(_ state: InsuranceCard.State) -> some View {
        switch state {
        case .unknown:
            row("exclamationmark.triangle.fill", .accent,
                "Noch kein Einlesen erfasst",
                "Bei Dauermedikation muss die Karte einmal pro Quartal in der Praxis eingelesen werden. Trag ein, wann das zuletzt war.")
        case .expired(let read):
            row("exclamationmark.triangle.fill", .statusRed,
                "Im \(InsuranceCard.quarterLabel(.now)) noch nicht eingelesen",
                "Zuletzt am \(read.germanDate). Bitte die Karte in der Praxis einlesen lassen – ohne Einlesen im neuen Quartal stellen viele Praxen kein Folgerezept aus.")
        case .endingSoon(let read, let until):
            row("clock.badge.exclamationmark.fill", .accent,
                "Eingelesen am \(read.germanDate), gilt bis \(until.germanDate)",
                "Das Quartal endet bald. Stellt die Praxis das Rezept erst danach aus, muss die Karte neu eingelesen werden.")
        case .valid(let read, let until):
            row("checkmark.seal.fill", .statusOk,
                "Eingelesen am \(read.germanDate)",
                "Gilt im \(InsuranceCard.quarterLabel(.now)) bis \(until.germanDate).", calm: true)
        case .off:
            EmptyView()
        }
    }

    private func row(_ icon: String, _ color: Color, _ title: String, _ text: String, calm: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.body)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(calm ? Color.primary : color)
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(Color.subtleText)
            }
        }
        .padding(.vertical, 2)
    }
}
