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
    @State private var countInput: Double?
    @State private var healthMeds: [HealthMedication] = []
    @State private var confirmDelete = false
    @FocusState private var countFocused: Bool

    init(med: Medication) {
        _draft = State(initialValue: med)
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
                    TextField("Jetzt gezählt", value: $countInput, format: .number)
                        .keyboardType(.decimalPad)
                        .focused($countFocused)
                    Button("Übernehmen") { applyCount() }
                        .disabled(countInput == nil)
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
                Text(store.settings.healthConnected && draft.healthName != nil
                     ? "Abgezogen wird, was du in Apple Health als „genommen“ protokollierst."
                     : "Abgezogen wird pro Tag die Menge aus dem Einnahmeplan.")
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
                TextField("Stärke, z. B. 80 mg", text: $draft.strength)
                Stepper(value: $draft.dosesPerDay, in: 0...20, step: 0.5) {
                    LabeledContent("Stück pro Tag") { Text(draft.dosesPerDay.pieces).monospacedDigit() }
                }
                LabeledContent("Stück pro Packung") {
                    TextField("z. B. 100", value: $draft.packSize, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
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
            if countFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { countFocused = false }
                }
            }
        }
        .confirmationDialog("\(draft.name) entfernen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Entfernen", role: .destructive) {
                store.delete(draft.id)
                dismiss()
            }
        }
        .task { await loadHealthMeds() }
        .onChange(of: draft) { _, new in store.update(new) }
        .onChange(of: stored) { _, new in
            if let new, new != draft { draft = new }
        }
        .onChange(of: draft.healthName) { old, _ in
            rebaseAfterModeChange(oldHealthName: old)
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
        guard let c = countInput else { return }
        draft.stock = max(0, c)
        draft.stockDate = .now
        draft.consumedSinceStock = 0
        countInput = nil
        countFocused = false
    }

    private func receivedPack() {
        guard let p = draft.packSize, let current = store.forecast(draft).current else { return }
        draft.stock = current.rounded(.down) + Double(p)
        draft.stockDate = .now
        draft.consumedSinceStock = 0
        draft.orderedOn = nil
    }

    /// Beim Wechsel zwischen „nach Plan“ und „aus Health“ den aktuellen Stand festschreiben,
    /// damit nichts doppelt oder gar nicht abgezogen wird.
    private func rebaseAfterModeChange(oldHealthName: String?) {
        guard draft.stock != nil else { return }
        var before = draft
        before.healthName = oldHealthName
        if let current = store.forecast(before).current {
            draft.stock = current.rounded(.down)
            draft.stockDate = .now
            draft.consumedSinceStock = 0
        }
    }
}
