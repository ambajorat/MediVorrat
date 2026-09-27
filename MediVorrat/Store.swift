import Foundation
import Observation

struct MedItem: Identifiable {
    let med: Medication
    let forecast: Forecast
    var id: UUID { med.id }
}

@MainActor
@Observable
final class Store {
    var medications: [Medication] = []
    var settings = AppSettings()
    var lastHealthSync: Date?
    var healthError: String?

    private struct Snapshot: Codable {
        var medications: [Medication]
        var settings: AppSettings
    }

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("medivorrat.json")
    }()

    init() { load() }

    // MARK: Persistenz

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        medications = snap.medications
        settings = snap.settings
    }

    func save() {
        let snap = Snapshot(medications: medications, settings: settings)
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        }
        Notifications.reschedule(items: items, hour: settings.reminderHour)
    }

    // MARK: Abgeleitete Werte

    func forecast(_ m: Medication) -> Forecast { Calc.forecast(m, settings: settings) }

    var items: [MedItem] {
        medications
            .map { MedItem(med: $0, forecast: forecast($0)) }
            .sorted {
                if $0.forecast.status != $1.forecast.status { return $0.forecast.status < $1.forecast.status }
                return ($0.forecast.daysLeft ?? 9999) < ($1.forecast.daysLeft ?? 9999)
            }
    }

    // MARK: Änderungen

    func update(_ m: Medication) {
        if let i = medications.firstIndex(where: { $0.id == m.id }) {
            guard medications[i] != m else { return }
            medications[i] = m
        } else {
            medications.append(m)
        }
        save()
    }

    func add(_ list: [Medication]) {
        medications.append(contentsOf: list)
        save()
    }

    func delete(_ id: UUID) {
        medications.removeAll { $0.id == id }
        save()
    }

    func markOrdered(_ ids: Set<UUID>) {
        for i in medications.indices where ids.contains(medications[i].id) {
            medications[i].orderedOn = .now
        }
        save()
    }

    // MARK: Apple Health

    /// Apple Health an- oder ausschalten. Vorher wird jeder Bestand mit der
    /// bisherigen Rechenart festgeschrieben, damit beim Umschalten nichts springt.
    func setHealthEnabled(_ on: Bool) {
        guard settings.healthConnected != on else { return }
        for i in medications.indices {
            if let current = forecast(medications[i]).current {
                medications[i].stock = current.rounded(.down)
                medications[i].stockDate = .now
                medications[i].consumedSinceStock = 0
            }
        }
        settings.healthConnected = on
        save()
    }

    func refresh() async {
        await syncHealth()
        save()
    }

    func syncHealth() async {
        let linked = medications.filter { $0.healthName != nil && $0.stockDate != nil }
        guard settings.healthConnected, !linked.isEmpty, HealthSync.shared.isAvailable,
              let earliest = linked.compactMap(\.stockDate).min() else { return }
        do {
            let doses = try await HealthSync.shared.takenDoses(since: earliest)
            for i in medications.indices {
                guard let name = medications[i].healthName, let since = medications[i].stockDate else { continue }
                medications[i].consumedSinceStock = doses
                    .filter { $0.name == name && $0.date >= since }
                    .reduce(0) { $0 + $1.quantity }
            }
            lastHealthSync = .now
            healthError = nil
        } catch {
            healthError = error.localizedDescription
        }
    }

    // MARK: Rezeptanfrage

    func prescriptionText(for ids: Set<UUID>) -> String {
        let lines = medications
            .filter { ids.contains($0.id) }
            .map { m -> String in
                var s = "– \(m.displayName)"
                if let p = m.packSize { s += ", Packung à \(p) Stück" }
                return s
            }
        var t = "Guten Tag"
        if !settings.practiceName.isEmpty { t += " liebes Team der \(settings.practiceName)" }
        t += ",\n\nich bitte um Folgerezepte für:\n\n"
        t += lines.isEmpty ? "– (bitte Medikamente auswählen)" : lines.joined(separator: "\n")
        t += "\n\n"
        if settings.askForERezept { t += "Gern als E-Rezept auf meine Gesundheitskarte.\n\n" }
        t += "Vielen Dank und viele Grüße"
        if !settings.patientName.isEmpty { t += "\n\(settings.patientName)" }
        if !settings.birthDate.isEmpty { t += "\ngeb. \(settings.birthDate)" }
        return t
    }
}
