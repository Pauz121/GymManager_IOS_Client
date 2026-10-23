import Foundation

enum ClientNutritionCoachRules {
    static let version = "coach-nutrition-1.0.0"
    static let equation = "mifflin-st-jeor-simplified-1990-v1"
    static let activityVersion = "gymmanager-inherited-activity-v1"
    static let foodReviewVersion = "nutrition-food-review-1"
    static let minimumEnergy = 1400.0
    static let maximumEnergy = 4500.0
    static let dailyEnergyTolerance = 0.10
    static let dailyMacroTolerance = 0.20
    static let mealEnergyTolerance = 0.25
    static let mealProteinTolerance = 0.35
    static let targetAtwaterTolerance = 0.000001

    static func mealShares(_ count: Int) -> [Double] {
        switch count {
        case 3: [0.25, 0.40, 0.35]
        case 4: [0.25, 0.35, 0.10, 0.30]
        case 5: [0.25, 0.10, 0.30, 0.10, 0.25]
        case 6: [0.20, 0.10, 0.25, 0.10, 0.25, 0.10]
        default: []
        }
    }
}

struct ClientNutritionEnergyCalculation: Codable, Equatable, Sendable {
    let equation: String
    let activityVersion: String
    let age: Int
    let biologicalSex: ClientBiologicalSex
    let heightCm: Double
    let weightKg: Double
    let activityEvidence: ClientNutritionActivityEvidence
    let activityCategory: ClientNutritionActivity
    let activityFactor: Double
    let estimatedRMR: Double
    let estimatedMaintenance: Double
    let goal: ClientNutritionPhase
    let goalAdjustment: Double
    let calorieTarget: Double
    let proteinGramsPerKg: Double
    let target: ClientNutritionTarget
}

enum ClientNutritionCoachEnergy {
    static func rmr(age: Int, sex: ClientBiologicalSex, weightKg: Double, heightCm: Double) throws -> Double {
        guard (18...78).contains(age), weightKg.isFinite, (35...120).contains(weightKg),
              heightCm.isFinite, (130...220).contains(heightCm) else {
            throw ClientNutritionGenerationEligibility.invalidAnthropometrics
        }
        return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + (sex == .male ? 5 : -161)
    }

    static func calculate(profile: ClientNutritionCoachProfile, phase: ClientNutritionPhase) throws -> ClientNutritionEnergyCalculation {
        guard let age = profile.age, let sex = profile.biologicalSex, let kg = profile.weightKg,
              let cm = profile.heightCm, let evidence = profile.activity,
              (0...7).contains(evidence.exerciseDaysPerWeek) else { throw ClientNutritionGenerationEligibility.missingRequiredProfile }
        let resting = try rmr(age: age, sex: sex, weightKg: kg, heightCm: cm)
        try checkApplicability(weightKg: kg, heightCm: cm, phase: phase)
        let category = evidence.category
        let maintenance = resting * category.coefficient
        let exercising = evidence.exerciseDaysPerWeek > 0
        let proteinRate = exercising ? (phase == .cut ? 2.0 : phase == .bulk ? 1.8 : 1.6) : 1.0
        let target = try allocate(resting: resting, maintenance: maintenance, weightKg: kg, phase: phase, proteinRate: proteinRate)
        let calories = target.calories
        return ClientNutritionEnergyCalculation(equation: ClientNutritionCoachRules.equation,
            activityVersion: ClientNutritionCoachRules.activityVersion, age: age, biologicalSex: sex,
            heightCm: cm, weightKg: kg, activityEvidence: evidence, activityCategory: category,
            activityFactor: category.coefficient, estimatedRMR: resting, estimatedMaintenance: maintenance,
            goal: phase, goalAdjustment: calories - maintenance, calorieTarget: calories,
            proteinGramsPerKg: proteinRate, target: target)
    }

    static func checkApplicability(weightKg kg: Double, heightCm cm: Double, phase: ClientNutritionPhase) throws {
        let heightAdjustedMass = kg / pow(cm / 100, 2)
        guard (15...40).contains(heightAdjustedMass) else { throw ClientNutritionGenerationEligibility.invalidAnthropometrics }
        // Retain the pre-existing low-relative-weight Cut guard; no disease is inferred.
        guard phase != .cut || heightAdjustedMass >= 18.5 else { throw ClientNutritionGenerationEligibility.energyTargetUnsafe }
    }

    /// Shared numeric allocation. Calling it is not eligibility/authentication evidence.
    static func allocate(resting: Double, maintenance: Double, weightKg: Double,
                         phase: ClientNutritionPhase, proteinRate: Double) throws -> ClientNutritionTarget {
        guard [resting, maintenance, weightKg, proteinRate].allSatisfy({ $0.isFinite && $0 > 0 }),
              (1.0...2.0).contains(proteinRate) else { throw ClientNutritionGenerationEligibility.energyTargetUnsafe }
        let modifier: Double = phase == .cut ? -0.10 : phase == .bulk ? 0.05 : 0
        // Internal RMR/TDEE are unrounded; final kcal target quantized once to inherited10kcal.
        let calories = (maintenance * (1 + modifier) / 10).rounded() * 10
        guard (ClientNutritionCoachRules.minimumEnergy...ClientNutritionCoachRules.maximumEnergy).contains(calories) else {
            throw ClientNutritionGenerationEligibility.energyTargetUnsafe
        }
        let protein = weightKg * proteinRate
        let fat = calories * 0.30 / 9
        let carbs = (calories - protein * 4 - fat * 9) / 4
        let target = ClientNutritionTarget(restingKcal: resting.rounded(), estimatedKcal: maintenance.rounded(),
                                          calories: calories, protein: protein, carbs: carbs, fat: fat)
        guard validMacros(target), protein * 4 / calories <= 0.35 else {
            throw ClientNutritionGenerationEligibility.energyTargetUnsafe
        }
        return target
    }

    static func validMacros(_ value: ClientNutritionTarget) -> Bool {
        guard [value.restingKcal, value.estimatedKcal, value.calories, value.protein, value.carbs, value.fat].allSatisfy({ $0.isFinite && $0 > 0 }),
              (ClientNutritionCoachRules.minimumEnergy...ClientNutritionCoachRules.maximumEnergy).contains(value.calories) else { return false }
        let fatRatio = value.fat * 9 / value.calories
        return (0.20...0.35).contains(fatRatio) &&
            abs(value.protein * 4 + value.carbs * 4 + value.fat * 9 - value.calories) <= ClientNutritionCoachRules.targetAtwaterTolerance
    }
}
