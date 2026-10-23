import Foundation

enum ClientWorkoutCoachRules {
    static let version = "coach-workout-2.0.0"
    struct Blueprint: Sendable {
        let name: String
        let muscles: Set<ClientMuscleRegion>
        let patterns: [ClientMovementPattern]
        let weekday: Int
    }
    static let upper: Set<ClientMuscleRegion> = [.chest, .upperBack, .lats, .shoulders, .biceps, .triceps]
    static let lower: Set<ClientMuscleRegion> = [.quadriceps, .hamstrings, .glutes, .calves, .core]

    static func strategy(_ profile: ClientTrainingProfile) -> ClientWorkoutStrategy {
        switch profile.splitPreference {
        case .fullBody: return .fullBody
        case .upperLower: return .upperLower
        case .pushPullLegs: return .pushPullLegs
        case .custom: return .custom
        case .automatic:
            if profile.weeklyFrequency <= 3 {
                return profile.weeklyFrequency == 3 && profile.experience != .beginner
                    && profile.sessionDurationMinutes >= 75 && !profile.priorityMuscles.isEmpty ? .hybrid : .fullBody
            }
            if profile.weeklyFrequency == 4 {
                return profile.sessionDurationMinutes >= 75 && profile.experience == .advanced
                    && profile.priorityMuscles.count >= 2 && profile.goal == .hypertrophy ? .hybrid : .upperLower
            }
            if profile.weeklyFrequency == 5 { return .hybrid }
            return .pushPullLegs
        }
    }
    static func blueprints(_ profile: ClientTrainingProfile, strategy: ClientWorkoutStrategy) -> [Blueprint] {
        let days: [Int]
        switch profile.weeklyFrequency {
        case 2: days = [1, 4]
        case 3: days = [1, 3, 5]
        case 4: days = [1, 2, 4, 5]
        case 5: days = [1, 2, 3, 5, 6]
        default: days = [1, 2, 3, 4, 5, 6]
        }
        let u: (String, Set<ClientMuscleRegion>, [ClientMovementPattern]) = ("Upper", upper, [.horizontalPush, .horizontalPull, .verticalPull, .verticalPush, .elbowFlexion, .elbowExtension])
        let l: (String, Set<ClientMuscleRegion>, [ClientMovementPattern]) = ("Lower", lower, [.kneeDominant, .hipHinge, .calves, .core, .unilateralLower])
        let p: (String, Set<ClientMuscleRegion>, [ClientMovementPattern]) = ("Push", [.chest, .shoulders, .triceps], [.horizontalPush, .verticalPush, .elbowExtension, .horizontalPush])
        let r: (String, Set<ClientMuscleRegion>, [ClientMovementPattern]) = ("Pull", [.lats, .upperBack, .biceps], [.horizontalPull, .verticalPull, .elbowFlexion, .horizontalPull])
        let a: (String, Set<ClientMuscleRegion>, [ClientMovementPattern]) = ("Full Body", ClientMuscleRegion.majorGroups, [.kneeDominant, .horizontalPush, .horizontalPull, .core, .calves, .hipHinge])
        let b: (String, Set<ClientMuscleRegion>, [ClientMovementPattern]) = ("Full Body", ClientMuscleRegion.majorGroups, [.hipHinge, .horizontalPush, .verticalPull, .calves, .core, .verticalPush])
        let templates: [(String, Set<ClientMuscleRegion>, [ClientMovementPattern])]
        switch strategy {
        case .fullBody: templates = [a, b]
        case .upperLower: templates = [u, l]
        case .pushPullLegs: templates = [p, r, l]
        case .hybrid:
            if profile.weeklyFrequency == 3 { templates = [u, l, a] }
            else if profile.weeklyFrequency == 4 {
                templates = [("Torso", [.chest, .lats, .upperBack, .shoulders], u.2),
                             ("Arti", lower.union([.biceps, .triceps]), [.kneeDominant, .hipHinge, .calves, .elbowFlexion, .elbowExtension, .core])]
            } else { templates = [p, r, l, u, l] }
        case .custom:
            return days.enumerated().map { index, day in
                let groups = Set(profile.customSplitGroups[index])
                return Blueprint(name: "Giorno \(index + 1)", muscles: groups,
                    patterns: patterns(for: groups), weekday: day)
            }
        }
        var names: [String: Int] = [:]
        return days.enumerated().map { index, day in
            let value = templates[index % templates.count]
            names[value.0, default: 0] += 1
            return Blueprint(name: "\(value.0) \(names[value.0] ?? 1)", muscles: value.1, patterns: value.2, weekday: day)
        }
    }
    static func patterns(for muscles: Set<ClientMuscleRegion>) -> [ClientMovementPattern] {
        let pairs: [(ClientMuscleRegion, ClientMovementPattern)] = [(.chest,.horizontalPush),(.upperBack,.horizontalPull),(.lats,.verticalPull),(.quadriceps,.kneeDominant),(.hamstrings,.hipHinge),(.glutes,.hipHinge),(.shoulders,.verticalPush),(.biceps,.elbowFlexion),(.triceps,.elbowExtension),(.calves,.calves),(.core,.core)]
        return pairs.filter { muscles.contains($0.0) }.map(\.1).reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
    }
    static func exerciseCount(_ minutes: Int) -> Int { minutes <= 30 ? 4 : minutes <= 60 ? 5 : 6 }
    static func exerciseCount(_ profile: ClientTrainingProfile) -> Int {
        min(exerciseCount(profile.sessionDurationMinutes), profile.experience == .beginner ? 5 : 6)
    }
    static func minutes(_ exercises: [ClientPersonalExercise]) -> Int {
        // Conservative estimate:5min preparation,45s work/set,actual between-set rest,75s transition/exercise.
        guard exercises.count <= 100, exercises.allSatisfy({ (0...100).contains($0.sets) && (0...3_600).contains($0.restSeconds) }) else { return Int.max }
        let seconds = 300 + exercises.reduce(0) { $0 + $1.sets * 45 + max(0, $1.sets - 1) * $1.restSeconds + 75 }
        return Int(ceil(Double(seconds) / 60))
    }
    static func minimumVolume(_ profile: ClientTrainingProfile) -> Double {
        profile.sessionDurationMinutes == 30 ? 2 : profile.experience == .beginner ? 3 : 5
    }
    static func target(_ muscle: ClientMuscleRegion, _ profile: ClientTrainingProfile) -> Double {
        let base: Double = profile.sessionDurationMinutes == 30 ? 4 : profile.experience == .beginner ? 6 : 10
        let phaseAdjustment: Double = profile.nutritionPhase == .cut ? -1
            : profile.nutritionPhase == .bulk && profile.experience != .beginner && profile.sessionDurationMinutes >= 60 ? 1 : 0
        return max(3, base + phaseAdjustment) + (profile.priorityMuscles.contains(muscle) ? 2 : 0)
    }
    static func maximum(_ muscle: ClientMuscleRegion, _ profile: ClientTrainingProfile) -> Double {
        profile.priorityMuscles.contains(muscle) ? 24 : 22
    }
    static func fingerprint(_ text: String) -> String {
        // Stable non-security fingerprint; never used for auth, tamper detection or IDs.
        let value = text.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        return String(value, radix: 16)
    }
    static func programSignature(_ plan: ClientPersonalWorkoutPlan) -> String {
        fingerprint(plan.sessions.map { day in
            "\(day.name)|\(day.weekday ?? 0)|" + day.exercises.map {
                "\($0.catalogExerciseID?.uuidString ?? "missing"):\($0.sets):\($0.repetitions):\($0.restSeconds):\($0.effortTarget)"
            }.joined(separator: "|")
        }.joined(separator: "\n"))
    }
}
