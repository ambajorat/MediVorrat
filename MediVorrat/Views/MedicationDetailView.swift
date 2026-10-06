import SwiftUI

struct MedicationDetailView: View {
    @Environment(Store.self) private var store
    let id: UUID

    var body: some View {
        if let m = store.medications.first(where: { $0.id == id }) {
            MedicationForm(med: m)
        } else {
            ContentUnavailableView("Entfernt", systemImage: "trash")
        }
    }
}

private struct MedicationForm: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Medication
    @State private var countText = ""
    @State private var packText: String
    @State private var healthMeds: [HealthMedication] = []
    @State private var confirmDelete = false
    @State private var showScan = false
    private enum Field { case count, name, strength, packSize }
    @FocusState private var focused: Field?

    init(med: Medication) {
        _draft = State(initialValue: med)
        _packText = State(initialValue: med.packSize.map(String.init) ?? "")
    }

    /// Eingabe als Text, damit „Übernehmen“ sofort reagiert (value:-Felder übernehmen erst beim Verlassen)
    private var countValue: Double? {
        Double(countText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }

    private var stored: Medication? { store.medications.first { $0.id == draft.id } }

    var body: some View {
        let f = store.forecast(draft)
        Form {
            Section {
                if let c = f.current, let days = f.daysLeft, let until = f.until {
                    LabeledContent("Aktuell") { Text("\(Int(c.rounded(.down))) Stück").monospacedDigit() }
                    LabeledContent("Reicht") { Text("\(days) Tage, bis \(until.shortDay)") }
                    if let o = f.orderBy {
                        LabeledContent("Rezept anfordern bis") { Text(o.shortDay) }
                    }
                    HStack { Text("Status"); Spacer(); StatusTag(status: f.status) }
                }
                HStack {
                    TextField("Jetzt gezählt", text: $countText)
                        .keyboardType(.decimalPad)
                        .focused($focused, equals: .count)
                    Button("Übernehmen") { applyCount() }
                        .buttonStyle(.borderless)
                        .fontWeight(.semibold)
                        .disabled(countValue == nil)
                }
                Button { showScan = true } label: {
                    Label("Packung scannen", systemImage: "barcode.viewfinder")
                }
                if let p = draft.packSize {
                    Button { receivedPack() } label: {
                        Label("Packung erhalten (+\(p))", systemImage: "shippingbox")
                    }
                    .disabled(f.status == .missing)
                }
            } header: {
                Text("Bestand")
            } footer: {
                if store.settings.healthConnected && draft.healthName != nil {
                    Text("Abgezogen wird, was du in Apple Health als „genommen“ protokollierst.")
                } else if draft.isWeekly {
                    Text("Abgezogen wird am Einnahmetag die Menge aus dem Einnahmeplan.")
                } else {
                    Text("Abgezogen wird pro Tag die Menge aus dem Einnahmeplan.")
                }
            }

            let packs = store.packs(for: draft.id)
            if !packs.isEmpty {
                Section {
                    ForEach(packs) { pack in
                        LabeledContent(pack.label) {
                            Text("\(pack.size) Stück")
                        }
                        .swipeActions {
                            Button("Entfernen", role: .destructive) { store.removePack(key: pack.key) }
                        }
                    }
                } header: {
                    Text("Bekannte Packungen")
                } footer: {
                    Text("Diese Packungen erkennt der Scan automatisch. Zum Entfernen nach links wischen.")
                }
            }

            Section("Rezept") {
                if let d = draft.orderedOn {
                    LabeledContent("Angefragt am") { Text(d.shortDay) }
                    Button("Anfrage zurücksetzen") { draft.orderedOn = nil }
                } else {
                    Button("Als angefragt markieren") { draft.orderedOn = .now }
                        .disabled(f.status == .paused)
                }
            }

            Section("Angaben") {
                TextField("Name", text: $draft.name)
                    .focused($focused, equals: .name)
                    .submitLabel(.done)
                TextField("Stärke, z. B. 80 mg", text: $draft.strength)
                    .focused($focused, equals: .strength)
                    .submitLabel(.done)
                Picker("Einnahme", selection: weeklyBinding) {
                    Text("Täglich").tag(false)
                    Text("Wöchentlich").tag(true)
                }
                .pickerStyle(.segmented)
                if let wd = draft.weeklyDay {
                    Picker("Wochentag", selection: Binding(get: { wd }, set: { draft.weeklyDay = $0 })) {
                        ForEach(Calc.orderedWeekdays, id: \.self) { day in
                            Text(Calc.weekdayName(day, short: false)).tag(day)
                        }
                    }
                }
                Stepper(value: $draft.dosesPerDay, in: 0...20, step: 0.5) {
                    LabeledContent(draft.isWeekly ? LocalizedStringKey("Stück pro Woche") : LocalizedStringKey("Stück pro Tag")) {
                        Text(draft.dosesPerDay.pieces).monospacedDigit()
                    }
                }
                LabeledContent("Stück pro Packung") {
                    TextField("z. B. 100", text: $packText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focused, equals: .packSize)
                }
                Toggle("Pausiert", isOn: $draft.isPaused)
            }

            if store.settings.healthConnected {
                Section {
                    Picker("Verknüpft mit", selection: $draft.healthName) {
                        Text("Nicht verknüpft").tag(String?.none)
                        ForEach(pickerOptions, id: \.self) { name in
                            Text(label(for: name)).tag(String?.some(name))
                        }
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Nicht verknüpfte Medikamente rechnen nach Einnahmeplan.")
                }
            }

            Section {
                Button("Medikament entfernen", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle(draft.name)
        .pageForm()
        .tint(Color.accent)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            if focused != nil {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    if focused == .count {
                        Button("Übernehmen") { applyCount() }
                            .fontWeight(.semibold)
                            .disabled(countValue == nil)
                    } else {
                        Button("Fertig") { focused = nil }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .confirmationDialog("\(draft.name) entfernen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Entfernen", role: .destructive) {
                store.delete(draft.id)
                dismiss()
            }
        }
        .sheet(isPresented: $showScan) { PackScanView(medicationID: draft.id) }
        .task { await loadHealthMeds() }
        .onChange(of: draft) { _, new in store.update(new) }
        .onChange(of: stored) { _, new in
            if let new, new != draft { draft = new }
        }
        .onChange(of: packText) { _, text in
            let value = Int(text.trimmingCharacters(in: .whitespaces)).flatMap { $0 > 0 ? $0 : nil }
            if draft.packSize != value { draft.packSize = value }
        }
        .onChange(of: draft.packSize) { _, value in
            // Änderung von außen (z. B. Scan) ins Feld übernehmen, solange nicht getippt wird
            if focused != .packSize { packText = value.map(String.init) ?? "" }
        }
        .onChange(of: draft.healthName) { old, _ in
            var before = draft
            before.healthName = old
            rebase(from: before)
        }
        .onChange(of: draft.weeklyDay) { old, _ in
            // Wechsel täglich/wöchentlich oder Wochentag: bisherigen Verbrauch nach altem Plan festschreiben
            var before = draft
            before.weeklyDay = old
            rebase(from: before)
        }
    }

    private var pickerOptions: [String] {
        var names = healthMeds.filter { !$0.isArchived }.map(\.name)
        if let current = draft.healthName, !names.contains(current) { names.append(current) }
        return names
    }

    private func label(for name: String) -> String {
        if let nick = healthMeds.first(where: { $0.name == name })?.nickname, !nick.isEmpty { return nick }
        return name
    }

    private func loadHealthMeds() async {
        guard store.settings.healthConnected, HealthSync.shared.isAvailable else { return }
        healthMeds = (try? await HealthSync.shared.medications()) ?? []
    }

    private func applyCount() {
        guard let c = countValue else { return }
        draft.stock = max(0, c)
        draft.stockDate = .now
        draft.consumedSinceStock = 0
        countText = ""
        focused = nil
    }

    private func receivedPack() {
        guard let p = draft.packSize, let current = store.forecast(draft).current else { return }
        draft.stock = current.rounded(.down) + Double(p)
        draft.stockDate = .now
        draft.consumedSinceStock = 0
        draft.orderedOn = nil
        store.noteHappyMoment()
    }

    /// Täglich ↔ wöchentlich bzw. ohne Wochentag-Angabe: aktueller Wochentag als Vorgabe
    private var weeklyBinding: Binding<Bool> {
        Binding(
            get: { draft.weeklyDay != nil },
            set: { on in
                if on, draft.weeklyDay == nil {
                    draft.weeklyDay = Calendar.current.component(.weekday, from: .now)
                } else if !on {
                    draft.weeklyDay = nil
                }
            }
        )
    }

    /// Beim Wechsel zwischen „nach Plan“ und „aus Health“ oder zwischen täglich und wöchentlich
    /// den aktuellen Stand festschreiben, damit nichts doppelt oder gar nicht abgezogen wird.
    private func rebase(from before: Medication) {
        guard draft.stock != nil else { return }
        if let current = store.forecast(before).current {
            draft.stock = current.rounded(.down)
            draft.stockDate = .now
            draft.consumedSinceStock = 0
        }
    }
}
