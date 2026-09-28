import Foundation

enum AppInfo {
    /// Apple-ID aus App Store Connect (Zahl hinter „id“), sobald MediVorrat angelegt ist.
    /// Solange nil, sind „App bewerten“ und „App empfehlen“ ausgeblendet.
    static let appStoreID: String? = nil

    static var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    static var storeURL: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/de/app/id\($0)") }
    }

    /// Direkt ins Bewertungsformular – requestReview ist von Apple gedrosselt
    static var reviewURL: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }

    static let blogURL = URL(string: "https://ploetzlich-querschnitt.de")!
    static let bdmWebURL = URL(string: "https://blaseunddarm.de")!
    static let bdmStoreURL = URL(string: "https://apps.apple.com/de/app/blase-darm-manager/id6792282103")!
}
