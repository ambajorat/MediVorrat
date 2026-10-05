import Foundation

struct Medication: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var strength: String = ""
    /// Stück pro Tag laut Einnahmeplan (für die Prognose)
    var dosesPerDay: Double = 1
    var packSize: Int? = nil
    /// Zuletzt gezählter Bestand
    var stock: Double? = nil
    /// Zeitpunkt der Zählung
    var stockDate: Date? = nil
    /// Aus Apple Health: seit der Zählung als „genommen“ protokollierte Menge
    var consumedSinceStock: Double = 0
    /// displayText des verknüpften Health-Medikaments (nil = rechnen nach Plan)
    var healthName: String? = nil
    var orderedOn: Date? = nil
    var isPaused: Bool = false

    var displayName: String { strength.isEmpty ? name : "\(name) \(strength)" }
}

struct AppSettings: Codable, Equatable {
    var leadDays: Int = 14
    var soonDays: Int = 7
    var patientName: String = ""
    var birthDate: String = ""
    var practiceName: String = ""
    var practiceEmail: String = ""
    var askForERezept: Bool = true
    var reminderHour: Int = 9
    /// Schalter „Apple Health nutzen“
    var healthConnected: Bool = false
    /// Quartalsweise Prüfung, ob die Gesundheitskarte in der Praxis eingelesen ist
    var cardCheck: Bool = true
    /// Wann die Karte zuletzt in der Praxis eingelesen wurde
    var cardReadDate: Date? = nil

    enum CodingKeys: String, CodingKey {
        case leadDays, soonDays, patientName, birthDate, practiceName, practiceEmail,
             askForERezept, reminderHour, healthConnected, cardCheck, cardReadDate
    }
}

// Tolerant gegenüber älteren Dateien und iCloud-Ständen ohne neue Felder.
// In einer Extension, damit AppSettings() erhalten bleibt.
extension AppSettings {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        leadDays = try c.decodeIfPresent(Int.self, forKey: .leadDays) ?? d.leadDays
        soonDays = try c.decodeIfPresent(Int.self, forKey: .soonDays) ?? d.soonDays
        patientName = try c.decodeIfPresent(String.self, forKey: .patientName) ?? d.patientName
        birthDate = try c.decodeIfPresent(String.self, forKey: .birthDate) ?? d.birthDate
        practiceName = try c.decodeIfPresent(String.self, forKey: .practiceName) ?? d.practiceName
        practiceEmail = try c.decodeIfPresent(String.self, forKey: .practiceEmail) ?? d.practiceEmail
        askForERezept = try c.decodeIfPresent(Bool.self, forKey: .askForERezept) ?? d.askForERezept
        reminderHour = try c.decodeIfPresent(Int.self, forKey: .reminderHour) ?? d.reminderHour
        healthConnected = try c.decodeIfPresent(Bool.self, forKey: .healthConnected) ?? d.healthConnected
        cardCheck = try c.decodeIfPresent(Bool.self, forKey: .cardCheck) ?? d.cardCheck
        cardReadDate = try c.decodeIfPresent(Date.self, forKey: .cardReadDate)
    }
}

/// Gesundheitskarte: Bei Dauermedikation muss sie einmal pro Kalenderquartal
/// in der Praxis eingelesen werden (Q1 Jan–Mär, Q2 Apr–Jun, Q3 Jul–Sep, Q4 Okt–Dez).
enum InsuranceCard {
    enum State: Equatable {
        /// Prüfung ausgeschaltet (z. B. privat versichert)
        case off
        /// Noch nie ein Datum erfasst
        case unknown
        /// In diesem Quartal eingelesen
        case valid(readOn: Date, until: Date)
        /// Gültig, aber das Quartal endet in wenigen Tagen
        case endingSoon(readOn: Date, until: Date)
        /// Zuletzt in einem früheren Quartal eingelesen
        case expired(readOn: Date)

        var needsReading: Bool {
            switch self {
            case .unknown, .expired: return true
            default: return false
            }
        }
    }

    /// Ab so vielen Tagen vor Quartalsende wird gewarnt
    static let endingSoonDays = 7

    static var cal: Calendar { Calendar.current }

    static func quarterStart(_ d: Date) -> Date {
        let c = cal.dateComponents([.year, .month], from: d)
        let month = ((c.month ?? 1) - 1) / 3 * 3 + 1
        return cal.date(from: DateComponents(year: c.year, month: month, day: 1)) ?? cal.startOfDay(for: d)
    }

    /// Letzter Tag des Quartals
    static func quarterEnd(_ d: Date) -> Date {
        let next = cal.date(byAdding: .month, value: 3, to: quarterStart(d)) ?? d
        return cal.date(byAdding: .day, value: -1, to: next) ?? d
    }

    static func sameQuarter(_ a: Date, _ b: Date) -> Bool {
        quarterStart(a) == quarterStart(b)
    }

    /// „4. Quartal 2026“
    static func quarterLabel(_ d: Date) -> String {
        let c = cal.dateComponents([.year, .month], from: d)
        return "\(((c.month ?? 1) - 1) / 3 + 1). Quartal \(c.year ?? 0)"
    }

    static func state(_ s: AppSettings, now: Date = .now) -> State {
        guard s.cardCheck else { return .off }
        guard let read = s.cardReadDate else { return .unknown }
        guard sameQuarter(read, now) else { return .expired(readOn: read) }
        let end = quarterEnd(now)
        if Calc.days(from: now, to: end) < endingSoonDays { return .endingSoon(readOn: read, until: end) }
        return .valid(readOn: read, until: end)
    }

    /// Muss die Karte für einen Tag (z. B. einen Erinnerungstag) neu eingelesen werden?
    static func needsReading(on day: Date, settings s: AppSettings) -> Bool {
        guard s.cardCheck else { return false }
        guard let read = s.cardReadDate else { return true }
        return !sameQuarter(read, day)
    }
}

enum StockStatus: Int, Comparable {
    case orderNow = 0, ordered, soon, missing, ok, paused

    static func < (a: StockStatus, b: StockStatus) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .orderNow: return "Rezept anfordern"
        case .ordered: return "Angefragt"
        case .soon: return "Bald anfordern"
        case .missing: return "Bestand fehlt"
        case .ok: return "Ausreichend"
        case .paused: return "Pausiert"
        }
    }

    var needsPrescription: Bool { self == .orderNow || self == .soon }
}

struct Forecast {
    var status: StockStatus
    var current: Double? = nil
    var daysLeft: Int? = nil
    var until: Date? = nil
    var orderBy: Date? = nil
    var orderIn: Int? = nil
}

enum Calc {
    static var cal: Calendar { Calendar.current }

    static func days(from a: Date, to b: Date) -> Int {
        cal.dateComponents([.day], from: cal.startOfDay(for: a), to: cal.startOfDay(for: b)).day ?? 0
    }

    static func forecast(_ m: Medication, settings: AppSettings, now: Date = .now) -> Forecast {
        if m.isPaused || m.dosesPerDay <= 0 { return Forecast(status: .paused) }
        guard let stock = m.stock, let stockDate = m.stockDate else { return Forecast(status: .missing) }

        let consumed: Double
        if settings.healthConnected && m.healthName != nil {
            consumed = m.consumedSinceStock
        } else {
            // Nach Plan: pro angebrochenem Kalendertag nach der Zählung eine Tagesmenge
            consumed = m.dosesPerDay * Double(max(0, days(from: stockDate, to: now)))
        }
        let current = max(0, stock - consumed)
        let daysLeft = Int((current / m.dosesPerDay).rounded(.down))
        let today = cal.startOfDay(for: now)
        let until = cal.date(byAdding: .day, value: daysLeft, to: today) ?? today
        let orderBy = cal.date(byAdding: .day, value: -settings.leadDays, to: until) ?? until
        let orderIn = days(from: today, to: orderBy)

        let status: StockStatus
        if m.orderedOn != nil { status = .ordered }
        else if orderIn <= 0 { status = .orderNow }
        else if orderIn <= settings.soonDays { status = .soon }
        else { status = .ok }

        return Forecast(status: status, current: current, daysLeft: daysLeft, until: until, orderBy: orderBy, orderIn: orderIn)
    }
}

extension Date {
    var shortDay: String { formatted(.dateTime.weekday(.abbreviated).day().month(.twoDigits)) }
    /// „02.10.2026“
    var germanDate: String { formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()) }
}

extension Double {
    var pieces: String { formatted(.number.precision(.fractionLength(0...1))) }
}
