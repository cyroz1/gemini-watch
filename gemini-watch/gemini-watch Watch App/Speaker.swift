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
    
    func speak(text: String, messageId: UUID) {
        let settings = PersistenceManager.shared.loadSettings()
        
        if isSpeaking {
            let previousId = currentMessageId
            stop()
            if previousId == messageId { return }
        }
        
        let cleanText = cleanMarkdown(text)
        
        let utterance = AVSpeechUtterance(string: cleanText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = settings.speechRate
        
        currentMessageId = messageId
        isSpeaking = true
        
        if settings.hapticsEnabled {
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
        
        // Remove emojis
        clean = clean.unicodeScalars
            .filter { !$0.properties.isEmojiPresentation }
            .map(String.init)
            .joined()
        
        return clean
    }
}
