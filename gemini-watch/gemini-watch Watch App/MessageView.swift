import SwiftUI

struct MessageView: View {
    let message: Message
    let settings: AppSettings
    let isStreaming: Bool

    // Use @ObservedObject — Speaker.shared is a singleton we don't own
    @ObservedObject private var speaker = Speaker.shared

    init(message: Message, settings: AppSettings, isStreaming: Bool = false) {
        self.message = message
        self.settings = settings
        self.isStreaming = isStreaming
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // MARK: - Markdown Content
            let parts = MarkdownParser.shared.parse(message.text)

            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                switch part.type {
                case .code(let language):
                    VStack(alignment: .leading, spacing: 0) {
                        if let language = language, !language.isEmpty {
                            Text(language.uppercased())
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 1)
                        }
                        Text(part.text)
                            .font(.system(size: 9, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(5)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(5)

                case .blockMath:
                    Text(part.text)
                        .font(.system(size: 10, design: .serif))
                        .italic()
                        .padding(3)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)

                case .inlineMath:
                    Text(part.text)
                        .font(.system(size: 10, design: .serif))
                        .italic()
                        .padding(.horizontal, 2)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(2)

                case .text:
                    Text(LocalizedStringKey(part.text))
                        .font(.system(size: 12))
                }
            }

            // MARK: - Streaming Cursor
            if isStreaming {
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: 5, height: 5)
                        .symbolEffect(.pulse)
                    Circle()
                        .fill(Color.blue.opacity(0.5))
                        .frame(width: 5, height: 5)
                        .symbolEffect(.pulse)
                        .animation(.easeInOut.delay(0.15), value: isStreaming)
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 5, height: 5)
                        .symbolEffect(.pulse)
                        .animation(.easeInOut.delay(0.3), value: isStreaming)
                }
                .padding(.top, 2)
            }

            // MARK: - TTS Indicator
            if message.role == .model && speaker.currentMessageId == message.id && speaker.isSpeaking {
                HStack(spacing: 3) {
                    Image(systemName: "waveform")
                        .font(.system(size: 8))
                        .symbolEffect(.variableColor.iterative.reversing)
                    Text("Speaking…")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(6)
        .frame(maxWidth: message.role == .model ? .infinity : nil, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(message.role == .user ? Color.blue.opacity(0.3) : Color.gray.opacity(0.15))
        )
        // Tap to speak — passes settings so Speaker doesn't re-load from disk
        .onTapGesture {
            if message.role == .model {
                speaker.speak(
                    text: message.text,
                    messageId: message.id,
                    rate: settings.speechRate,
                    hapticsEnabled: settings.hapticsEnabled
                )
            }
        }
        .animation(.default, value: speaker.currentMessageId)
    }
}
