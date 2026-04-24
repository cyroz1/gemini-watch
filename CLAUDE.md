# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project layout

This is a **standalone watchOS app** (no iPhone companion target). All Swift sources live in `gemini-watch/gemini-watch Watch App/`. The Xcode project is `gemini-watch/gemini-watch.xcodeproj`. The repo root holds only `README.md`, `LICENSE`, and `.gitignore`.

- watchOS deployment target: **11.0**, Swift 5, Xcode **16+**.
- `TARGETED_DEVICE_FAMILY = 4` (Apple Watch only).
- No Swift Package Manager / CocoaPods / Carthage dependencies — everything is built on `URLSession`, `FileManager`, `AVFoundation`, `WatchKit`, `UserNotifications`, and SwiftUI.
- There is no test target. Code-level changes must be validated by building and running in the watchOS simulator.

## Build & run

```bash
open gemini-watch/gemini-watch.xcodeproj
```

Then in Xcode: select the **gemini-watch Watch App** scheme, pick an Apple Watch simulator (or paired device), and ⌘R.

There is no CLI build/lint/test pipeline. To build from the command line you would use `xcodebuild -project gemini-watch/gemini-watch.xcodeproj -scheme "gemini-watch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build`, but the canonical workflow is Xcode.

### API key setup (required to run)

Create `gemini-watch/gemini-watch Watch App/Secrets.plist` with a `GEMINI_API_KEY` string entry. See `Secrets.plist.example` for the format. **`Secrets.plist` is gitignored — never commit it.** `GeminiService.init()` reads this plist at launch; missing or empty values surface as `GeminiError.missingAPIKey` rather than crashing.

## Architecture

Lean MVVM in SwiftUI. The data flow is:

```
View (ContentView) → ChatViewModel → GeminiService (actor, SSE stream)
                          ↓                ↓
                  PersistenceManager   StreamEvent (.text | .sources)
                          ↓
                One JSON file per chat in Documents/conversations/
```

Key invariants and non-obvious conventions are captured below — these are the rules to preserve when changing code.

### Settings flow (do not bypass)

`AppSettingsStore` is the single source of truth for `AppSettings` at runtime. It is created once in `gemini_watchApp` and injected as an `@EnvironmentObject` everywhere. Disk I/O is debounced (300 ms) inside the store.

- **Views and services must read settings from the injected store**, never call `PersistenceManager.shared.loadSettings()` ad hoc. `ChatViewModel.configure(settingsStore:)` wires this up from `ContentView.onAppear`; `Speaker.speak(...)` takes settings as parameters for the same reason.
- `AppSettings` has a hand-written `init(from decoder:)` that tolerates missing `webSearchEnabled` (older persisted settings). Adding new fields requires the same decode-if-present pattern.

### Gemini streaming (`GeminiService`)

`GeminiService` is an **actor** that talks directly to `https://generativelanguage.googleapis.com/v1beta/models/...:streamGenerateContent?alt=sse` and returns an `AsyncThrowingStream<StreamEvent, Error>`.

- Outgoing context is **strictly alternated user↔model**, capped at the last 20 messages. Leading model messages are stripped and consecutive same-role messages are collapsed (last one wins). Don't relax this — Gemini rejects non-alternating histories.
- `StreamEvent` has two cases: `.text(String)` chunks and `.sources([GroundingSource])`. Grounding sources arrive in later SSE chunks; consumers must accept either at any time and let later sources supersede earlier ones.
- HTTP error mapping is centralized in `streamGenerateContent` (429 → "Rate limited.", 401/403 → "API key invalid.", 5xx → "Server error.", timeout → "Request timed out."). Extend this `switch` rather than throwing raw errors at the UI.
- `listModels()` filters to `models/gemini-*` with `generateContent` support and caches the result in the actor for the app's lifetime.

### Chat orchestration (`ChatViewModel`)

`@MainActor` class. Owns `messages`, `isLoading`, `streamingMessageId`, `suggestions`, `errorMessage`, `editingMessageId`, and the in-flight `streamTask`.

- A new model message is appended on the **first non-empty text chunk**, then mutated in place. Token-by-token UI updates are throttled to ~10 Hz via the `0.1`-second `lastUpdate` check inside `processRequest()`.
- `stopGeneration()` cancels the stream but keeps whatever was generated so far and persists it. `regenerateLast()` drops the trailing model message and re-requests.
- `persistCurrentState()` runs after every send/edit/finish; it preserves `createdAt` and `isPinned` from the existing metadata so they aren't reset on each save.
- After a successful stream, `scheduleReplyNotificationIfNeeded()` posts a local notification *only if* `WKExtension.shared().applicationState != .active`.
- `scheduleUpdate(_:)` debounces the conversation-list refresh callback (`onUpdate`) to 0.5 s — don't call the callback directly from streaming chunks.

### Persistence (`PersistenceManager`)

Singleton (`shared`). One JSON file per conversation in `Documents/conversations/<uuid>.json`, plus a sidecar `_index.json` containing the `[ConversationMetadata]` list.

- Metadata is cached in memory behind `cacheLock` (NSLock). On save/delete, the in-memory cache is updated **synchronously** so the next read sees the change, while the actual file write is dispatched to a background `ioQueue`. Preserve this ordering when adding new mutations.
- On first launch after upgrading from the old single-blob layout, `migrateFromUserDefaultsIfNeeded()` reads the legacy `saved_conversations` UserDefaults key, splits it into per-file storage, and sets the `conversations_migrated_v2` flag.
- `AppSettings` is small, so it lives in `UserDefaults` under `app_settings` rather than the file store.

### Markdown / LaTeX rendering (`MarkdownParser`)

Singleton with pre-compiled `NSRegularExpression`s and an LRU cache (key = full message text, limit 100).

- `parse(_:isStreaming:)` **must be called with `isStreaming: true` while a message is mid-stream** (see `MessageView`). This skips writing partial-prefix variants into the cache.
- Order matters in `doParse`: code blocks are extracted first; math is then extracted only outside code regions, with inline math suppressed when it overlaps a block-math match.
- `formatMath(_:)` converts a curated subset of LaTeX into Unicode glyphs (greek letters, operators, `\frac`, `\sqrt`, super/subscripts) — there is intentionally **no real LaTeX renderer**; new symbol support means extending the `greek` / `operators` tables.
- `* item` lists are converted to `• item` via `listMarkerRegex` in `formatText`.

### TTS (`Speaker`)

Singleton, `@MainActor`. Sets `AVAudioSession` to `.playback` / `.voicePrompt` on init. Tap-to-speak in `MessageView` toggles: tapping the same message while it's speaking stops it; tapping a different one stops the first and starts the new one.

`cleanMarkdown` strips `*`/`**`/`` ` ``/`$`/`$$` and emoji presentation glyphs before synthesis — extend this if new markdown syntax becomes audible.

### UI conventions (40 mm / 41 mm)

- Typography is deliberately tiny: body messages 12 pt, captions 9–10 pt, timestamps 8 pt, code 9 pt monospaced. **Don't bump these without checking the 40/41 mm simulator** — these sizes are tuned to fit the smallest active screens.
- Haptics are gated on `settingsStore.settings.hapticsEnabled`. Use `WKInterfaceDevice.current().play(.click | .start | .success | .stop)` consistently with existing callsites.
- The `GeminiBrand.gradient` (blue → purple → pink) and `GeminiSpark` view in `Branding.swift` are the only sanctioned brand surfaces. Reuse them rather than redefining colors locally.

## Code-comment markers

Source comments reference numbered notes (`#1`, `#2`, `#5`, `#6`, `#9`, `#11`–`#18`). These map to historical issues/PRs and are load-bearing context for the surrounding fix — keep them when editing nearby code.

## Privacy guarantees to preserve

- Conversations live only in the watch's sandbox; nothing is sent off-device except the prompt body to the Gemini API itself.
- No analytics, telemetry, or third-party SDKs. Don't introduce any without an explicit ask.
