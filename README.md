# Gemini Watch — Google Gemini AI Chat for Apple Watch (watchOS)

**Gemini Watch is a free, open-source Apple Watch app that brings Google Gemini AI chat to your wrist.** Stream conversations with Gemini directly from watchOS — no iPhone companion app, no tethering, no subscriptions. Built natively in SwiftUI and optimized for 40mm and 41mm Apple Watch screens.

![Platform: watchOS 11+](https://img.shields.io/badge/platform-watchOS%2011%2B-black?logo=apple)
![Language: Swift](https://img.shields.io/badge/language-Swift-orange?logo=swift)
![UI: SwiftUI](https://img.shields.io/badge/ui-SwiftUI-blue?logo=swift)
![License: MIT](https://img.shields.io/badge/license-MIT-green)
![Xcode 16+](https://img.shields.io/badge/Xcode-16%2B-1575F9?logo=xcode)

> **Keywords:** Apple Watch Gemini app · Google Gemini watchOS client · AI chat on Apple Watch · standalone watchOS AI assistant · SwiftUI Gemini API · streaming LLM Apple Watch.

---

## Table of Contents

- [Why Gemini Watch?](#why-gemini-watch)
- [Features](#features)
- [Screenshots](#screenshots)
- [Requirements](#requirements)
- [Installation & Setup](#installation--setup)
- [Getting a Google Gemini API Key](#getting-a-google-gemini-api-key)
- [Usage Guide](#usage-guide)
- [Architecture](#architecture)
- [Privacy & Data Handling](#privacy--data-handling)
- [FAQ](#faq)
- [Contributing](#contributing)
- [License](#license)

---

## Why Gemini Watch?

Most AI assistants on Apple Watch are thin mirrors of an iPhone app — they require your phone nearby, re-route requests through a companion, or don't support streaming. **Gemini Watch runs entirely on watchOS**: it calls the Google Gemini API directly over Wi-Fi or cellular, streams tokens as they arrive, and stores every conversation locally on the watch.

If you're looking for a **native Apple Watch Gemini client**, a **lightweight LLM chat app for watchOS**, or a **SwiftUI reference implementation of the Gemini streaming API**, this project is for you.

---

## Features

- **Real-time Streaming Chat** — Tokens appear as Gemini generates them, with an animated typing cursor. Built on Server-Sent Events (SSE) from the Gemini streaming endpoint.
- **Full Conversation History** — Every chat is saved as an individual JSON file on the watch and browsable from a scrollable list. Swipe any conversation to delete it; pin important chats to the top.
- **Message Editing & Regeneration** — Long-press any user message to edit it and regenerate Gemini's reply from that point.
- **Web Search Grounding** — Enable Gemini's `google_search` tool from Settings to get grounded answers with inline citations and source links.
- **Context-Aware Quick Replies** — Smart suggestion chips appear after each response, tailored to the content (code, lists, follow-up questions, or general conversation). Toggleable from Settings.
- **Markdown & LaTeX Rendering** — Code blocks with language labels, bold and italic text, inline math (`$…$`) and block math (`$$…$$`), powered by a pre-compiled regex parser with result caching for smooth scrolling.
- **Text-to-Speech** — Tap any Gemini response to hear it spoken aloud via `AVSpeechSynthesizer`, with a Slow / Normal / Fast speech-rate slider.
- **Adjustable Creativity (Temperature)** — A Precise → Balanced → Creative → Wild slider maps directly to the Gemini `temperature` parameter (0.0–1.0), with a one-tap reset to the default.
- **Haptic Feedback** — Optional haptics on key interactions; toggleable in Settings.
- **Double Tap Gesture Support** — Use the watchOS Double Tap gesture (Apple Watch Series 9, 10, and Ultra 2) to open the input field instantly.
- **Customizable System Prompt** — Edit Gemini's persona, tone, and instructions right from the in-app Settings screen, with a reset-to-default button.
- **Live Model Picker** — Switch between available Gemini models (e.g., `gemini-2.5-flash`, `gemini-2.5-pro`). The list is fetched live from the Gemini API and filtered to text-capable models.
- **Clear All Chats** — One-tap bulk delete with a confirmation dialog in the Settings "Danger Zone".
- **40mm / 41mm Optimized** — Compact typography, tight spacing, and carefully tuned tap targets designed for the smallest Apple Watch screens.
- **100% On-Device Storage** — Conversations never leave your watch except when sent to the Gemini API itself.

---

## Screenshots

<!-- Add screenshots here: chat view, conversation list, settings, streaming in progress -->
<!-- Example: ![Gemini Watch chat view on Apple Watch](docs/screenshot-chat.png) -->

*Screenshots coming soon. PRs with simulator captures welcome — see [Contributing](#contributing).*

---

## Requirements

| Requirement | Version |
|---|---|
| **Xcode** | 16 or later |
| **watchOS deployment target** | 11.0+ |
| **Apple Watch hardware** | Series 6 or later recommended |
| **Google Cloud / AI Studio account** | Required for a Gemini API key |
| **Network** | Wi-Fi or LTE on the watch for standalone use |

---

## Installation & Setup

### 1. Clone the repository

```bash
git clone https://github.com/cyroz1/gemini-watch.git
cd gemini-watch
```

### 2. Open the project in Xcode

```bash
open gemini-watch/gemini-watch.xcodeproj
```

### 3. Add your Gemini API key

Create a `Secrets.plist` file inside the **`gemini-watch Watch App`** group:

1. In Xcode: **File → New → File → Property List**.
2. Name it `Secrets.plist` and add it to the `gemini-watch Watch App` target.
3. Add a key `GEMINI_API_KEY` (type: `String`) and paste your API key as the value.

See `Secrets.plist.example` for the exact format.

> **Never commit `Secrets.plist`.** It is already listed in `.gitignore`.

### 4. Build and run

1. Select the **gemini-watch Watch App** scheme.
2. Choose an Apple Watch Simulator (or a paired physical device).
3. Press **⌘R** to build and run.

---

## Getting a Google Gemini API Key

1. Visit [Google AI Studio](https://aistudio.google.com/app/apikey).
2. Sign in with your Google account.
3. Click **Create API key** and copy the generated key.
4. Paste it into `Secrets.plist` as described above.

The free tier is sufficient for personal use. Check [Google's Gemini API pricing](https://ai.google.dev/pricing) for rate limits and paid tiers.

---

## Usage Guide

### Chat basics

- **Start a new chat** — Tap the compose button from the conversation list.
- **Send a message** — Tap the input field, dictate or scribble, and press send.
- **Regenerate a reply** — Long-press any of your own messages, edit, and resend.
- **Hear a reply aloud** — Tap any Gemini message to trigger text-to-speech.
- **Delete a conversation** — Swipe left on it in the conversation list.

### Settings

Open **Settings** from the conversation list to configure:

| Setting | What it does |
|---|---|
| **AI Model** | Picker of Gemini models your API key can access (e.g. `gemini-2.5-flash`, `gemini-2.5-pro`). Fetched live from the API. |
| **Speech → Speed** | Text-to-speech rate — Slow, Normal, or Fast. |
| **Creativity** | Maps to the Gemini `temperature` parameter (0.0–1.0). Labels: Precise, Balanced, Creative, Wild. Includes a **Reset to Default** button (0.7). |
| **Haptics** | Toggle haptic feedback on interactions. |
| **Quick Replies** | Toggle the context-aware suggestion chips that appear after each response. |
| **Web Search** | Toggle grounded answers with citations via Gemini's `google_search` tool. |
| **System Prompt** | Multiline editor for the assistant's persona and instructions. Includes a **Reset to Default** button. |
| **Clear All Chats** | Danger-zone action with a confirmation dialog — permanently deletes every saved conversation from the watch. |

---

## Architecture

Gemini Watch follows a lean MVVM architecture built entirely in SwiftUI. There is no Core Data, no Combine-heavy plumbing, and no third-party dependencies — just `URLSession`, `FileManager`, and `AVFoundation`.

| File | Purpose |
|---|---|
| `gemini_watchApp.swift` | App entry point — launches `ConversationListView`. |
| `ConversationListView.swift` | Browsable conversation list with swipe-to-delete. |
| `ContentView.swift` | Main chat UI — input bar, messages, suggestion chips. |
| `ChatViewModel.swift` | Message state, streaming orchestration, auto-persistence, debounced UI updates. |
| `GeminiService.swift` | Gemini API client — streaming SSE chat and model listing. |
| `MessageView.swift` | Message bubble with markdown rendering, streaming cursor, and TTS trigger. |
| `MarkdownParser.swift` | Pre-compiled regex parser for code blocks, math, and inline styling; result-cached. |
| `Models.swift` | `Message`, `Conversation`, and `AppSettings` data types. |
| `PersistenceManager.swift` | File-based storage (one JSON file per conversation) with UserDefaults migration. |
| `SettingsView.swift` | Model picker, speech rate, haptics, quick replies, system prompt editor. |
| `Speaker.swift` | Text-to-speech wrapper around `AVSpeechSynthesizer`. |
| `AppSettingsStore.swift` | Observable store for user preferences. |
| `Branding.swift` | Shared colors, gradients, and typography tokens. |

### Data flow

```
User input → ChatViewModel → GeminiService (streaming SSE)
                    ↓                       ↓
           PersistenceManager        MessageView (token-by-token UI)
                    ↓
          One JSON file per chat
```

---

## Privacy & Data Handling

- **Conversations are stored locally** on the Apple Watch as JSON files in the app's sandboxed container.
- **Messages are transmitted only to the Google Gemini API** over HTTPS when you send a request.
- **No analytics, telemetry, or third-party SDKs** are bundled.
- **Your API key stays on the device** in `Secrets.plist`, embedded in the app bundle at build time.

Review [Google's Gemini API data usage policy](https://ai.google.dev/gemini-api/terms) to understand how Google handles prompts and responses on their side.

---

## FAQ

### Does Gemini Watch require an iPhone?

No. Gemini Watch is a **standalone watchOS app**. As long as your Apple Watch has a network connection (Wi-Fi or cellular), it can talk to Gemini without an iPhone nearby.

### Is Gemini Watch free?

Yes — the app is MIT-licensed and free. You only pay Google for any API usage above their free Gemini tier.

### Which Apple Watch models are supported?

Any Apple Watch running **watchOS 11 or later**. The layout is tuned for 40mm and 41mm cases but scales up to 44mm, 45mm, 49mm (Ultra), and 42mm/46mm Series 10.

### Can I use a different model, like `gemini-2.5-pro`?

Yes. Open **Settings → Model** to pick from any model your API key has access to. The list is fetched live from the Gemini API.

### Does it support images, voice input, or vision?

The current release focuses on text chat with text-to-speech output. Voice input uses the standard watchOS dictation / Scribble input methods. Vision and multimodal support are on the roadmap.

### Does Gemini Watch support web search?

Yes. Flip the **Web Search** toggle in Settings to enable Gemini's `google_search` grounding tool. Responses that use web results include inline citations with source URLs.

### Can I tune how creative the responses are?

Yes. The **Creativity** slider in Settings maps directly to the Gemini `temperature` parameter from 0.0 (Precise) to 1.0 (Wild). Tap **Reset to Default** to return to 0.7.

### How do I back up my conversations?

Conversations live in the app's sandbox on the watch. They'll be included in encrypted iCloud backups of your paired iPhone if you have that enabled.

### Does it work offline?

The UI and your saved history work offline, but sending new messages requires a network connection to reach the Gemini API.

### Is this an official Google product?

No. Gemini Watch is an **unofficial, community-built** open-source client. "Gemini" and "Google" are trademarks of Google LLC.

---

## Contributing

Contributions, bug reports, and feature requests are welcome. Please open an issue or submit a pull request on [GitHub](https://github.com/cyroz1/gemini-watch).

Good first contributions:

- Screenshots from different Apple Watch sizes.
- Localization into additional languages.
- Accessibility improvements (VoiceOver labels, Dynamic Type audit).
- Complications and Smart Stack widgets.

---

## License

Released under the [MIT License](LICENSE). Copyright © 2026 cyroz.

---

## Related Topics

`apple-watch` · `watchos` · `gemini` · `gemini-api` · `google-gemini` · `ai-chat` · `llm` · `swiftui` · `swift` · `chatbot` · `streaming` · `sse` · `on-device` · `open-source`
