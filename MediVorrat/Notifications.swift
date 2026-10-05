import Foundation
import UserNotifications

/// Erinnerungen, die auch kommen, wenn die App nicht geöffnet wird.
/// Der Verbrauch nach Plan ist vorhersehbar – deshalb plant die App bei jedem Öffnen
/// und Speichern den ganzen Kalender der nächsten Wochen im Voraus:
///  • am Anfordern-Tag „Rezept anfordern“
///  • danach alle 3 Tage nachfassen, solange nichts als angefragt markiert ist
///  • 3 Tage vor Ende „Vorrat geht zu Ende“
///  • bei angefragten Medikamenten 3 Tage vor Ende „Packung schon da?“
/// Pro Tag höchstens EINE Mitteilung, die alle fälligen Medikamente zusammenfasst.
/// Ist an einem Anfordern-Tag die Gesundheitskarte im Quartal dieses Tages noch nicht
/// eingelesen, steht ein Hinweis dazu in der Mitteilung.
enum Notifications {
    static let prefix = "mv_day_"
    private static let legacyPrefix = "order_"

    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Fragt nur, wenn noch nie gefragt wurde (erstes Medikament angelegt)
    static func requestIfNeeded() async -> Bool {
        switch await status() {
        case .notDetermined: return await requestPermission()
        case .denied: return false
        default: return true
        }
    }

    private enum Kind: Int, Comparable {
        case checkDelivery = 0, followUp, order, low
        static func < (a: Kind, b: Kind) -> Bool { a.rawValue < b.rawValue }
    }

    static func reschedule(items: [MedItem], settings: AppSettings) {
        let hour = settings.reminderHour
        let center = UNUserNotificationCenter.current()
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        let todayAt = cal.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
        // Erster planbarer Tag: heute, wenn die Erinnerungsstunde noch kommt, sonst morgen
        let firstDay = todayAt > now ? today : (cal.date(byAdding: .day, value: 1, to: today) ?? today)
        func plus(_ d: Date, _ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: d) ?? d }

        // Tag → (Medikament → dringendste Art)
        var plan: [Date: [String: Kind]] = [:]
        func add(_ day: Date, _ kind: Kind, _ name: String) {
            var d = cal.startOfDay(for: day)
            if d < firstDay { d = firstDay }
            let current = plan[d]?[name]
            if current == nil || kind > current! { plan[d, default: [:]][name] = kind }
        }

        for item in items {
            let f = item.forecast
            let name = item.med.displayName
            guard let orderBy = f.orderBy, let until = f.until else { continue }
            let lowDay = plus(until, -3)
            switch f.status {
            case .orderNow, .soon, .ok:
                add(orderBy, .order, name)
                var d = plus(max(cal.startOfDay(for: orderBy), firstDay), 3)
                while d < lowDay {
                    add(d, .followUp, name)
                    d = plus(d, 3)
                }
                if lowDay > cal.startOfDay(for: orderBy) { add(lowDay, .low, name) }
            case .ordered:
                if lowDay >= firstDay { add(lowDay, .checkDelivery, name) }
            default:
                continue
            }
        }

        var requests: [UNNotificationRequest] = []
        // iOS erlaubt 64 geplante Mitteilungen pro App
        for (day, meds) in plan.sorted(by: { $0.key < $1.key }).prefix(60) {
            let names = { (k: Kind) in meds.filter { $0.value == k }.map(\.key).sorted() }
            let low = names(.low), order = names(.order) + names(.followUp), check = names(.checkDelivery)

            let content = UNMutableNotificationContent()
            if !low.isEmpty { content.title = "Vorrat geht zu Ende" }
            else if !order.isEmpty { content.title = "Rezept anfordern" }
            else { content.title = "Packung schon da?" }

            var lines: [String] = []
            if !low.isEmpty { lines.append("\(list(low)) \(low.count == 1 ? "reicht" : "reichen") nur noch etwa 3 Tage.") }
            if !order.isEmpty { lines.append("\(list(order)): jetzt Folgerezept anfordern.") }
            if !check.isEmpty { lines.append("\(list(check)): Rezept angefragt – Packung schon eingebucht?") }
            if !(low + order).isEmpty && InsuranceCard.needsReading(on: day, settings: settings) {
                lines.append("Gesundheitskarte im \(InsuranceCard.quarterLabel(day)) noch nicht eingelesen.")
            }
            content.body = lines.joined(separator: "\n")
            content.sound = .default
            content.badge = NSNumber(value: low.count + order.count)

            guard let fire = cal.date(bySettingHour: hour, minute: 0, second: 0, of: day) else { continue }
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let id = prefix + String(Int(day.timeIntervalSince1970))
            requests.append(UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            ))
        }

        let toAdd = requests
        let wanted = Set(toAdd.map(\.identifier))
        center.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter {
                ($0.hasPrefix(prefix) || $0.hasPrefix(legacyPrefix)) && !wanted.contains($0)
            }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            for r in toAdd { center.add(r) }   // gleiche Kennung ersetzt die alte Fassung
        }

        // App-Symbol zeigt, wie viele Rezepte jetzt fällig sind
        let dueNow = items.filter { $0.forecast.status == .orderNow }.count
        center.setBadgeCount(dueNow)
    }

    private static func list(_ names: [String]) -> String {
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        default: return names.dropLast().joined(separator: ", ") + " und " + names.last!
        }
    }
}
