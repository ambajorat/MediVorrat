import SwiftUI

struct ContentView: View {
    @Environment(Store.self) private var store
    @State private var path: [UUID] = []
    @State private var showPrescription = false
    @State private var showSettings = false
    @State private var showImport = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if store.medications.isEmpty {
                    emptyState
                } else {
                    Section {
                        SummaryHeader(items: store.items, settings: store.settings)
                    }
                    Section {
                        ForEach(store.items) { item in
                            NavigationLink(value: item.id) {
                                MedicationRow(item: item, leadDays: store.settings.leadDays)
                            }
                        }
                    } footer: {
                        Text("Der Balken zeigt die Reichweite bis 90 Tage, der Strich den spätesten Tag für die Rezeptanfrage (\(store.settings.leadDays) Tage Vorlauf).")
                    }
                }
            }
            .navigationTitle("Vorrat")
            .navigationDestination(for: UUID.self) { id in
                MedicationDetailView(id: id)
            }
            .refreshable { await store.refresh() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Label("Einstellungen", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showImport = true } label: {
                            Label("Aus Apple Health", systemImage: "heart.text.square")
                        }
                        Button { addManual() } label: {
                            Label("Manuell hinzufügen", systemImage: "square.and.pencil")
                        }
                    } label: {
                        Label("Hinzufügen", systemImage: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !store.medications.isEmpty {
                    Button { showPrescription = true } label: {
                        Label("Rezept anfragen", systemImage: "doc.text")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .sheet(isPresented: $showPrescription) { PrescriptionView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showImport) { HealthImportView() }
        }
    }

    private var emptyState: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                Text("Noch keine Medikamente")
                    .font(.title2.bold())
                Text("Übernimm deine Medikamente aus Apple Health. Dann zählt die App deine protokollierten Einnahmen automatisch vom Vorrat ab.")
                    .foregroundStyle(.secondary)
                Button { showImport = true } label: {
                    Label("Aus Apple Health übernehmen", systemImage: "heart.text.square")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                Button { addManual() } label: {
                    Text("Manuell hinzufügen")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 8)
        }
    }

    private func addManual() {
        let m = Medication(name: "Neues Medikament")
        store.add([m])
        path.append(m.id)
    }
}

struct SummaryHeader: View {
    let items: [MedItem]
    let settings: AppSettings

    var body: some View {
        let now = items.filter { $0.forecast.status == .orderNow }.count
        let soon = items.filter { $0.forecast.status == .soon }.count
        let missing = items.filter { $0.forecast.status == .missing }.count

        VStack(alignment: .leading, spacing: 4) {
            if missing == items.count {
                Text("Trag einmal deinen Bestand ein")
                    .font(.title3.bold())
                Text("Tippe ein Medikament an und zähle nach. Ab dann rechnet die App mit.")
                    .foregroundStyle(.secondary)
            } else if now > 0 {
                Text(now == 1 ? "1 Rezept jetzt anfordern" : "\(now) Rezepte jetzt anfordern")
                    .font(.title3.bold()).foregroundStyle(.red)
            } else if soon > 0 {
                Text(soon == 1 ? "1 Rezept in den nächsten \(settings.soonDays) Tagen" : "\(soon) Rezepte in den nächsten \(settings.soonDays) Tagen")
                    .font(.title3.bold()).foregroundStyle(.orange)
            } else {
                Text("Alles reicht noch")
                    .font(.title3.bold()).foregroundStyle(.green)
            }
            if missing > 0 && missing < items.count {
                Text(missing == 1 ? "Bei 1 Medikament fehlt noch der Bestand." : "Bei \(missing) Medikamenten fehlt noch der Bestand.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
