import Foundation
import Combine

@MainActor
final class ProgressStore: ObservableObject {
    @Published private(set) var saved: SavedProgress
    @Published private(set) var generatedPacks: [GeneratedLessonPack]
    private let storageKey = "cabinCrewEnglish.progress.v1"
    private let generatedStorageKey = "cabinCrewEnglish.generatedPacks.v1"

    var allItems: [VocabItem] { VocabularyData.allItems + generatedPacks.flatMap { $0.unit.items } }

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(SavedProgress.self, from: data) {
            saved = decoded
        } else {
            saved = SavedProgress()
        }
        if let data = UserDefaults.standard.data(forKey: generatedStorageKey),
           let decoded = try? JSONDecoder().decode([GeneratedLessonPack].self, from: data) {
            generatedPacks = decoded
        } else {
            generatedPacks = []
        }
    }

    var dueItems: [VocabItem] {
        let now = Date()
        return allItems.filter { item in
            guard let word = saved.words[item.id] else { return false }
            return word.dueAt <= now
        }.sorted { left, right in
            let l = saved.words[left.id]?.dueAt ?? .distantPast
            let r = saved.words[right.id]?.dueAt ?? .distantPast
            return l < r
        }
    }

    func completeLesson(items: [VocabItem], correctIDs: Set<String>) {
        saved.xp += 10 + correctIDs.count * 2
        saved.lessonsCompleted += 1
        saved.wordsPractised += items.count
        updateStreak()
        for item in items {
            updateWord(item.id, correct: correctIDs.contains(item.id))
        }
        persist()
    }

    func addGeneratedPack(_ pack: GeneratedLessonPack) {
        addGeneratedPacks([pack])
    }

    func addGeneratedPacks(_ packs: [GeneratedLessonPack]) {
        guard !packs.isEmpty else { return }
        generatedPacks.insert(contentsOf: packs, at: 0)
        if generatedPacks.count > 100 { generatedPacks = Array(generatedPacks.prefix(100)) }
        persistGeneratedPacks()
    }

    func completeGeneratedLesson(_ pack: GeneratedLessonPack, correctExerciseIDs: Set<String>) {
        let correctTerms = Set(pack.exercises.filter { correctExerciseIDs.contains($0.id) }.map { $0.relatedTerm.lowercased() })
        saved.xp += 10 + correctExerciseIDs.count * 2
        saved.lessonsCompleted += 1
        saved.wordsPractised += pack.unit.items.count
        updateStreak()
        for item in pack.unit.items {
            updateWord(item.id, correct: correctTerms.contains(item.term.lowercased()))
        }
        persist()
    }

    func reviewWord(_ item: VocabItem, knewIt: Bool) {
        updateWord(item.id, correct: knewIt)
        updateStreak()
        saved.xp += knewIt ? 2 : 1
        persist()
    }

    private func updateWord(_ id: String, correct: Bool) {
        var word = saved.words[id] ?? WordProgress()
        if correct {
            word.correct += 1
            word.box = min(word.box + 1, 5)
            let intervals: [Double] = [0, 1, 3, 7, 14, 30]
            word.dueAt = Calendar.current.date(byAdding: .day, value: Int(intervals[word.box]), to: Date()) ?? Date()
        } else {
            word.mistakes += 1
            word.box = 0
            word.dueAt = Calendar.current.date(byAdding: .minute, value: 10, to: Date()) ?? Date()
        }
        saved.words[id] = word
    }

    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let last = saved.lastStudyDate {
            let lastDay = calendar.startOfDay(for: last)
            if lastDay == today { return }
            if calendar.date(byAdding: .day, value: 1, to: lastDay) == today {
                saved.streak += 1
            } else {
                saved.streak = 1
            }
        } else {
            saved.streak = 1
        }
        saved.lastStudyDate = Date()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func persistGeneratedPacks() {
        if let data = try? JSONEncoder().encode(generatedPacks) {
            UserDefaults.standard.set(data, forKey: generatedStorageKey)
        }
    }
}
