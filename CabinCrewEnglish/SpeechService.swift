import AVFoundation

@MainActor
final class SpeechService {
    static let shared = SpeechService()
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: UserDefaults.standard.string(forKey: "cabinCrewEnglish.voice") ?? "en-GB")
        utterance.rate = 0.47
        synthesizer.speak(utterance)
    }
}
