import SwiftUI
import StoreKit

/// Entscheidet, WANN das System-Bewertungsfenster angefragt wird (Muster aus Blase & Darm).
/// Glücksmomente in MediVorrat: Packung eingebucht oder Rezept angefragt.
/// Apple deckelt zusätzlich auf max. 3 Anzeigen pro Jahr; in Debug/TestFlight erscheint nie etwas.
enum ReviewGate {
    private static let thresholds = [3, 12, 30]
    private static let minDaysBetween = 60
    private static let maxPerYear = 3

    private static let doneKey = "mv_review_done_thresholds"
    private static let datesKey = "mv_review_request_dates"

    static func shouldRequest(count: Int) -> Bool {
        let defaults = UserDefaults.standard
        let done = defaults.array(forKey: doneKey) as? [Int] ?? []
        guard thresholds.contains(where: { count >= $0 && !done.contains($0) }) else { return false }

        let dates = defaults.array(forKey: datesKey) as? [Date] ?? []
        let yearAgo = Calendar.current.date(byAdding: .day, value: -365, to: Date()) ?? .distantPast
        let recent = dates.filter { $0 > yearAgo }
        guard recent.count < maxPerYear else { return false }
        if let last = recent.max() {
            let cutoff = Calendar.current.date(byAdding: .day, value: -minDaysBetween, to: Date()) ?? .distantPast
            guard last < cutoff else { return false }
        }
        return true
    }

    static func markRequested(count: Int) {
        let defaults = UserDefaults.standard
        var done = defaults.array(forKey: doneKey) as? [Int] ?? []
        for t in thresholds where count >= t && !done.contains(t) { done.append(t) }
        defaults.set(done, forKey: doneKey)
        var dates = defaults.array(forKey: datesKey) as? [Date] ?? []
        dates.append(Date())
        defaults.set(dates, forKey: datesKey)
    }
}

/// Beobachtet die Glücksmomente und fragt mit 2 Sekunden Verzögerung an.
struct ReviewRequester: ViewModifier {
    @Environment(Store.self) private var store
    @Environment(\.requestReview) private var requestReview

    func body(content: Content) -> some View {
        content.onChange(of: store.happyMoments) { _, count in
            guard ReviewGate.shouldRequest(count: count) else { return }
            ReviewGate.markRequested(count: count)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                requestReview()
            }
        }
    }
}
