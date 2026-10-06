import SwiftUI

struct ContentView: View {
    @Environment(Store.self) private var store
    @State private var path: [UUID] = []
    @State private var showPrescription = false
    @State private var showSettings = false
    @State private var showImport = false
    @State private var showScan = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerArea
                    if store.medications.isEmpty {
                        emptyState
                    } else {
                        SummaryCard(items: store.items, settings: store.settings)
                        overdueBanner
                        Text("Medikamente")
                            .font(.subheadline.weight(.bold))
                            .padding(.top, 4)
                        ForEach(store.items) { item in
                            NavigationLink(value: item.id) {
                                MedicationRow(item: item, leadDays: store.settings.leadDays, healthOn: store.settings.healthConnected)
                            }
                            .buttonStyle(.plain)
                        }
                        Text("Der Balken zeigt die Reichweite bis 90 Tage, der Strich den spätesten Tag für die Rezeptanfrage (\(store.settings.leadDays) Tage Vorlauf).")
                            .font(.caption)
                            .foregroundStyle(Color.subtleText)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.pageBg)
            .navigationBarTitleDisplayMode(.inline)
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
                    if !store.medications.isEmpty {
                        Button { showScan = true } label: {
                            Label("Packung scannen", systemImage: "barcode.viewfinder")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if store.settings.healthConnected {
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
                    } else {
                        Button { addManual() } label: {
                            Label("Hinzufügen", systemImage: "plus")
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !store.medications.isEmpty {
                    Button { showPrescription = true } label: {
                        Label("Rezept anfragen", systemImage: "doc.text")
                    }
                    .buttonStyle(LargeButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
            .sheet(isPresented: $showPrescription) { PrescriptionView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showImport) { HealthImportView() }
            .sheet(isPresented: $showScan) { PackScanView() }
        }
        .tint(Color.accent)
        .modifier(ReviewRequester())
        .task(id: store.medications.isEmpty) {
            guard !store.medications.isEmpty, !store.isDemo else { return }
            if await Notifications.requestIfNeeded() { store.save() }
        }
    }

    private var headerArea: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("MediVorrat")
                .font(.system(size: 22, weight: .bold, design: .serif))
            Text("Vorrat im Blick, Rezepte rechtzeitig")
                .font(.caption)
                .foregroundStyle(Color.subtleText)
        }
    }

    @ViewBuilder
    private var overdueBanner: some View {
        let due = store.items.filter { $0.forecast.status == .orderNow }
        if !due.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Group {
                        if due.count == 1 {
                            Text("\(due[0].med.name): Rezept jetzt anfordern")
                        } else {
                            Text("\(due.count) Rezepte jetzt anfordern")
                        }
                    }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accent)
                    if store.cardState.needsReading {
                        Text("Gesundheitskarte in diesem Quartal noch nicht eingelesen")
                            .font(.footnote)
                            .foregroundStyle(Color.subtleText)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.accent.opacity(0.12), in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accent.opacity(0.3)))
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "pills.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.accent)
            Text("Noch keine Medikamente")
                .font(.system(size: 20, weight: .bold, design: .serif))
            if HealthSync.shared.isAvailable {
                Text("Mit Apple Health zieht die App ab, was du dort als „genommen“ protokollierst. Ohne Health rechnet sie mit deinem Einnahmeplan. Du kannst das später in den Einstellungen umschalten.")
                    .font(.subheadline)
                    .foregroundStyle(Color.subtleText)
                Button { showImport = true } label: {
                    Label("Mit Apple Health starten", systemImage: "heart.text.square")
                }
                .buttonStyle(LargeButtonStyle())
                Button { addManual() } label: {
                    Text("Ohne Health, manuell anlegen")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.pillBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                Text("Leg deine Medikamente mit Einnahmeplan und Bestand an, oder scanne eine Packung. Die App zieht jeden Tag die geplante Menge ab und sagt dir, wann du ein Rezept anfordern solltest.")
                    .font(.subheadline)
                    .foregroundStyle(Color.subtleText)
                Button { addManual() } label: {
                    Label("Medikament anlegen", systemImage: "plus")
                }
                .buttonStyle(LargeButtonStyle())
                Button { showScan = true } label: {
                    Label("Packung scannen", systemImage: "barcode.viewfinder")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.pillBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .card(padding: 18)
    }

    private func addManual() {
        let m = Medication(name: String(localized: "Neues Medikament"))
        store.add([m])
        path.append(m.id)
    }
}

/// Übersicht im Stil der BDM-„Heute“-Karte
struct SummaryCard: View {
    let items: [MedItem]
    let settings: AppSettings

    var body: some View {
        let now = items.filter { $0.forecast.status == .orderNow }.count
        let soon = items.filter { $0.forecast.status == .soon }.count
        let ordered = items.filter { $0.forecast.status == .ordered }.count
        let ok = items.filter { $0.forecast.status == .ok }.count
        let missing = items.filter { $0.forecast.status == .missing }.count

        VStack(alignment: .leading, spacing: 8) {
            Text("Übersicht")
                .font(.subheadline.weight(.bold))
            HStack(spacing: 0) {
                summaryItem(value: now, label: "jetzt fällig", color: .statusRed)
                divider
                summaryItem(value: soon, label: "bald fällig", color: .accent)
                divider
                summaryItem(value: ordered, label: "angefragt", color: .statusOrdered)
                divider
                summaryItem(value: ok, label: "reicht", color: .statusOk)
            }
            .padding(.vertical, 12)
            .background(Color.cardBg, in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.pillBorder, lineWidth: 0.5))
            if missing > 0 {
                Group {
                    if missing == 1 {
                        Text("Bei 1 Medikament fehlt noch der Bestand.")
                    } else {
                        Text("Bei \(missing) Medikamenten fehlt noch der Bestand.")
                    }
                }
                    .font(.caption)
                    .foregroundStyle(Color.subtleText)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle().fill(Color.pillBorder).frame(width: 0.5, height: 30)
    }

    private func summaryItem(value: Int, label: LocalizedStringKey, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.weight(.bold))
                .foregroundStyle(value > 0 ? color : Color.subtleText)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.subtleText)
        }
        .frame(maxWidth: .infinity)
    }
}
