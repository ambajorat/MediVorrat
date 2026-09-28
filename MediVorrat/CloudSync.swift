import Foundation

/// iCloud-Abgleich über den iCloud-Key-Value-Speicher.
/// Der ganze Stand liegt als ein JSON-Wert unter einem Schlüssel (Grenze 1 MB – reicht weit).
/// Konfliktregel: der zuletzt geänderte Stand gewinnt (modifiedAt im Snapshot).
@MainActor
final class CloudSync {
    static let shared = CloudSync()

    private let kv = NSUbiquitousKeyValueStore.default
    private let key = "mv_snapshot_v1"
    private let enabledKey = "mv_icloud_sync"
    private var observer: NSObjectProtocol?

    /// Wird mit den Cloud-Daten aufgerufen, wenn ein anderes Gerät etwas geändert hat
    var onRemoteChange: ((Data) -> Void)?

    /// Geräteweite Einstellung (bewusst nicht mitsynchronisiert)
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    var isAccountAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil }

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kv,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isEnabled, let data = self.kv.data(forKey: self.key) else { return }
                self.onRemoteChange?(data)
            }
        }
        kv.synchronize()
    }

    func remoteData() -> Data? {
        kv.synchronize()
        return kv.data(forKey: key)
    }

    func push(_ data: Data) {
        guard isEnabled else { return }
        kv.set(data, forKey: key)
        kv.synchronize()
    }
}
