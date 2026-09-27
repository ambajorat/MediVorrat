import SwiftUI
import VisionKit

/// Packung scannen und in den Vorrat einbuchen.
/// Erste Packung einer Sorte: Medikament + Stückzahl zuordnen (Stückzahl per Texterkennung vorgeschlagen).
/// Danach erkennt die App die Packung am Code und bucht mit einem Tipp ein.
struct PackScanView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Aus einem Medikament heraus geöffnet: neue Packungen gehen direkt an dieses Medikament
    let medicationID: UUID?

    init(medicationID: UUID? = nil) {
        self.medicationID = medicationID
    }

    private var fixedMed: Medication? {
        guard let medicationID else { return nil }
        return store.medications.first { $0.id == medicationID }
    }

    private enum Phase: Equatable {
        case scanning
        case known(PackCode)
        case duplicate(PackCode)
        case unknown(PackCode)
    }

    @State private var phase: Phase = .scanning
    @State private var lastRaw: Set<String> = []
    @State private var ocrPackSize: Int?
    @State private var selectedMed: UUID?
    @State private var packSizeInput: Int?
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?
    @FocusState private var sizeFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    VStack(spacing: 0) {
                        PackScannerRepresentable(onBarcodes: handleBarcodes, onTexts: handleTexts)
                            .frame(maxHeight: .infinity)
                            .overlay(alignment: .top) { toastView }
                        panel
                            .frame(maxWidth: .infinity)
                            .background(Color.pageBg)
                    }
                } else {
                    ContentUnavailableView {
                        Label("Scannen nicht möglich", systemImage: "camera.fill")
                    } description: {
                        Text("Die Kamera ist nicht verfügbar. Prüfe in den iPhone-Einstellungen unter MediVorrat, ob der Kamerazugriff erlaubt ist.")
                    }
                    .background(Color.pageBg)
                }
            }
            .navigationTitle(fixedMed.map { "Packung: \($0.name)" } ?? "Packung scannen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
                if sizeFocused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Fertig") { sizeFocused = false }
                    }
                }
            }
        }
        .tint(Color.accent)
    }

    // MARK: Panel

    @ViewBuilder
    private var panel: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch phase {
            case .scanning:
                Label(fixedMed.map { "Packung von \($0.name) in die Kamera halten" } ?? "Halte den Code der Packung in die Kamera", systemImage: "viewfinder")
                    .font(.subheadline.weight(.semibold))
                Text("Am besten den quadratischen DataMatrix-Code. Dann erkennt die App auch, ob diese Packung schon eingebucht ist.")
                    .font(.caption)
                    .foregroundStyle(Color.subtleText)

            case .known(let code):
                if let known = store.knownPack(code) {
                    header(known.med.displayName, detail: "Packung à \(known.entry.packSize) Stück, \(code.label)")
                    Button {
                        book(code, medID: known.med.id, size: known.entry.packSize)
                    } label: {
                        Label("Einbuchen (+\(known.entry.packSize))", systemImage: "shippingbox")
                    }
                    .buttonStyle(LargeButtonStyle())
                    if let fixed = fixedMed, fixed.id != known.med.id {
                        Button("Stattdessen \(fixed.name) zuordnen") { startAssign(code) }
                            .font(.subheadline)
                    } else {
                        Button("Anders zuordnen") { startAssign(code) }
                            .font(.subheadline)
                    }
                }

            case .duplicate(let code):
                header("Schon eingebucht", detail: "Genau diese Packung (\(code.label)) hast du bereits eingebucht.")
                Button("Weiter scannen") { resetScan() }
                    .buttonStyle(LargeButtonStyle())
                if let known = store.knownPack(code) {
                    Button("Trotzdem einbuchen") {
                        book(code, medID: known.med.id, size: known.entry.packSize)
                    }
                    .font(.subheadline)
                }

            case .unknown(let code):
                header("Neue Packung", detail: "\(code.label). Einmal zuordnen, danach erkennt die App sie selbst.")
                if store.medications.isEmpty {
                    Text("Leg zuerst ein Medikament an.")
                        .foregroundStyle(Color.subtleText)
                } else {
                    Picker("Medikament", selection: $selectedMed) {
                        Text("Bitte wählen").tag(UUID?.none)
                        ForEach(store.medications) { m in
                            Text(m.displayName).tag(UUID?.some(m.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .background(Color.cardBg, in: .rect(cornerRadius: 10))

                    HStack {
                        Text("Stück pro Packung")
                        Spacer()
                        TextField("z. B. 100", value: $packSizeInput, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($sizeFocused)
                            .frame(width: 100)
                    }
                    .padding(12)
                    .background(Color.cardBg, in: .rect(cornerRadius: 10))
                    if let n = ocrPackSize, n == packSizeInput {
                        Text("Stückzahl von der Packung gelesen, bitte prüfen.")
                            .font(.caption)
                            .foregroundStyle(Color.subtleText)
                    }

                    Button {
                        if let id = selectedMed, let size = packSizeInput, size > 0 {
                            book(code, medID: id, size: size)
                        }
                    } label: {
                        Label("Zuordnen und einbuchen", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(LargeButtonStyle())
                    .disabled(selectedMed == nil || (packSizeInput ?? 0) <= 0)

                    Button("Nur zuordnen, Bestand nicht ändern") {
                        if let id = selectedMed, let size = packSizeInput, size > 0 {
                            store.assignPack(code, medicationID: id, packSize: size)
                            let name = store.medications.first(where: { $0.id == id })?.name ?? "Packung"
                            showToast("\(name): Packung zugeordnet")
                            resetScan(keepSeen: true)
                        }
                    }
                    .font(.subheadline)
                    .disabled(selectedMed == nil || (packSizeInput ?? 0) <= 0)
                }
                Button("Abbrechen") { resetScan() }
                    .font(.subheadline)
            }
        }
        .padding(20)
    }

    private func header(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 20, weight: .bold, design: .serif))
            Text(detail).font(.caption).foregroundStyle(Color.subtleText)
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Label(toast, systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.cardBg, in: Capsule())
                .overlay(Capsule().stroke(Color.pillBorder, lineWidth: 0.5))
                .padding(.top, 12)
                .transition(.opacity)
        }
    }

    // MARK: Logik

    private func handleBarcodes(_ payloads: [String]) {
        let set = Set(payloads)
        guard !set.isEmpty, set != lastRaw else { return }
        let fresh = set.subtracting(lastRaw)
        lastRaw = set
        guard !fresh.isEmpty else { return }

        // DataMatrix mit Seriennummer bevorzugen, dann PZN, dann Rest
        let codes = fresh.map(PackCode.parse)
        guard let code = codes.first(where: { $0.serial != nil })
                ?? codes.first(where: { $0.pzn != nil })
                ?? codes.first else { return }

        switch phase {
        case .scanning:
            evaluate(code)
        case .known(let current), .unknown(let current):
            // Gleiche Packung, jetzt mit Seriennummer: präziser übernehmen
            if current.key == code.key, current.serial == nil, code.serial != nil {
                evaluate(code)
            }
        case .duplicate:
            break
        }
    }

    private func evaluate(_ code: PackCode) {
        if store.isAlreadyBooked(code) {
            phase = .duplicate(code)
        } else if store.knownPack(code) != nil {
            phase = .known(code)
        } else {
            startAssign(code)
        }
    }

    private func startAssign(_ code: PackCode) {
        let known = store.knownPack(code)
        selectedMed = medicationID ?? known?.med.id ?? store.medications.first(where: { m in
            !store.packCatalog.values.contains { $0.medicationID == m.id }
        })?.id ?? store.medications.first?.id
        let medPack = store.medications.first(where: { $0.id == selectedMed })?.packSize
        let knownSize = known?.med.id == selectedMed ? known?.entry.packSize : nil
        packSizeInput = knownSize ?? ocrPackSize ?? medPack
        phase = .unknown(code)
    }

    private func handleTexts(_ texts: [String]) {
        if let n = PackCode.packSize(in: texts) {
            ocrPackSize = n
            if case .unknown = phase, packSizeInput == nil { packSizeInput = n }
        }
    }

    private func book(_ code: PackCode, medID: UUID, size: Int) {
        store.bookPack(code, medicationID: medID, packSize: size)
        let name = store.medications.first(where: { $0.id == medID })?.name ?? "Packung"
        showToast("\(name): +\(size) eingebucht")
        resetScan(keepSeen: true)
    }

    /// keepSeen: die gerade gescannten Codes nicht sofort erneut auswerten –
    /// eine neue Packung (andere Seriennummer) wird trotzdem erkannt.
    private func resetScan(keepSeen: Bool = false) {
        phase = .scanning
        ocrPackSize = nil
        packSizeInput = nil
        sizeFocused = false
        if !keepSeen { lastRaw = [] }
    }

    private func showToast(_ text: String) {
        toastTask?.cancel()
        withAnimation { toast = text }
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation { toast = nil }
        }
    }
}

// MARK: - DataScannerViewController-Brücke (Muster aus Blase & Darm)

private struct PackScannerRepresentable: UIViewControllerRepresentable {
    let onBarcodes: ([String]) -> Void
    let onTexts: ([String]) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.dataMatrix, .code39, .code128, .ean13]),
                .text()
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        if !vc.isScanning {
            try? vc.startScanning()
        }
    }

    static func dismantleUIViewController(_ vc: DataScannerViewController, coordinator: Coordinator) {
        if vc.isScanning { vc.stopScanning() }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodes: onBarcodes, onTexts: onTexts)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onBarcodes: ([String]) -> Void
        let onTexts: ([String]) -> Void
        private var debounceTask: Task<Void, Never>?

        init(onBarcodes: @escaping ([String]) -> Void, onTexts: @escaping ([String]) -> Void) {
            self.onBarcodes = onBarcodes
            self.onTexts = onTexts
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            processItems(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didUpdate updatedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            processItems(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didRemove removedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            processItems(allItems)
        }

        private func processItems(_ items: [RecognizedItem]) {
            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }

                var codes: [String] = []
                var texts: [String] = []
                for item in items {
                    switch item {
                    case .barcode(let barcode):
                        if let value = barcode.payloadStringValue, !value.isEmpty {
                            codes.append(value)
                        }
                    case .text(let text):
                        texts.append(text.transcript)
                    @unknown default:
                        break
                    }
                }
                self.onBarcodes(codes)
                self.onTexts(texts)
            }
        }
    }
}
