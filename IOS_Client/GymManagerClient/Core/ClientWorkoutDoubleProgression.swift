import Foundation

enum ClientWorkoutDoubleProgression {
    struct SetPerformance: Equatable, Sendable {
        let repetitions: Int?
        let loadKg: Double?
        let rir: Double?
    }
    enum Decision: String, Equatable, Sendable { case collectEvidence, maintain, suggestIncrease }

    /// A suggestion only. Never changes prescription/logs or manufactures an increment in kilograms.
    static func decide(prescription: ClientPersonalExercise, performed: [SetPerformance]) -> Decision {
        guard let range = ClientWorkoutRepRange(prescription.repetitions), prescription.sets > 0,
              performed.count == prescription.sets, prescription.effortTarget.hasPrefix("RIR "),
              let target = Double(prescription.effortTarget.dropFirst(4)), (1...4).contains(target) else { return .collectEvidence }
        var loads: [Double] = []
        var achieved = true
        for set in performed {
            guard let reps = set.repetitions, (1...100).contains(reps), let load = set.loadKg, load.isFinite, load > 0,
                  let rir = set.rir, rir.isFinite, (0...10).contains(rir) else { return .collectEvidence }
            if reps < range.upper || rir < target { achieved = false }
            loads.append(load)
        }
        guard achieved, let first = loads.first, loads.allSatisfy({ abs($0 - first) < 0.001 }) else { return .maintain }
        return .suggestIncrease
    }
}
