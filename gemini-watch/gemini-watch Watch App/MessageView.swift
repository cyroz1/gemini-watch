import SwiftUI

struct MessageView: View {
    let message: Message
    @StateObject private var speaker = Speaker.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // MARK: - Markdown Content
            // We parse content hierarchically using the robust parser
            let parts = MarkdownParser.shared.parse(message.text)
            
            // Use enumerated() to provide stable identity based on position
            // This prevents full view recreation when text appends
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                switch part.type {
                case .code(let language):
                    VStack(alignment: .leading, spacing: 0) {
                        if let language = language, !language.isEmpty {
                            Text(language.uppercased())
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 2)
                        }
                        
                        Text(part.text)
                            .font(.system(.caption2, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(6)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(6)
                    
                case .blockMath:
                    Text(part.text)
                        .font(.system(.caption2, design: .serif))
                        .italic()
                        .padding(4)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                        
                case .inlineMath:
                    Text(part.text)
                        .font(.system(.caption, design: .serif))
                        .italic()
                        .padding(.horizontal, 2)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(2)
                        
                case .text:
                    // Using LocalizedStringKey allows SwiftUI to parse standard markdown (bold/italic) in text
                    Text(LocalizedStringKey(part.text))
                        .font(.caption)
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
        .frame(maxWidth: message.role == .model ? .infinity : nil, alignment: .leading) // Ensure model messages fill width
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
}
