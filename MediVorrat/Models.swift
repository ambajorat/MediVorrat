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
}

extension Double {
    var pieces: String { formatted(.number.precision(.fractionLength(0...1))) }
}
