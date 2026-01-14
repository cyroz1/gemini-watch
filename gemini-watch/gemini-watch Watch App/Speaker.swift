import Foundation
import AVFoundation
import Combine

@MainActor
class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()
    
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    @Published var currentMessageId: UUID? = nil
    
    override init() {
        super.init()
        synthesizer.delegate = self
        
        // Configure audio session for playback even in silent mode context
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func speak(text: String, messageId: UUID) {
        if isSpeaking {
            let previousId = currentMessageId
            stop()
            // If tapping the same message, satisfy the toggle behavior (just stop)
            if previousId == messageId {
                return
            }
        }
        
        // Clean markdown for speech
        let cleanText = cleanMarkdownKey(text)
        
        let utterance = AVSpeechUtterance(string: cleanText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        currentMessageId = messageId
        isSpeaking = true
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
    
    // Helper to remove basic markdown for cleaner speech
    private func cleanMarkdownKey(_ text: String) -> String {
        var clean = text
        // Remove bold/italics markers
        clean = clean.replacingOccurrences(of: "**", with: "")
        clean = clean.replacingOccurrences(of: "*", with: "")
        clean = clean.replacingOccurrences(of: "`", with: " code ") // Indicate code slightly
        // Remove LaTeX delimiters
        clean = clean.replacingOccurrences(of: "$$", with: "")
        clean = clean.replacingOccurrences(of: "$", with: "")
        // Remove links [text](url) -> text
        // (Regex would be better but this is a simple pass)
        
        // Remove Emojis (prevent reading them as "Sparkles", "Rocket", etc.)
        clean = clean.unicodeScalars
            .filter { !$0.properties.isEmojiPresentation }
            .map(String.init)
            .joined()
            
        return clean
    }
}
