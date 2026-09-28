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
    /// Gelernte Packungen: PZN (bzw. Code) → Medikament + Stückzahl
    var packCatalog: [String: PackEntry] = [:]
    /// Bereits eingebuchte Einzelpackungen (PZN|Seriennummer)
    var bookedPacks: [String] = []
    /// Zähler für die Bewertungsabfrage (Packung eingebucht, Rezept angefragt)
    private(set) var happyMoments: Int = UserDefaults.standard.integer(forKey: "mv_happy_moments")
    var lastHealthSync: Date?
    var healthError: String?
    /// Zeitpunkt der letzten inhaltlichen Änderung (Konfliktregel für iCloud)
    private(set) var modifiedAt: Date?
    private(set) var cloudSyncOn: Bool = CloudSync.shared.isEnabled
    private(set) var lastCloudSync: Date?
    /// Letzter gespeicherter Inhalt ohne Zeitstempel – nur echte Änderungen werden geschrieben und hochgeladen
    @ObservationIgnored private var lastContent: Data?
    /// Letzter hochgeladener Cloud-Inhalt (ohne Health-Werte, ohne Zeitstempel)
    @ObservationIgnored private var lastCloudContent: Data?

    private struct Snapshot: Codable {
        var medications: [Medication]
        var settings: AppSettings
        var packCatalog: [String: PackEntry]
        var bookedPacks: [String]
        var modifiedAt: Date?

        init(medications: [Medication], settings: AppSettings,
             packCatalog: [String: PackEntry], bookedPacks: [String], modifiedAt: Date? = nil) {
            self.medications = medications
            self.settings = settings
            self.packCatalog = packCatalog
            self.bookedPacks = bookedPacks
            self.modifiedAt = modifiedAt
        }

        // Tolerant gegenüber älteren Dateien ohne Packungsdaten
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            medications = try c.decode([Medication].self, forKey: .medications)
            settings = try c.decode(AppSettings.self, forKey: .settings)
            packCatalog = try c.decodeIfPresent([String: PackEntry].self, forKey: .packCatalog) ?? [:]
            bookedPacks = try c.decodeIfPresent([String].self, forKey: .bookedPacks) ?? []
            modifiedAt = try c.decodeIfPresent(Date.self, forKey: .modifiedAt)
        }
    }

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("medivorrat.json")
    }()

    init() {
        load()
        lastContent = encode(snapshot(stamped: false))
        CloudSync.shared.onRemoteChange = { [weak self] data in
            self?.applyRemote(data)
        }
        CloudSync.shared.start()
        if cloudSyncOn { pullFromCloud() }
    }

    // MARK: Persistenz

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]   // stabile Bytes für den Änderungsvergleich
        return e
    }()

    private func encode(_ snap: Snapshot) -> Data? { try? Self.encoder.encode(snap) }

    private func snapshot(stamped: Bool) -> Snapshot {
        Snapshot(medications: medications, settings: settings,
                 packCatalog: packCatalog, bookedPacks: bookedPacks,
                 modifiedAt: stamped ? modifiedAt : nil)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        medications = snap.medications
        settings = snap.settings
        packCatalog = snap.packCatalog
        bookedPacks = snap.bookedPacks
        modifiedAt = snap.modifiedAt
    }

    private func writeLocal() {
        if let data = encode(snapshot(stamped: true)) {
            try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        }
    }

    func save() {
        let content = encode(snapshot(stamped: false))
        if content != lastContent {
            lastContent = content
            modifiedAt = .now
            writeLocal()
            pushToCloud()
        }
        Notifications.reschedule(items: items, hour: settings.reminderHour)
    }

    // MARK: iCloud

    func setCloudSync(_ on: Bool) {
        CloudSync.shared.isEnabled = on
        cloudSyncOn = on
        guard on else { return }
        pullFromCloud()             // neuerer Cloud-Stand gewinnt …
        pushToCloud(force: true)    // … sonst geht der eigene Stand hoch
    }

    /// Stand für iCloud – OHNE alles, was aus Apple Health stammt
    /// (App-Store-Richtlinie 5.1.3: keine HealthKit-Daten in iCloud).
    /// Health-Verknüpfung und aus Health gezählter Verbrauch bleiben auf dem Gerät.
    private func cloudSnapshot(stamped: Bool) -> Snapshot {
        var s = snapshot(stamped: stamped)
        s.settings.healthConnected = false
        s.medications = s.medications.map { m in
            var c = m
            c.healthName = nil
            c.consumedSinceStock = 0
            return c
        }
        return s
    }

    private func pushToCloud(force: Bool = false) {
        guard cloudSyncOn else { return }
        let content = encode(cloudSnapshot(stamped: false))
        // Reine Health-Änderungen lösen keinen Upload aus
        guard force || content != lastCloudContent,
              let data = encode(cloudSnapshot(stamped: true)) else { return }
        lastCloudContent = content
        CloudSync.shared.push(data)
        lastCloudSync = .now
    }

    func pullFromCloud() {
        guard cloudSyncOn, let data = CloudSync.shared.remoteData() else { return }
        applyRemote(data)
    }

    /// Übernimmt einen Cloud-Stand, wenn er neuer ist. Der Apple-Health-Schalter bleibt pro Gerät.
    private func applyRemote(_ data: Data) {
        guard let snap = try? JSONDecoder().decode(Snapshot.self, from: data),
              let remoteDate = snap.modifiedAt,
              remoteDate > (modifiedAt ?? .distantPast) else { return }
        let localHealth = settings.healthConnected
        let local = Dictionary(medications.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        // Health-Werte kommen nie aus der Cloud – lokale behalten
        medications = snap.medications.map { remote in
            var m = remote
            if let l = local[remote.id] {
                m.healthName = l.healthName
                m.consumedSinceStock = (l.stockDate == remote.stockDate) ? l.consumedSinceStock : 0
            }
            return m
        }
        settings = snap.settings
        settings.healthConnected = localHealth
        packCatalog = snap.packCatalog
        bookedPacks = snap.bookedPacks
        modifiedAt = remoteDate
        lastContent = encode(snapshot(stamped: false))
        lastCloudContent = encode(cloudSnapshot(stamped: false))
        writeLocal()
        lastCloudSync = .now
        Notifications.reschedule(items: items, hour: settings.reminderHour)
        // Wurde auf dem anderen Gerät neu gezählt, den Health-Verbrauch ab dort neu lesen
        if settings.healthConnected && medications.contains(where: { $0.healthName != nil }) {
            Task { await refresh() }
        }
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
        packCatalog = packCatalog.filter { $0.value.medicationID != id }
        save()
    }

    // MARK: Packungs-Scan

    /// Bekannte Packung, sofern das Medikament noch existiert
    func knownPack(_ code: PackCode) -> (entry: PackEntry, med: Medication)? {
        guard let entry = packCatalog[code.key],
              let med = medications.first(where: { $0.id == entry.medicationID }) else { return nil }
        return (entry, med)
    }

    func isAlreadyBooked(_ code: PackCode) -> Bool {
        guard let id = code.packID else { return false }
        return bookedPacks.contains(id)
    }

    /// Packung nur zuordnen, ohne den Bestand zu ändern
    /// (z. B. für die angebrochene Packung, die schon im gezählten Bestand steckt).
    func assignPack(_ code: PackCode, medicationID: UUID, packSize: Int) {
        guard let i = medications.firstIndex(where: { $0.id == medicationID }) else { return }
        packCatalog[code.key] = PackEntry(medicationID: medicationID, packSize: packSize)
        if medications[i].packSize == nil { medications[i].packSize = packSize }
        save()
    }

    func removePack(key: String) {
        packCatalog[key] = nil
        save()
    }

    /// Zugeordnete Packungssorten eines Medikaments (Schlüssel = PZN bzw. Code)
    func packs(for medicationID: UUID) -> [KnownPack] {
        packCatalog
            .filter { $0.value.medicationID == medicationID }
            .map { KnownPack(key: $0.key, size: $0.value.packSize) }
            .sorted { $0.key < $1.key }
    }

    /// Packung einbuchen: Bestand = aktuell + Stückzahl, „angefragt“ zurücksetzen.
    /// Ist noch kein Bestand erfasst, startet der Bestand mit dieser Packung.
    func bookPack(_ code: PackCode, medicationID: UUID, packSize: Int) {
        guard let i = medications.firstIndex(where: { $0.id == medicationID }) else { return }
        packCatalog[code.key] = PackEntry(medicationID: medicationID, packSize: packSize)
        if medications[i].packSize == nil { medications[i].packSize = packSize }
        let current = forecast(medications[i]).current ?? 0
        medications[i].stock = current.rounded(.down) + Double(packSize)
        medications[i].stockDate = .now
        medications[i].consumedSinceStock = 0
        medications[i].orderedOn = nil
        noteHappyMoment()
        if let id = code.packID {
            bookedPacks.append(id)
            if bookedPacks.count > 500 { bookedPacks.removeFirst(bookedPacks.count - 500) }
        }
        save()
    }

    func noteHappyMoment() {
        happyMoments += 1
        UserDefaults.standard.set(happyMoments, forKey: "mv_happy_moments")
    }

    func markOrdered(_ ids: Set<UUID>) {
        if !ids.isEmpty { noteHappyMoment() }
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
        pullFromCloud()
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

    private func requestedMeds(_ ids: Set<UUID>) -> [Medication] {
        medications.filter { ids.contains($0.id) }
    }

    private func dailyText(_ m: Medication) -> String {
        "\(m.dosesPerDay.pieces) Stück täglich"
    }

    var prescriptionSubject: String {
        var s = "Bitte um Folgerezept"
        if !settings.patientName.isEmpty { s += " – \(settings.patientName)" }
        if !settings.birthDate.isEmpty { s += " (geb. \(settings.birthDate))" }
        return s
    }

    /// Klartext für Teilen, Nachrichten und mailto
    func prescriptionText(for ids: Set<UUID>) -> String {
        let lines = requestedMeds(ids).map { m -> String in
            var s = "• \(m.displayName)"
            if let p = m.packSize { s += ", Packung à \(p) Stück" }
            s += " (\(dailyText(m)))"
            return s
        }
        var t = "Liebes Praxisteam,\n\n"
        t += "ich bitte um Folgerezepte für folgende Medikamente:\n\n"
        t += lines.isEmpty ? "• (bitte Medikamente auswählen)" : lines.joined(separator: "\n")
        t += "\n\n"
        if settings.askForERezept { t += "Gern als E-Rezept auf meine Gesundheitskarte.\n\n" }
        t += "Vielen Dank und viele Grüße"
        if !settings.patientName.isEmpty { t += "\n\(settings.patientName)" }
        if !settings.birthDate.isEmpty { t += "\ngeb. \(settings.birthDate)" }
        return t
    }

    /// Formatierte Mail mit Tabelle für das Mail-Fenster
    func prescriptionHTML(for ids: Set<UUID>) -> String {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;")
             .replacingOccurrences(of: "<", with: "&lt;")
             .replacingOccurrences(of: ">", with: "&gt;")
        }
        let cell = "padding:8px 12px;border:1px solid #d8d3ca;text-align:left;vertical-align:top"
        let head = cell + ";background:#f4f1ec;font-weight:600"
        let rows = requestedMeds(ids).map { m -> String in
            let name = "<b>\(esc(m.name))</b>" + (m.strength.isEmpty ? "" : " \(esc(m.strength))")
            let pack = m.packSize.map { "\($0) Stück" } ?? "–"
            return "<tr><td style=\"\(cell)\">\(name)</td><td style=\"\(cell)\">\(pack)</td><td style=\"\(cell)\">\(esc(dailyText(m)))</td></tr>"
        }.joined()

        var h = "<div style=\"font-family:-apple-system,Helvetica,Arial,sans-serif;font-size:15px;line-height:1.5;color:#1d1d1f\">"
        h += "<p>Liebes Praxisteam,</p>"
        h += "<p>ich bitte um Folgerezepte für folgende Medikamente:</p>"
        h += "<table cellspacing=\"0\" cellpadding=\"0\" style=\"border-collapse:collapse;margin:8px 0 16px\">"
        h += "<tr><th style=\"\(head)\">Medikament</th><th style=\"\(head)\">Packung</th><th style=\"\(head)\">Einnahme</th></tr>"
        h += rows
        h += "</table>"
        if settings.askForERezept { h += "<p>Gern als <b>E-Rezept</b> auf meine Gesundheitskarte.</p>" }
        h += "<p>Vielen Dank und viele Grüße"
        if !settings.patientName.isEmpty { h += "<br>\(esc(settings.patientName))" }
        if !settings.birthDate.isEmpty { h += "<br>geb. \(esc(settings.birthDate))" }
        h += "</p></div>"
        return h
    }
}
