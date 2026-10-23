import Foundation

enum ClientExerciseDifficultyPolicy {
    static func allows(_ item: ClientExerciseCatalogItem, for experience: ClientTrainingExperience) -> Bool {
        guard let level = item.effectiveDifficulty else { return false }
        // Intermediate choices are permitted for beginners but ranked below simpler options.
        // Advanced techniques require an advanced profile; manual selection stays explicit.
        return level != .advanced || experience == .advanced
    }

    static func preferenceScore(_ item: ClientExerciseCatalogItem, for experience: ClientTrainingExperience) -> Int {
        guard let level = item.effectiveDifficulty else { return -100 }
        switch (experience, level) {
        case (.beginner, .beginner): return 16
        case (.beginner, .intermediate): return -12
        case (.intermediate, .beginner), (.intermediate, .intermediate): return 8
        case (.advanced, _): return 8 // An advanced user still benefits from simple movements.
        default: return -100
        }
    }
}
