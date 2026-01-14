# Gemini Watch

A standalone Apple Watch application that brings the power of Google's Gemini AI to your wrist.

## Features

- **Chat Interface**: Interact with Gemini directly from your Apple Watch.
- **Message History**: Maintains context of the conversation for natural follow-ups.
- **Message Editing**: Long-press on any user message to edit it and regenerate the response.
- **Markdown Support**: Renders responses with basic formatting, including code blocks.
- **LaTeX Support**: Renders math expressions (inline `$` and block `$$`) with distinct styling.
- **Text-to-Speech**: Tap on Gemini's messages to hear them spoken aloud.
- **Double Tap Support**: Use the system Double Tap gesture (or tap "Reply") to quickly open the input.
- **Optimized for SE**: Responsive design using Dynamic Type and haptic feedback for a great experience on smaller screens.
- **Streaming Responses**: Real-time text generation.

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

4. **Run**:
   Select the "gemini-watch Watch App" target and a Watch Simulator (or connected device) and press Run (Cmd+R).

## Requirements

- Xcode 15+
- watchOS 10+
- A Google Cloud Project with the Gemini API enabled.

## Architecture

- **`ChatViewModel`**: Manages the state of the chat connection.
- **`GeminiService`**: Handles networking and streaming connection to the Gemini API.
- **`Models`**: Contains the `Message` data structure for type-safe chat history.
