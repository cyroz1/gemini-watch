import SwiftUI

struct MessageView: View {
    let message: Message
    @StateObject private var speaker = Speaker.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // MARK: - Markdown Content
            // We split content by code blocks ```
            let parts = parseMarkdown(message.text)
            
            ForEach(parts.indices, id: \.self) { index in
                let part = parts[index]
                if part.isCode {
                    Text(part.text)
                        .font(.system(.caption2, design: .monospaced))
                        .padding(6)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(LocalizedStringKey(part.text))
                        .font(.caption) // Dynamic Type
                }
            }
            
            // MARK: - TTS Indicator
            // Only show for model messages that are currently speaking
            if message.role == .model && speaker.currentMessageId == message.id && speaker.isSpeaking {
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .symbolEffect(.variableColor.iterative.reversing)
                    Text("Speaking...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(message.role == .user ? Color.blue.opacity(0.3) : Color.gray.opacity(0.15)))
        // Tap to Speak logic
        .onTapGesture {
            if message.role == .model {
                speaker.speak(text: message.text, messageId: message.id)
            }
        }
        .animation(.default, value: speaker.currentMessageId)
    }
    
    // MARK: - Markdown Parser
    struct ContentPart {
        let text: String
        let isCode: Bool
    }
    
    func parseMarkdown(_ text: String) -> [ContentPart] {
        // Simple splitter for ```code blocks```
        // Note: This matches ```...``` pairs.
        var parts: [ContentPart] = []
        let components = text.components(separatedBy: "```")
        
        for (index, component) in components.enumerated() {
            if component.isEmpty { continue }
            
            // Even indices are text, Odd indices are code
            // Example: "Text" [0] ``` "Code" [1] ``` "Text" [2]
            if index % 2 == 0 {
                parts.append(ContentPart(text: component.trimmingCharacters(in: .newlines), isCode: false))
            } else {
                parts.append(ContentPart(text: component.trimmingCharacters(in: .newlines), isCode: true))
            }
        }
        return parts
    }
}
