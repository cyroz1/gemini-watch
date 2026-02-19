# Gemini Watch

A standalone Apple Watch application that brings Google's Gemini AI to your wrist, optimized for small screens.

## Features

- **Streaming Chat** — Real-time streaming responses with an animated typing cursor while Gemini is generating.
- **Conversation History** — Chats saved as individual JSON files and browsable from a list, with swipe-to-delete.
- **Message Editing** — Long-press any user message to edit it and regenerate the response.
- **Context-Aware Quick Replies** — Suggestion chips appear after each response, tailored to the content (code, lists, questions, or general).
- **Markdown & LaTeX** — Renders code blocks (with language labels), bold/italic text, and math expressions (`$` inline, `$$` block) using a fast pre-compiled regex parser with result caching.
- **Text-to-Speech** — Tap any Gemini response to hear it read aloud at configurable speed.
- **Double Tap Support** — Use the system Double Tap gesture to open the input field.
- **Customizable System Prompt** — Edit the AI's persona and instructions directly from Settings.
- **40mm Optimized** — Compact layout with tight spacing and small fonts designed for smaller watch faces.

## Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/cyroz1/gemini-watch.git
   ```

2. **Open in Xcode**:
   Double-click `gemini-watch.xcodeproj`.

3. **Configure API Key**:
   - Create `Secrets.plist` in the `gemini-watch Watch App` group.
   - Add key `GEMINI_API_KEY` with your Google Gemini API key as the value.
   - See `Secrets.plist.example` for the expected format.

4. **Run**:
   Select the **gemini-watch Watch App** target and a Watch Simulator or connected device, then press **Cmd+R**.

## Requirements

- Xcode 16+
- watchOS 11+
- A Google Cloud Project with the Gemini API enabled

## Architecture

| File | Purpose |
|---|---|
| `gemini_watchApp.swift` | App entry point — launches `ConversationListView` |
| `ConversationListView.swift` | Browsable conversation list with swipe-to-delete |
| `ContentView.swift` | Main chat UI — input bar, messages, suggestion chips |
| `ChatViewModel.swift` | Message management, streaming orchestration, auto-persistence, debounced updates |
| `GeminiService.swift` | Gemini API client — streaming SSE chat and model listing |
| `MessageView.swift` | Message bubble with markdown rendering, streaming cursor, and TTS |
| `MarkdownParser.swift` | Pre-compiled regex parser for code blocks, math, and text; result-cached |
| `Models.swift` | `Message`, `Conversation`, and `AppSettings` data types |
| `PersistenceManager.swift` | File-based storage (one JSON file per conversation) with UserDefaults migration |
| `SettingsView.swift` | Model picker, speech rate, haptics, quick replies, system prompt editor |
| `Speaker.swift` | Text-to-speech via `AVSpeechSynthesizer` |
