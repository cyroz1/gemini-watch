import SwiftUI

struct MessageView: View {
    let message: Message
    @StateObject private var speaker = Speaker.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // MARK: - Markdown Content
            // We parse content hierarchically: Code -> Block Math -> Inline Math
            let parts = parseMarkdown(message.text)
            
            ForEach(parts) { part in
                switch part.type {
                case .code:
                    Text(part.text)
                        .font(.system(.caption2, design: .monospaced))
                        .padding(6)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
    
    enum PartType {
        case text
        case code
        case blockMath
        case inlineMath
    }
    
    struct ContentPart: Identifiable {
        let id = UUID()
        let text: String
        let type: PartType
    }
    
    func parseMarkdown(_ text: String) -> [ContentPart] {
        var results: [ContentPart] = []
        
        // 1. Split by Code Blocks (```)
        let codeComponents = text.components(separatedBy: "```")
        
        for (index, component) in codeComponents.enumerated() {
            if component.isEmpty { continue }
            
            let isCode = index % 2 != 0
            
            if isCode {
                results.append(ContentPart(text: component.trimmingCharacters(in: .newlines), type: .code))
            } else {
                // 2. Process non-code text for Block Math ($$)
                results.append(contentsOf: parseBlockMath(component))
            }
        }
        
        return results
    }
    
    private func parseBlockMath(_ text: String) -> [ContentPart] {
        var results: [ContentPart] = []
        let components = text.components(separatedBy: "$$")
        
        for (index, component) in components.enumerated() {
            if component.isEmpty { continue }
            
            let isBlockMath = index % 2 != 0
            
            if isBlockMath {
                results.append(ContentPart(text: component.trimmingCharacters(in: .whitespacesAndNewlines), type: .blockMath))
            } else {
                // 3. Process remaining text for Inline Math ($)
                results.append(contentsOf: parseInlineMath(component))
            }
        }
        return results
    }
    
    private func parseInlineMath(_ text: String) -> [ContentPart] {
        var results: [ContentPart] = []
        let components = text.components(separatedBy: "$")
        
        for (index, component) in components.enumerated() {
            if component.isEmpty { continue }
            
            let isInlineMath = index % 2 != 0
            
            if isInlineMath {
                results.append(ContentPart(text: component.trimmingCharacters(in: .whitespacesAndNewlines), type: .inlineMath))
            } else {
                results.append(ContentPart(text: component.trimmingCharacters(in: .newlines), type: .text))
            }
        }
        return results
    }
}
