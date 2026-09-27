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

/// Liest Medikamente und protokollierte Einnahmen aus Apple Health (ab iOS 26).
/// Medikamente nutzen Per-Object-Autorisierung – NIE über requestAuthorization(toShare:read:)
/// anfragen, das wirft eine ObjC-Exception und beendet die App.
@MainActor
final class HealthSync {
    static let shared = HealthSync()
    private let healthStore = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Zeigt das System-Blatt, in dem man die freizugebenden Medikamente auswählt.
    /// Die Einnahmen der freigegebenen Medikamente sind automatisch mit freigegeben.
    func requestAccess() async throws {
        try await healthStore.requestPerObjectReadAuthorization(
            for: HKObjectType.userAnnotatedMedicationType(),
            predicate: nil
        )
    }

    private func annotatedMedications() async throws -> [HKUserAnnotatedMedication] {
        let descriptor = HKUserAnnotatedMedicationQueryDescriptor(predicate: nil, limit: nil)
        return try await descriptor.result(for: healthStore)
    }

    func medications() async throws -> [HealthMedication] {
        try await annotatedMedications().map {
            HealthMedication(name: $0.medication.displayText, nickname: $0.nickname, isArchived: $0.isArchived)
        }
    }

    /// Alle als „genommen“ protokollierten Einnahmen seit `start`.
    func takenDoses(since start: Date) async throws -> [HealthDose] {
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
