# AGENTS.md

## Purpose

This file gives coding agents the project-specific context needed to work on Gemini Watch safely and consistently. Read it before making changes.

Gemini Watch is a standalone watchOS SwiftUI app that talks directly to the Google Gemini API. It has no iPhone companion app, no server, no third-party package manager, and no analytics SDK. Keep changes small, native, and watch-first.

## Repository Layout

```text
.
├── README.md
├── LICENSE
├── .gitignore
└── gemini-watch/
    ├── gemini-watch.xcodeproj/
    └── gemini-watch Watch App/
        ├── AppSettingsStore.swift
        ├── Branding.swift
        ├── ChatViewModel.swift
        ├── ContentView.swift
        ├── ConversationListView.swift
        ├── GeminiService.swift
        ├── MarkdownParser.swift
        ├── MessageView.swift
        ├── Models.swift
        ├── PersistenceManager.swift
        ├── Secrets.plist.example
        ├── SettingsView.swift
        ├── Speaker.swift
        ├── gemini_watchApp.swift
        └── Assets.xcassets/
```

Important project characteristics:

- Native SwiftUI watchOS app.
- watchOS deployment target is 11.0.
- Swift version is 5.0 in project settings.
- The Watch App target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- The project uses Xcode's file system synchronized root group for the watch app source folder. Adding a Swift file under `gemini-watch/gemini-watch Watch App/` should normally be picked up by Xcode without manually editing the project file.
- There are currently no Swift Package Manager, CocoaPods, Carthage, or npm dependencies.

## Build And Run

Primary workflow:

1. Open `gemini-watch/gemini-watch.xcodeproj` in Xcode 16 or later.
2. Select the `gemini-watch Watch App` scheme.
3. Choose an Apple Watch simulator or paired watch.
4. Build and run with Cmd-R.

CLI workflow, when full Xcode is selected:

```bash
xcodebuild -list -project gemini-watch/gemini-watch.xcodeproj
xcodebuild \
  -project gemini-watch/gemini-watch.xcodeproj \
  -scheme "gemini-watch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
  build
```

If `xcodebuild` reports that the active developer directory is Command Line Tools, the machine needs full Xcode selected, for example:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Do not add a package manager or external build system just to make local validation easier.

## Secrets And API Keys

The Gemini API key is loaded from `Secrets.plist` in the app bundle.

- `Secrets.plist` must not be committed.
- `Secrets.plist.example` is the committed template and should remain safe for public repos.
- `.gitignore` already excludes `Secrets.plist`.
- Do not add fallback keys, sample real keys, logging of keys, or hard-coded API credentials.
- If API-key handling changes, preserve a clear missing-key error path for users.

The expected plist key is:

```text
GEMINI_API_KEY
```

## Architecture

The app follows a lean MVVM-style structure:

```text
ConversationListView
  -> ContentView
      -> ChatViewModel
          -> GeminiService
          -> PersistenceManager
          -> AppSettingsStore
      -> MessageView
          -> MarkdownParser
          -> Speaker
```

Core responsibilities:

- `gemini_watchApp.swift`: app entry point, creates shared `AppSettingsStore` and `Speaker`, injects them through the SwiftUI environment, and requests notification authorization.
- `ConversationListView.swift`: root navigation, conversation list, search, pin/unpin, delete, settings sheet, and new-chat creation.
- `ContentView.swift`: main chat UI, message scrolling, input bar, quick-reply chips, edit flow, stop/regenerate actions, and error display.
- `ChatViewModel.swift`: conversation state, user/model messages, streaming orchestration, cancellation, haptics, persistence calls, suggestions, and local reply notifications.
- `GeminiService.swift`: Google Gemini API client, streaming SSE parsing, model listing, system prompt and temperature plumbing, web-search grounding, and API error mapping.
- `Models.swift`: `Message`, `Conversation`, `ConversationMetadata`, `GroundingSource`, and `AppSettings`.
- `PersistenceManager.swift`: file-backed conversation storage, metadata index, UserDefaults-backed settings, and legacy migration.
- `SettingsView.swift`: model picker, speech speed, temperature, feature toggles, web search, system prompt, and clear-all action.
- `MessageView.swift`: message bubble rendering, markdown/math/code display, citations sheet, TTS trigger, context menu, and streaming indicator.
- `MarkdownParser.swift`: lightweight markdown/math/code parsing with precompiled regexes and a small parse cache.
- `Speaker.swift`: `AVSpeechSynthesizer` wrapper and markdown cleanup for speech output.
- `Branding.swift`: shared Gemini gradient and sparkle mark.

## Data Flow

Message send flow:

1. `ContentView` submits text to `ChatViewModel.sendMessage`.
2. The view model appends a user `Message` and persists the current conversation.
3. `ChatViewModel.processRequest` reads current settings from `AppSettingsStore`.
4. `GeminiService.streamGenerateContent` builds the Gemini request and starts an SSE stream.
5. Stream events update the current model message incrementally on the main actor.
6. When streaming finishes, the view model persists the final state and may generate quick replies.

Conversation storage:

- Each conversation is one JSON file in the app Documents directory under `conversations/`.
- `_index.json` stores metadata for fast list loading.
- `ConversationMetadata` is intentionally lighter than `Conversation`.
- `PersistenceManager` updates the metadata cache synchronously and writes JSON on a background queue.
- Settings are small and remain in UserDefaults under the `app_settings` key.

Gemini request details:

- API base: `https://generativelanguage.googleapis.com/v1beta/models/`.
- Streaming endpoint uses `:streamGenerateContent?alt=sse`.
- The API key is sent in `x-goog-api-key`.
- The service trims context to the last 20 messages, removes leading model messages, and collapses adjacent same-role messages to preserve Gemini's expected user/model alternation.
- Web search grounding is opt-in through Settings and maps to Gemini's `google_search` tool.

## Coding Guidelines

Keep the app watch-first:

- Design for 40mm and 41mm screens first.
- Prefer compact typography, short labels, and predictable watchOS controls.
- Avoid large explanatory screens, marketing copy, or phone-sized layouts.
- Keep tap targets usable without making the layout feel oversized.
- Check that long labels and generated text do not overlap or push core controls off-screen.

Use existing patterns:

- Use SwiftUI and system frameworks already present in the project.
- Prefer `@StateObject`, `@EnvironmentObject`, and simple value models as already used.
- Keep UI state in views and conversation/business state in `ChatViewModel`.
- Keep network code in `GeminiService`.
- Keep persistence code in `PersistenceManager`.
- Keep shared user preferences in `AppSettingsStore`.
- Do not introduce broad architecture changes without a clear need.

Concurrency:

- Treat UI mutation as main-actor work.
- `ChatViewModel`, `AppSettingsStore`, and `Speaker` are main-actor oriented.
- `GeminiService` is an `actor`; keep network and model-list caching there.
- Preserve cancellation behavior for streaming tasks.
- Avoid blocking the main actor with file I/O, network waits, or expensive parsing.

Persistence:

- Preserve backward decoding compatibility when adding model or settings fields.
- For new `AppSettings` fields, update `CodingKeys`, the custom decoder, the initializer, and `.default`.
- Optional fields are preferred for persisted model additions unless every legacy payload can decode safely.
- Keep writes atomic where practical.
- Do not store large conversation payloads in UserDefaults.

Streaming:

- Preserve incremental token display.
- Do not wait for the whole response before showing the model message.
- Preserve `streamingMessageId` so `MessageView` can show the live indicator.
- Keep partial responses when the user stops generation.
- Keep error messages short enough for watch screens.

Markdown and rendering:

- `MarkdownParser` intentionally supports a small subset: code blocks, inline math, block math, bullet normalization, and selected LaTeX replacements.
- Do not add a full markdown dependency without weighing binary size and watch performance.
- Avoid parsing changes that run heavy regex work repeatedly while streaming.
- The parser intentionally skips cache writes for streaming partials.

Text-to-speech:

- Use `Speaker` instead of creating another `AVSpeechSynthesizer`.
- Keep markdown cleanup in `Speaker.cleanMarkdown`.
- Pass settings into `Speaker.speak` rather than loading settings inside `Speaker`.

Branding and visual style:

- Use `GeminiBrand.gradient` and `GeminiSpark` for Gemini accent moments.
- Prefer system SF Symbols for controls.
- Avoid custom icon systems unless there is a strong reason.
- Keep color usage restrained and readable in watchOS dark UI.

## Adding Features

Before adding a new feature, identify the smallest place it belongs:

- New chat behavior: usually `ChatViewModel` and `ContentView`.
- New setting: `AppSettings`, `AppSettingsStore`, `SettingsView`, and wherever the setting is consumed.
- New Gemini request option: `AppSettings` if user-configurable, then `ChatViewModel` and `GeminiService`.
- New persisted conversation field: `Models.swift`, with decode compatibility considered.
- New list behavior: `ConversationListView` and possibly `PersistenceManager`.
- New rendering behavior: `MessageView` and `MarkdownParser`.

When adding a source file, put it under:

```text
gemini-watch/gemini-watch Watch App/
```

Then verify Xcode sees it. Because this project uses a synchronized root group, manual `.pbxproj` edits may not be necessary for ordinary source additions.

## Testing And Validation

There is currently no dedicated test target in the project.

Preferred validation:

1. Build the watch app in Xcode.
2. Run on a watchOS simulator.
3. Verify at least:
   - launch shows the conversation list
   - new chat opens
   - missing `Secrets.plist` shows a clear error
   - sending with a valid key streams text
   - stop generation keeps partial text
   - settings persist across relaunch
   - conversations persist and can be deleted
   - model picker failure is handled gracefully
   - web-search sources display when enabled and returned
   - TTS starts and stops for model messages

CLI validation, when full Xcode is available:

```bash
xcodebuild \
  -project gemini-watch/gemini-watch.xcodeproj \
  -scheme "gemini-watch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
  build
```

If a simulator name differs locally, run:

```bash
xcrun simctl list devices available
```

Then choose an available watchOS simulator.

When validation cannot be run, state the reason clearly in the final response.

## Git And Review Hygiene

- Keep changes focused on the requested task.
- Do not stage unrelated files, especially `.DS_Store`, `xcuserdata/`, local build products, or personal simulator files.
- Do not commit `Secrets.plist`.
- Do not rewrite user changes unless explicitly asked.
- If the tree is already dirty, inspect it before staging and stage only intended files.
- Prefer concise commits that describe the actual change.
- Before pushing, check:

```bash
git status -sb
git diff --stat
git diff --cached --stat
```

## Common Pitfalls

- `git pull` may be configured to rebase and fail if unrelated local files are dirty. Preserve user changes and use a safe fetch plus fast-forward when appropriate.
- Full Xcode is required for `xcodebuild`; Command Line Tools alone are not enough.
- Watch screens are tiny. Text that looks acceptable in a desktop preview can be unusable on a 40mm simulator.
- Gemini streaming chunks may include text and grounding metadata at different times. Consumers must handle sources arriving before, during, or after text.
- Older persisted settings and messages may not contain newly added fields. Keep decoders tolerant.
- `Link` on watchOS may hand off to the paired iPhone; do not assume in-watch browser behavior.
- Network failures, invalid keys, rate limits, and server errors should produce short user-facing messages.

## Documentation Updates

Update `README.md` when a user-facing feature, setup requirement, setting, privacy behavior, or supported platform changes.

Update this file when agent workflow, project structure, build steps, architecture, or contribution expectations change.
