import Foundation
import Security

// Stores the provider key in iOS Keychain rather than UserDefaults.
enum APIKeychain {
    private static let service = "com.asdfghhub.CabinCrewEnglish"
    private static let account = "openai-compatible-api-key"

    static func load() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { return "" }
        return value
    }

    static func save(_ value: String) throws {
        let data = Data(value.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw APIExerciseGenerationError.keychain(status)
        }
    }
}

enum APIExerciseGenerationError: LocalizedError {
    case missingAPIKey
    case missingModel
    case invalidURL
    case http(Int, String)
    case emptyResponse
    case invalidJSON(String)
    case invalidContent(String)
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Сначала укажи API-ключ в настройках API."
        case .missingModel:
            return "Укажи ID модели из панели своего API-провайдера."
        case .invalidURL:
            return "Некорректный адрес API. Например: https://router.cheap/v1"
        case .http(let code, let message):
            return "API вернул HTTP \(code): \(message)"
        case .emptyResponse:
            return "Модель вернула пустой ответ. Попробуй ещё раз или выбери другую модель."
        case .invalidJSON(let detail):
            return "Не удалось разобрать JSON от модели: \(detail)"
        case .invalidContent(let detail):
            return "Ответ модели не прошёл проверку: \(detail)"
        case .keychain(let status):
            return "Не удалось сохранить API-ключ в Keychain (код \(status))."
        }
    }
}

struct AIExerciseGenerator {
    private struct ChatRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    private struct ModelListResponse: Decodable {
        struct Model: Decodable { let id: String }
        let data: [Model]
    }

    private struct BatchPayload: Decodable {
        struct Item: Decodable {
            let term: String
            let translation: String
            let definition: String
            let example: String
            let exampleTranslation: String
        }
        struct Exercise: Decodable {
            let type: String
            let prompt: String
            let options: [String]
            let correctAnswer: String
            let explanation: String
            let relatedTerm: String
        }
        struct Lesson: Decodable {
            let title: String
            let subtitle: String
            let symbol: String
            let items: [Item]
            let exercises: [Exercise]
        }
        let lessons: [Lesson]
    }

    /// Generates one or several complete lessons in a single paid API request.
    func generateLessons(topic: String, level: String, count: Int, lessonCount: Int,
                         baseURL: String, model: String, apiKey: String,
                         existingTerms: [String]) async throws -> [GeneratedLessonPack] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelID = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw APIExerciseGenerationError.missingAPIKey }
        guard !modelID.isEmpty else { throw APIExerciseGenerationError.missingModel }

        let endpoint = try makeEndpoint(baseURL, path: "chat/completions")
        let safeCount = min(max(count, 6), 12)
        let safeLessonCount = min(max(lessonCount, 1), 5)
        let known = existingTerms.prefix(260).joined(separator: ", ")

        let systemPrompt = """
        You are an expert English-for-cabin-crew course author. Create original language-learning material for cabin crew students. Do not teach, invent, or replace real airline operating procedures, safety commands, emergency checklists, medical instructions, or regulatory requirements. If a topic touches safety or first aid, test only ordinary vocabulary and comprehension of non-operational phrases, and explicitly avoid procedural guidance. Use natural international aviation English, suitable for the requested CEFR level. Never claim an expression is officially mandated phraseology.
        Return only valid JSON. No Markdown fences, no commentary, no extra keys. Every multiple-choice exercise must have exactly four distinct options and correctAnswer must exactly match one option.
        """

        let userPrompt = """
        Generate exactly \(safeLessonCount) DIFFERENT fresh Cabin Crew English lessons in one response.
        Overall topic or course direction: \(topic)
        CEFR level: \(level)
        Each lesson must have exactly \(safeCount) vocabulary cards and exactly \(safeCount) multiple-choice exercises.
        Lessons must cover distinct subtopics and must not repeat vocabulary or exercises between lessons.
        Avoid exact vocabulary duplicates from this existing library: \(known)

        Output only this JSON shape:
        {
          "lessons": [
            {
              "title": "Short lesson title in Russian",
              "subtitle": "One-sentence description in Russian",
              "symbol": "airplane",
              "items": [
                {"term":"English word or phrase","translation":"Russian translation","definition":"Short definition in simple English","example":"Natural English example sentence","exampleTranslation":"Russian translation of the example"}
              ],
              "exercises": [
                {"type":"choose_translation","prompt":"Question in Russian or English","options":["option 1","option 2","option 3","option 4"],"correctAnswer":"option 1","explanation":"Short explanation in Russian","relatedTerm":"English phrase from this lesson's items"}
              ]
            }
          ]
        }
        Use a mix of exercise types: choose_translation, choose_phrase, complete_sentence, and choose_response. All tasks must be solvable using that lesson's vocabulary and language context. Keep examples realistic for cabin crew communication. Avoid repeating the same correct answer pattern. Each exercise's relatedTerm must exactly match a term from the same lesson's items. Generate exactly \(safeLessonCount) lessons; do not merge lessons or return a single lesson when several were requested.
        """

        let scaledTokens = safeLessonCount * safeCount * 300
        let body = ChatRequest(
            model: modelID,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            temperature: 0.65,
            max_tokens: min(max(3600, scaledTokens), 15000)
        )
        let data = try await post(body, endpoint: endpoint, key: key)
        let content = try decodeContent(data)
        let jsonString = extractJSONObject(from: content)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw APIExerciseGenerationError.invalidJSON("ответ не является UTF-8 JSON")
        }

        let payload: BatchPayload
        do {
            payload = try JSONDecoder().decode(BatchPayload.self, from: jsonData)
        } catch {
            throw APIExerciseGenerationError.invalidJSON("проверь выбранную модель; JSON должен содержать массив lessons")
        }
        guard payload.lessons.count >= safeLessonCount else {
            throw APIExerciseGenerationError.invalidContent("запрошено уроков: \(safeLessonCount), получено: \(payload.lessons.count)")
        }

        var knownTerms = Set(existingTerms.map { normalize($0) })
        var packs: [GeneratedLessonPack] = []

        for lesson in payload.lessons.prefix(safeLessonCount) {
            var seenTerms = Set<String>()
            let validItems = lesson.items.filter { item in
                let term = item.term.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalized = normalize(term)
                guard !term.isEmpty,
                      !item.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !item.example.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !knownTerms.contains(normalized),
                      !seenTerms.contains(normalized) else { return false }
                seenTerms.insert(normalized)
                return true
            }
            guard validItems.count >= 5 else {
                throw APIExerciseGenerationError.invalidContent("в одном из уроков получено меньше пяти уникальных слов")
            }

            let unitID = "ai-\(UUID().uuidString)"
            let safeSymbol = allowedSymbols.contains(lesson.symbol) ? lesson.symbol : "sparkles"
            let items = validItems.prefix(safeCount).map { item in
                VocabItem(
                    id: "\(unitID)-\(UUID().uuidString)",
                    term: item.term.trimmingCharacters(in: .whitespacesAndNewlines),
                    translation: item.translation.trimmingCharacters(in: .whitespacesAndNewlines),
                    definition: item.definition.trimmingCharacters(in: .whitespacesAndNewlines),
                    example: item.example.trimmingCharacters(in: .whitespacesAndNewlines),
                    exampleTranslation: item.exampleTranslation.trimmingCharacters(in: .whitespacesAndNewlines),
                    unitID: unitID
                )
            }
            let normalizedTerms = Set(items.map { normalize($0.term) })
            let exercises = lesson.exercises.compactMap { exercise -> GeneratedExercise? in
                var options: [String] = []
                for option in exercise.options.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !option.isEmpty {
                    if !options.contains(option) { options.append(option) }
                }
                let answer = exercise.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
                let relatedTerm = exercise.relatedTerm.trimmingCharacters(in: .whitespacesAndNewlines)
                let prompt = exercise.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                guard options.count == 4,
                      options.contains(answer),
                      normalizedTerms.contains(normalize(relatedTerm)),
                      !prompt.isEmpty else { return nil }
                return GeneratedExercise(
                    id: UUID().uuidString,
                    type: allowedExerciseTypes.contains(exercise.type) ? exercise.type : "choose_translation",
                    prompt: prompt,
                    options: options,
                    correctAnswer: answer,
                    explanation: exercise.explanation.trimmingCharacters(in: .whitespacesAndNewlines),
                    relatedTerm: relatedTerm
                )
            }
            guard exercises.count >= 5 else {
                throw APIExerciseGenerationError.invalidContent("в одном из уроков получено меньше пяти корректных упражнений")
            }

            let unit = CourseUnit(
                id: unitID,
                title: lesson.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Новый AI-урок" : lesson.title,
                subtitle: lesson.subtitle,
                level: level,
                symbol: safeSymbol,
                items: items
            )
            packs.append(GeneratedLessonPack(id: unitID, unit: unit, exercises: exercises, createdAt: Date()))
            knownTerms.formUnion(normalizedTerms)
        }

        return packs
    }

    func fetchModels(baseURL: String, apiKey: String) async throws -> [String] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw APIExerciseGenerationError.missingAPIKey }
        let url = try makeEndpoint(baseURL, path: "models")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, data: data)
        do {
            let decoded = try JSONDecoder().decode(ModelListResponse.self, from: data)
            return Array(Set(decoded.data.map(\.id))).sorted()
        } catch {
            throw APIExerciseGenerationError.invalidJSON("провайдер вернул неожиданный список моделей")
        }
    }

    func testConnection(baseURL: String, model: String, apiKey: String) async throws {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelID = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw APIExerciseGenerationError.missingAPIKey }
        guard !modelID.isEmpty else { throw APIExerciseGenerationError.missingModel }
        let body = ChatRequest(
            model: modelID,
            messages: [
                .init(role: "system", content: "Reply briefly."),
                .init(role: "user", content: "Reply with OK.")
            ],
            temperature: 0,
            max_tokens: 8
        )
        let data = try await post(body, endpoint: makeEndpoint(baseURL, path: "chat/completions"), key: key)
        _ = try decodeContent(data)
    }

    private let allowedSymbols: Set<String> = ["airplane", "airplane.departure", "airplane.arrival", "bell.fill", "cup.and.saucer.fill", "person.2.fill", "briefcase.fill", "heart.text.square.fill", "bubble.left.and.bubble.right.fill", "sparkles"]
    private let allowedExerciseTypes: Set<String> = ["choose_translation", "choose_phrase", "complete_sentence", "choose_response"]

    private func post(_ body: ChatRequest, endpoint: URL, key: String) async throws -> Data {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response, data: data)
        return data
    }

    private func validateHTTP(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw APIExerciseGenerationError.emptyResponse }
        guard (200...299).contains(http.statusCode) else {
            throw APIExerciseGenerationError.http(http.statusCode, extractProviderError(from: data))
        }
    }

    private func decodeContent(_ data: Data) throws -> String {
        let completion: ChatResponse
        do {
            completion = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            throw APIExerciseGenerationError.invalidJSON("неожиданный формат ответа Chat Completions")
        }
        guard let content = completion.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw APIExerciseGenerationError.emptyResponse
        }
        return content
    }

    private func makeEndpoint(_ base: String, path: String) throws -> URL {
        var value = base.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") { value.removeLast() }
        guard !value.isEmpty else { throw APIExerciseGenerationError.invalidURL }
        value = value.replacingOccurrences(of: "/chat/completions", with: "")
        value = value.replacingOccurrences(of: "/models", with: "")
        if value.hasSuffix("/v1") { value += "/\(path)" }
        else { value += "/v1/\(path)" }
        guard let url = URL(string: value), url.scheme != nil, url.host != nil else { throw APIExerciseGenerationError.invalidURL }
        return url
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func extractJSONObject(from source: String) -> String {
        let cleaned = source.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = cleaned.firstIndex(of: "{"), let last = cleaned.lastIndex(of: "}"), first <= last else { return cleaned }
        return String(cleaned[first...last])
    }

    private func extractProviderError(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = object["error"] as? [String: Any],
           let message = error["message"] as? String {
            return String(message.prefix(700))
        }
        if let text = String(data: data, encoding: .utf8) { return String(text.prefix(700)) }
        return "неизвестная ошибка провайдера"
    }
}
