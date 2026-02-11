# Gemini Watch

A standalone Apple Watch application that brings the power of Google's Gemini AI to your wrist, optimized for 40mm screens.

## Features

- **Conversation History** — All chats are saved and browsable from a conversation list, with swipe-to-delete.
- **Chat Interface** — Interact with Gemini directly from your Apple Watch with real-time streaming responses.
- **Message Editing** — Long-press on any user message to edit it and regenerate the response.
- **Quick Replies** — Contextual suggestion chips ("Explain more", "Summarize", "Give an example") appear after each response.
- **Voice Input** — Tap the microphone button to dictate messages.
- **Settings** — Configure AI model (dynamically fetched from your API key), speech rate, haptics, and quick replies.
- **Markdown & LaTeX** — Renders code blocks, bold/italic, and math expressions (`$` inline, `$$` block).
- **Text-to-Speech** — Tap on any Gemini response to hear it spoken aloud with configurable speed.
- **Double Tap Support** — Use the system Double Tap gesture to quickly open the input.
- **40mm Optimized** — Compact layout with tight spacing and small fonts designed for smaller watch screens.

## Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/cyroz1/gemini-watch.git
   ```

2. **Open in Xcode**:
   Double-click `gemini-watch.xcodeproj` to open the project.

3. **Configure API Key**:
   - Create a file named `Secrets.plist` in the `gemini-watch Watch App` group.
   - Add a key `GEMINI_API_KEY` with your Google Gemini API key as the value.
   - See `Secrets.plist.example` for the expected format.

4. **Run**:
   Select the "gemini-watch Watch App" target and a Watch Simulator (or connected device) and press Run (Cmd+R).

## Requirements

- Xcode 16+
- watchOS 11+
- A Google Cloud Project with the Gemini API enabled.

## Architecture

| File | Purpose |
|---|---|
| `gemini_watchApp.swift` | App entry point — launches `ConversationListView` |
| `ConversationListView.swift` | Browsable list of saved conversations with swipe-to-delete |
| `ContentView.swift` | Main chat UI with input bar, suggestions, and voice input |
| `ChatViewModel.swift` | Message management, streaming orchestration, auto-persistence |
| `GeminiService.swift` | Gemini API client — streaming chat and model listing |
| `MessageView.swift` | Individual message bubble with markdown rendering and TTS |
| `MarkdownParser.swift` | Robust parser for code blocks, inline/block math, and text |
| `Models.swift` | `Message`, `Conversation`, and `AppSettings` data types |
| `PersistenceManager.swift` | UserDefaults-based storage for conversations and settings |
| `SettingsView.swift` | Settings UI — model picker, speech rate, toggles |
| `Speaker.swift` | Text-to-speech via AVSpeechSynthesizer |
