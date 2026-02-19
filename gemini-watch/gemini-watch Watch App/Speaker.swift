import Foundation
import AVFoundation
import Combine
import WatchKit

@MainActor
class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()

    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    @Published var currentMessageId: UUID? = nil

    override init() {
        super.init()
        synthesizer.delegate = self

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    /// Speak the given text. Callers pass settings so Speaker doesn't load from disk on every call.
    func speak(text: String, messageId: UUID, rate: Float, hapticsEnabled: Bool) {
        if isSpeaking {
            let previousId = currentMessageId
            stop()
            if previousId == messageId { return }
        }

        let utterance = AVSpeechUtterance(string: cleanMarkdown(text))
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate

        currentMessageId = messageId
        isSpeaking = true

        if hapticsEnabled {
            WKInterfaceDevice.current().play(.start)
        }

        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        currentMessageId = nil
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.currentMessageId = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.currentMessageId = nil
        }
    }

    // MARK: - Markdown Cleaning

    private func cleanMarkdown(_ text: String) -> String {
        var clean = text
        clean = clean.replacingOccurrences(of: "**", with: "")
        clean = clean.replacingOccurrences(of: "*", with: "")
        clean = clean.replacingOccurrences(of: "`", with: " code ")
        clean = clean.replacingOccurrences(of: "$$", with: "")
        clean = clean.replacingOccurrences(of: "$", with: "")
        clean = clean.unicodeScalars
            .filter { !$0.properties.isEmojiPresentation }
            .map(String.init)
            .joined()
        return clean
    }
}
