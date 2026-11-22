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
            return "Сначала укажи API-ключ в настройках генератора."
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

    private struct GeneratedPayload: Decodable {
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
        let title: String
        let subtitle: String
        let symbol: String
        let items: [Item]
        let exercises: [Exercise]
    }

    func generate(topic: String, level: String, count: Int, baseURL: String, model: String, apiKey: String, existingTerms: [String]) async throws -> GeneratedLessonPack {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelID = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw APIExerciseGenerationError.missingAPIKey }
        guard !modelID.isEmpty else { throw APIExerciseGenerationError.missingModel }

        let endpoint = try makeEndpoint(baseURL)
        let safeCount = min(max(count, 6), 12)
        let known = existingTerms.prefix(180).joined(separator: ", ")
        let systemPrompt = """
        You are an expert English-for-cabin-crew course author. Create original language-learning material for cabin crew students. Do not teach, invent, or replace real airline operating procedures, safety commands, emergency checklists, medical instructions, or regulatory requirements. If a topic touches safety or first aid, test only ordinary vocabulary and comprehension of non-operational phrases, and explicitly avoid procedural guidance. Use natural international aviation English, suitable for the requested CEFR level. Never claim an expression is officially mandated phraseology.
        Return only valid JSON. No Markdown fences, no commentary, no extra keys. Every multiple-choice exercise must have exactly four distinct options and correctAnswer must exactly match one option.
        """
        let userPrompt = """
        Generate one fresh Cabin Crew English lesson.
        Topic: \(topic)
        CEFR level: \(level)
        Number of vocabulary cards: \(safeCount)
        Number of multiple-choice exercises: \(safeCount)
        Avoid exact vocabulary duplicates from this existing library: \(known)

        Output this exact JSON shape:
        {
          "title": "Short lesson title in Russian",
          "subtitle": "One-sentence description in Russian",
          "symbol": "airplane",
          "items": [
            {"term":"English word or phrase","translation":"Russian translation","definition":"Short meaning in simple English","example":"Natural example sentence","exampleTranslation":"Russian translation of the example"}
          ],
          "exercises": [
            {"type":"choose_translation","prompt":"Question in Russian or English","options":["option 1","option 2","option 3","option 4"],"correctAnswer":"option 1","explanation":"Short explanation in Russian","relatedTerm":"English phrase from items"}
          ]
        }
        Use a mix of exercise types: choose_translation, choose_phrase, complete_sentence, and choose_response. All tasks must be solvable using the lesson vocabulary and language context. Keep examples realistic for cabin crew communication. Avoid repeating the same correct answer pattern. Each exercise's relatedTerm must exactly match a term from items. Generate exactly \(safeCount) items and \(safeCount) exercises.
        """

        let body = ChatRequest(
            model: modelID,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            temperature: 0.65,
            max_tokens: 3600
        )
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIExerciseGenerationError.emptyResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = extractProviderError(from: data)
            throw APIExerciseGenerationError.http(http.statusCode, message)
        }

        let completion: ChatResponse
        do {
            completion = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            throw APIExerciseGenerationError.invalidJSON("неожиданный формат ответа Chat Completions")
        }
        guard let content = completion.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw APIExerciseGenerationError.emptyResponse
        }

        let jsonString = extractJSONObject(from: content)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw APIExerciseGenerationError.invalidJSON("ответ не является UTF-8 JSON")
        }
        let payload: GeneratedPayload
        do {
            payload = try JSONDecoder().decode(GeneratedPayload.self, from: jsonData)
        } catch {
            throw APIExerciseGenerationError.invalidJSON("проверь выбранную модель; поля JSON не совпали со схемой")
        }

        let knownTerms = Set(existingTerms.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
        var seenTerms = Set<String>()
        let validItems = payload.items.filter { item in
            let term = item.term.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = term.lowercased()
            guard !term.isEmpty,
                  !item.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !item.example.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !knownTerms.contains(normalized),
                  !seenTerms.contains(normalized) else { return false }
            seenTerms.insert(normalized)
            return true
        }
        guard validItems.count >= 5 else {
            throw APIExerciseGenerationError.invalidContent("получено слишком мало корректных слов")
        }

        let unitID = "ai-\(UUID().uuidString)"
        let safeSymbol = allowedSymbols.contains(payload.symbol) ? payload.symbol : "sparkles"
        let items = validItems.prefix(safeCount).map { item in
            VocabItem(
                id: "\(unitID)-\(UUID().uuidString)",
                term: item.term.trimmingCharacters(in: .whitespacesAndNewlines),
                translation: item.translation.trimmingCharacters(in: .whitespacesAndNewlines),
                definition: item.definition,
                example: item.example,
                exampleTranslation: item.exampleTranslation,
                unitID: unitID
            )
        }
        let normalizedTerms = Set(items.map { $0.term.lowercased() })
        let exercises = payload.exercises.compactMap { exercise -> GeneratedExercise? in
            var options: [String] = []
            for option in exercise.options.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !option.isEmpty {
                if !options.contains(option) { options.append(option) }
            }
            let answer = exercise.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
            let relatedTerm = exercise.relatedTerm.trimmingCharacters(in: .whitespacesAndNewlines)
            let prompt = exercise.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard options.count == 4,
                  options.contains(answer),
                  normalizedTerms.contains(relatedTerm.lowercased()),
                  !prompt.isEmpty else { return nil }
            return GeneratedExercise(
                id: UUID().uuidString,
                type: allowedExerciseTypes.contains(exercise.type) ? exercise.type : "choose_translation",
                prompt: prompt,
                options: options,
                correctAnswer: answer,
                explanation: exercise.explanation,
                relatedTerm: relatedTerm
            )
        }
        guard exercises.count >= 5 else {
            throw APIExerciseGenerationError.invalidContent("модель создала меньше пяти корректных упражнений")
        }

        let unit = CourseUnit(
            id: unitID,
            title: payload.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Новый AI-урок" : payload.title,
            subtitle: payload.subtitle,
            level: level,
            symbol: safeSymbol,
            items: items
        )
        return GeneratedLessonPack(id: unitID, unit: unit, exercises: exercises, createdAt: Date())
    }

    private let allowedSymbols: Set<String> = ["airplane", "airplane.departure", "airplane.arrival", "bell.fill", "cup.and.saucer.fill", "person.2.fill", "briefcase.fill", "heart.text.square.fill", "bubble.left.and.bubble.right.fill", "sparkles"]
    private let allowedExerciseTypes: Set<String> = ["choose_translation", "choose_phrase", "complete_sentence", "choose_response"]

    private func makeEndpoint(_ base: String) throws -> URL {
        var value = base.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") { value.removeLast() }
        guard !value.isEmpty else { throw APIExerciseGenerationError.invalidURL }
        if value.hasSuffix("/chat/completions") {
            guard let url = URL(string: value), url.scheme != nil, url.host != nil else { throw APIExerciseGenerationError.invalidURL }
            return url
        }
        if value.hasSuffix("/v1") { value += "/chat/completions" }
        else { value += "/v1/chat/completions" }
        guard let url = URL(string: value), url.scheme != nil, url.host != nil else { throw APIExerciseGenerationError.invalidURL }
        return url
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
