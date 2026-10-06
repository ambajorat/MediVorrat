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
    @State private var packSizeText = ""
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var recognizedNames: [String] = []
    @State private var newName = ""
    @State private var newStrength = ""
    @State private var newDoses: Double = 1

    private enum Field { case size, name, strength }
    @FocusState private var focused: Field?

    /// Eintrag im Auswahlmenü für „neues Medikament anlegen“
    private static let newMedTag = UUID(uuidString: "00000000-0000-0000-0000-00000000AE01")!
    private var isNewMed: Bool { selectedMed == Self.newMedTag }
    private var packSizeValue: Int? {
        Int(packSizeText.trimmingCharacters(in: .whitespaces)).flatMap { $0 > 0 ? $0 : nil }
    }
    private var canAssign: Bool {
        guard selectedMed != nil, packSizeValue != nil else { return false }
        return !isNewMed || !newName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    VStack(spacing: 0) {
                        PackScannerRepresentable(onBarcodes: handleBarcodes, onTexts: handleTexts)
                            .frame(maxHeight: .infinity)
                            .overlay(alignment: .top) { toastView }
                        ScrollView {
                            panel.frame(maxWidth: .infinity)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .frame(height: panelHeight)
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
            .navigationTitle(fixedMed.map { m in String(localized: "Packung: \(m.name)") } ?? String(localized: "Packung scannen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
                if focused != nil {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Fertig") { focused = nil }
                            .fontWeight(.semibold)
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
                Label(fixedMed.map { m in String(localized: "Packung von \(m.name) in die Kamera halten") }
                      ?? String(localized: "Halte den Code der Packung in die Kamera"), systemImage: "viewfinder")
                    .font(.subheadline.weight(.semibold))
                Text("Am besten den quadratischen DataMatrix-Code. Dann erkennt die App auch, ob diese Packung schon eingebucht ist.")
                    .font(.caption)
                    .foregroundStyle(Color.subtleText)

            case .known(let code):
                if let known = store.knownPack(code) {
                    let size = known.entry.packSize
                    let label = code.label
                    header(known.med.displayName, detail: String(localized: "Packung à \(size) Stück, \(label)"))
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
                let label = code.label
                header(String(localized: "Schon eingebucht"),
                       detail: String(localized: "Genau diese Packung (\(label)) hast du bereits eingebucht."))
                Button("Weiter scannen") { resetScan() }
                    .buttonStyle(LargeButtonStyle())
                if let known = store.knownPack(code) {
                    Button("Trotzdem einbuchen") {
                        book(code, medID: known.med.id, size: known.entry.packSize)
                    }
                    .font(.subheadline)
                }

            case .unknown(let code):
                let label = code.label
                header(String(localized: "Neue Packung"),
                       detail: String(localized: "\(label). Einmal zuordnen, danach erkennt die App sie selbst."))
                Picker("Medikament", selection: $selectedMed) {
                    ForEach(store.medications) { m in
                        Text(m.displayName).tag(UUID?.some(m.id))
                    }
                    Text("Neues Medikament anlegen …").tag(UUID?.some(Self.newMedTag))
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .background(Color.cardBg, in: .rect(cornerRadius: 10))

                if isNewMed {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Name, z. B. Sotalol", text: $newName)
                            .focused($focused, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focused = .strength }
                        Divider()
                        TextField("Stärke, z. B. 80 mg (optional)", text: $newStrength)
                            .focused($focused, equals: .strength)
                            .submitLabel(.next)
                            .onSubmit { focused = .size }
                        Divider()
                        Stepper(value: $newDoses, in: 0.5...20, step: 0.5) {
                            Text("\(newDoses.pieces) Stück pro Tag")
                        }
                    }
                    .padding(12)
                    .background(Color.cardBg, in: .rect(cornerRadius: 10))

                    if !recognizedNames.isEmpty {
                        Text("Von der Packung gelesen – antippen übernimmt den Namen:")
                            .font(.caption)
                            .foregroundStyle(Color.subtleText)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recognizedNames, id: \.self) { text in
                                    Button(text) { newName = text }
                                        .font(.subheadline)
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(Color.pillBg, in: .rect(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pillBorder, lineWidth: 0.5))
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                HStack {
                    Text("Stück pro Packung")
                    Spacer()
                    TextField("z. B. 100", text: $packSizeText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focused, equals: .size)
                        .frame(width: 100)
                }
                .padding(12)
                .background(Color.cardBg, in: .rect(cornerRadius: 10))
                if let n = ocrPackSize, n == packSizeValue {
                    Text("Stückzahl von der Packung gelesen, bitte prüfen.")
                        .font(.caption)
                        .foregroundStyle(Color.subtleText)
                }

                Button {
                    if let id = resolveMedication(), let size = packSizeValue {
                        book(code, medID: id, size: size)
                    }
                } label: {
                    Label(isNewMed ? String(localized: "Anlegen und einbuchen") : String(localized: "Zuordnen und einbuchen"),
                          systemImage: "checkmark.circle")
                }
                .buttonStyle(LargeButtonStyle())
                .disabled(!canAssign)

                Button(isNewMed ? String(localized: "Nur anlegen, Bestand nicht ändern")
                                : String(localized: "Nur zuordnen, Bestand nicht ändern")) {
                    if let id = resolveMedication(), let size = packSizeValue {
                        store.assignPack(code, medicationID: id, packSize: size)
                        let name = store.medications.first(where: { $0.id == id })?.name ?? String(localized: "Packung")
                        showToast(String(localized: "\(name): Packung zugeordnet"))
                        resetScan(keepSeen: true)
                    }
                }
                .font(.subheadline)
                .disabled(!canAssign)

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
        // Vorauswahl: festes Medikament › bisherige Zuordnung › Medikament ohne bekannte Packung › neu anlegen
        selectedMed = medicationID ?? known?.med.id ?? store.medications.first(where: { m in
            !store.packCatalog.values.contains { $0.medicationID == m.id }
        })?.id ?? Self.newMedTag
        let medPack = store.medications.first(where: { $0.id == selectedMed })?.packSize
        let knownSize = known?.med.id == selectedMed ? known?.entry.packSize : nil
        packSizeText = (knownSize ?? ocrPackSize ?? medPack).map(String.init) ?? ""
        newName = ""
        newStrength = ""
        newDoses = 1
        phase = .unknown(code)
    }

    /// Gewähltes Medikament; bei „neu anlegen“ wird es jetzt erstellt.
    private func resolveMedication() -> UUID? {
        guard let sel = selectedMed else { return nil }
        guard sel == Self.newMedTag else { return sel }
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        let m = Medication(name: name,
                           strength: newStrength.trimmingCharacters(in: .whitespaces),
                           dosesPerDay: newDoses,
                           packSize: packSizeValue)
        store.add([m])
        return m.id
    }

    private func handleTexts(_ texts: [String]) {
        if let n = PackCode.packSize(in: texts) {
            ocrPackSize = n
            if case .unknown = phase, packSizeText.isEmpty { packSizeText = String(n) }
        }
        // Namensvorschläge: Textzeilen mit Buchstaben, ohne reine Mengen-/Zahlenangaben
        let names = texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 && $0.count <= 40 && $0.contains(where: \.isLetter) }
            .filter { PackCode.packSize(in: [$0]) == nil }
        var unique: [String] = []
        for n in names where !unique.contains(n) { unique.append(n) }
        let top = Array(unique.prefix(6))
        if case .unknown = phase, top != recognizedNames { recognizedNames = top }
    }

    private var panelHeight: CGFloat {
        switch phase {
        case .scanning: return 120
        case .known, .duplicate: return 240
        case .unknown: return isNewMed ? 460 : 330
        }
    }

    private func book(_ code: PackCode, medID: UUID, size: Int) {
        store.bookPack(code, medicationID: medID, packSize: size)
        let name = store.medications.first(where: { $0.id == medID })?.name ?? String(localized: "Packung")
        showToast(String(localized: "\(name): +\(size) eingebucht"))
        resetScan(keepSeen: true)
    }

    /// keepSeen: die gerade gescannten Codes nicht sofort erneut auswerten –
    /// eine neue Packung (andere Seriennummer) wird trotzdem erkannt.
    private func resetScan(keepSeen: Bool = false) {
        phase = .scanning
        ocrPackSize = nil
        packSizeText = ""
        recognizedNames = []
        focused = nil
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
