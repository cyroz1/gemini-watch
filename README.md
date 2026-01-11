# Gemini Watch

Gemini Watch is a native watchOS application that brings the power of Google's Gemini AI directly to your wrist. Specifically optimized for the small screen of the Apple Watch, it provides a fast, streaming chat experience.

## Features

- **Gemini 2.5 Flash Integration**: Built with the latest Gemini 2.5 Flash model for lightning-fast, high-quality responses.
- **SSE Streaming**: Responses stream in real-time as they are generated, minimizing wait times.
- **Native Watch UI**: Custom-designed interface that avoids bulky "platters" and maximizes screen space for chat history.
- **Smart Markdown Rendering**: Custom formatting for headings, lists, and mathematical expressions optimized for readability on watchOS.
- **Message Editing**: Long-press any message to edit and refresh the conversation flow.
- **Auto-Scrolling**: Intelligent scrolling that keeps you focused on the latest part of the AI's response.

## Getting Started

### Prerequisites

- **Xcode 15.0+**
- **watchOS 10.0+** (Physical device or Simulator)
- **Gemini API Key**: Obtain one from the [Google AI Studio](https://aistudio.google.com/).

### Setup Instructions

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/cyroz1/gemini-watch.git
   cd gemini-watch
   ```

2. **Configure API Key**:
   - Navigate to the project folder: `gemini-watch/gemini-watch Watch App/`.
   - Locate `Secrets.plist.example`.
   - Duplicate it and rename it to `Secrets.plist`.
   - Open `Secrets.plist` and replace `YOUR_API_KEY_HERE` with your actual Gemini API key.

3. **Open in Xcode**:
   - Open `gemini-watch.xcodeproj`.
   - Ensure the `gemini-watch Watch App` target is selected.

4. **Run**:
   - Select your Apple Watch or a simulator as the run destination.
   - Press `Cmd + R` to build and run.

## Architecture

- **SwiftUI**: Modern, declarative UI framework for a responsive watch experience.
- **Combine/Concurrency**: Uses `AsyncThrowingStream` for efficient SSE (Server-Sent Events) handling.
- **MVVM Pattern**: Clean separation of concerns between `ContentView` and `ChatViewModel`.

## License

This project is licensed under the MIT License - see the [LICENSE](file:///Users/amir/Documents/gemini-watch/LICENSE) file for details.
