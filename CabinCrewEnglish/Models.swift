import Foundation

struct VocabItem: Identifiable, Codable, Hashable {
    let id: String
    let term: String
    let translation: String
    let definition: String
    let example: String
    let exampleTranslation: String
    let unitID: String
}

struct CourseUnit: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let level: String
    let symbol: String
    let items: [VocabItem]
}

struct WordProgress: Codable {
    var box: Int = 0
    var dueAt: Date = .distantPast
    var correct: Int = 0
    var mistakes: Int = 0
}

struct SavedProgress: Codable {
    var xp: Int = 0
    var lessonsCompleted: Int = 0
    var wordsPractised: Int = 0
    var streak: Int = 0
    var lastStudyDate: Date?
    var words: [String: WordProgress] = [:]
}


struct GeneratedExercise: Identifiable, Codable, Hashable {
    let id: String
    let type: String
    let prompt: String
    let options: [String]
    let correctAnswer: String
    let explanation: String
    let relatedTerm: String
}

struct GeneratedLessonPack: Identifiable, Codable, Hashable {
    let id: String
    let unit: CourseUnit
    let exercises: [GeneratedExercise]
    let createdAt: Date
}
