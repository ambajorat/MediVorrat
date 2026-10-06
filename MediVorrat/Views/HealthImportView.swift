import SwiftUI

struct HealthImportView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [HealthMedication] = []
    @State private var selected: Set<String> = []
    @State private var perDay: [String: Double] = [:]
    @State private var loading = true
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView("Lese Apple Health …")
                } else if let errorText {
                    ContentUnavailableView("Apple Health nicht erreichbar", systemImage: "heart.slash", description: Text(errorText))
                } else if candidates.isEmpty {
                    ContentUnavailableView("Keine neuen Medikamente",
                                           systemImage: "checkmark.circle",
                                           description: Text("Alle freigegebenen Medikamente sind schon in der Liste. Weitere gibst du in den Einstellungen frei."))
                } else {
                    List {
                        Section {
                            ForEach(candidates) { m in
                                Toggle(isOn: binding(for: m.name)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(title(for: m))
                                        Text("etwa \((perDay[m.name] ?? 1).pieces) pro Tag")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                        if let nick = m.nickname, !nick.isEmpty {
                                            Text(m.name).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        } footer: {
                            Text("Die Menge pro Tag ist der Durchschnitt deiner Einnahmen der letzten 14 Tage. Du kannst sie danach anpassen.")
                        }
                    }
                }
            }
            .navigationTitle("Aus Apple Health")
            .pageForm()
            .tint(Color.accent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") { importSelected() }
                        .disabled(selected.isEmpty)
                }
            }
            .task { await load() }
        }
    }

    private func title(for m: HealthMedication) -> String {
        if let nick = m.nickname, !nick.isEmpty { return nick }
        return m.name
    }

    private func binding(for name: String) -> Binding<Bool> {
        Binding(
            get: { selected.contains(name) },
            set: { on in if on { selected.insert(name) } else { selected.remove(name) } }
        )
    }

    private func load() async {
        defer { loading = false }
        guard HealthSync.shared.isAvailable else {
            errorText = String(localized: "Auf diesem Gerät gibt es keine Health-Daten.")
            return
        }
        do {
            try await HealthSync.shared.requestAccess()
            store.setHealthEnabled(true)

            let known = Set(store.medications.compactMap(\.healthName))
            candidates = try await HealthSync.shared.medications()
                .filter { !$0.isArchived && !known.contains($0.name) }

            let since = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
            let doses = try await HealthSync.shared.takenDoses(since: since)
            for m in candidates {
                let sum = doses.filter { $0.name == m.name }.reduce(0) { $0 + $1.quantity }
                perDay[m.name] = sum > 0 ? max(0.5, (sum / 14 * 2).rounded() / 2) : 1
            }
            selected = Set(candidates.map(\.name))
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func importSelected() {
        let new = candidates
            .filter { selected.contains($0.name) }
            .map { Medication(name: title(for: $0), dosesPerDay: perDay[$0.name] ?? 1, healthName: $0.name) }
        store.add(new)
        dismiss()
    }
}
