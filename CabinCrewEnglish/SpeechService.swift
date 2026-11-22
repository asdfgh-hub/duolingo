import AVFoundation

@MainActor
final class SpeechService {
    static let shared = SpeechService()
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        speakSequence([text])
    }

    /// Speaks English-only feedback in order, without cutting the first utterance off.
    func speakSequence(_ texts: [String]) {
        synthesizer.stopSpeaking(at: .immediate)
        let voiceID = UserDefaults.standard.string(forKey: "cabinCrewEnglish.voice") ?? "en-GB"

        var spoken = Set<String>()
        for text in texts {
            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = cleaned.lowercased()
            guard Self.isEnglishText(cleaned), spoken.insert(normalized).inserted else { continue }
            let utterance = AVSpeechUtterance(string: cleaned)
            utterance.voice = AVSpeechSynthesisVoice(language: voiceID)
            utterance.rate = 0.47
            synthesizer.speak(utterance)
        }
    }

    static func isEnglishText(_ text: String) -> Bool {
        let hasLatin = text.range(of: "[A-Za-z]", options: .regularExpression) != nil
        let hasCyrillic = text.range(of: "[А-Яа-яЁё]", options: .regularExpression) != nil
        return hasLatin && !hasCyrillic
    }
}
