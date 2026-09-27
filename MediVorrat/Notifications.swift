import Foundation
import UserNotifications

enum Notifications {
    static let prefix = "order_"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Pro Medikament genau eine Erinnerung am Anfordern-Tag (oder, wenn überfällig,
    /// zur nächsten Erinnerungsstunde). Wird bei jedem Speichern und App-Start neu gesetzt.
    static func reschedule(items: [MedItem], hour: Int) {
        let center = UNUserNotificationCenter.current()
        var requests: [UNNotificationRequest] = []
        let cal = Calendar.current
        let now = Date()
        for item in items {
            let f = item.forecast
            guard f.status == .orderNow || f.status == .soon || f.status == .ok,
                  let orderBy = f.orderBy, let until = f.until else { continue }

            var fire = cal.date(bySettingHour: hour, minute: 0, second: 0, of: orderBy) ?? orderBy
            if fire <= now {
                let todayAt = cal.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
                fire = todayAt > now ? todayAt : (cal.date(byAdding: .day, value: 1, to: todayAt) ?? todayAt)
            }

            let content = UNMutableNotificationContent()
            content.title = "Rezept anfordern"
            content.body = "\(item.med.displayName) reicht noch bis \(until.shortDay)."
            content.sound = .default

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let request = UNNotificationRequest(
                identifier: prefix + item.med.id.uuidString,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )
            requests.append(request)
        }

        let toAdd = requests
        let wanted = Set(toAdd.map(\.identifier))
        center.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(prefix) && !wanted.contains($0) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            // gleiche Identifier ersetzen bestehende Anfragen
            for r in toAdd { center.add(r) }
        }
    }
}
