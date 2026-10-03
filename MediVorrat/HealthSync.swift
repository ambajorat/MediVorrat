import Foundation
import HealthKit

struct HealthDose {
    let name: String
    let date: Date
    let quantity: Double
}

struct HealthMedication: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let nickname: String?
    let isArchived: Bool
}

struct HealthNeedsIOS26: LocalizedError {
    var errorDescription: String? { "Medikamente aus Apple Health gibt es ab iOS 26." }
}

/// Liest Medikamente und protokollierte Einnahmen aus Apple Health.
/// Die Medications-API gibt es erst ab iOS 26 – auf älteren Systemen meldet
/// isAvailable false, und die Oberfläche blendet alle Health-Teile aus.
/// Medikamente nutzen Per-Object-Autorisierung – NIE über requestAuthorization(toShare:read:)
/// anfragen, das wirft eine ObjC-Exception und beendet die App.
@MainActor
final class HealthSync {
    static let shared = HealthSync()
    private let healthStore = HKHealthStore()

    var isAvailable: Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        if #available(iOS 26, *) { return true }
        return false
    }

    /// Zeigt das System-Blatt, in dem man die freizugebenden Medikamente auswählt.
    /// Die Einnahmen der freigegebenen Medikamente sind automatisch mit freigegeben.
    func requestAccess() async throws {
        guard #available(iOS 26, *) else { throw HealthNeedsIOS26() }
        try await healthStore.requestPerObjectReadAuthorization(
            for: HKObjectType.userAnnotatedMedicationType(),
            predicate: nil
        )
    }

    func medications() async throws -> [HealthMedication] {
        guard #available(iOS 26, *) else { return [] }
        return try await annotatedMedications().map {
            HealthMedication(name: $0.medication.displayText, nickname: $0.nickname, isArchived: $0.isArchived)
        }
    }

    /// Alle als „genommen“ protokollierten Einnahmen seit `start`.
    func takenDoses(since start: Date) async throws -> [HealthDose] {
        guard #available(iOS 26, *) else { return [] }
        return try await takenDoses26(since: start)
    }

    // MARK: Nur iOS 26

    @available(iOS 26, *)
    private func annotatedMedications() async throws -> [HKUserAnnotatedMedication] {
        let descriptor = HKUserAnnotatedMedicationQueryDescriptor(predicate: nil, limit: nil)
        return try await descriptor.result(for: healthStore)
    }

    @available(iOS 26, *)
    private func takenDoses26(since start: Date) async throws -> [HealthDose] {
        let meds = try await annotatedMedications()
        let datePredicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.sample(type: HKObjectType.medicationDoseEventType(), predicate: datePredicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: nil
        )
        let samples = try await descriptor.result(for: healthStore)

        var result: [HealthDose] = []
        for sample in samples {
            guard let event = sample as? HKMedicationDoseEvent, event.logStatus == .taken else { continue }
            guard let med = meds.first(where: { $0.medication.identifier == event.medicationConceptIdentifier }) else { continue }
            result.append(HealthDose(name: med.medication.displayText,
                                     date: event.startDate,
                                     quantity: event.doseQuantity ?? 1))
        }
        return result
    }
}
