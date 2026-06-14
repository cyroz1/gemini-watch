import SwiftUI
import WatchKit

struct ContentView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var scrollAmount = 0.0

    @EnvironmentObject private var settingsStore: AppSettingsStore
    @EnvironmentObject private var speaker: Speaker

    let conversationId: UUID
    var onUpdate: (() -> Void)?

    init(conversationId: UUID, onUpdate: (() -> Void)? = nil) {
        self.conversationId = conversationId
        self.onUpdate = onUpdate
        _viewModel = StateObject(wrappedValue: ChatViewModel())
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: - Messages
            ScrollViewReader { proxy in
                List {
                    if viewModel.messages.isEmpty {
                        emptyState
                            .listRowBackground(Color.clear)
                    }

                    ForEach(viewModel.messages) { msg in
                        MessageView(
                            message: msg,
                            isStreaming: viewModel.streamingMessageId == msg.id,
                            onRegenerate: (msg.role == .model && msg.id == viewModel.messages.last?.id && !viewModel.isGenerating)
                                ? { viewModel.regenerateLast() }
                                : nil
                        )
                        .onLongPressGesture {
                            if settingsStore.settings.hapticsEnabled {
                                WKInterfaceDevice.current().play(.click)
                            }
                            inputText = msg.text
                            viewModel.editingMessageId = msg.id
                            isInputFocused = true
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(msg.role == .user ? Color.blue.opacity(0.15) : Color.white.opacity(0.08))
                        )
                        .id(msg.id)
                    }

                    // Loading indicator
                    if viewModel.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Gemini is thinking…")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                        .id("loader")
                    }

                    // Quick-reply suggestions
                    if !viewModel.suggestions.isEmpty {
                        suggestionChips
                            .listRowBackground(Color.clear)
                            .id("suggestions")
                    }

                    Color.clear.frame(height: 40)
                        .listRowBackground(Color.clear)
                        .id("bottom_anchor")
                }
                .listStyle(.elliptical) // Modern watchOS list shape
                .focusable()
                .digitalCrownRotation($scrollAmount)
                .onChange(of: scrollAmount) {
                    if settingsStore.settings.hapticsEnabled {
                        WKInterfaceDevice.current().play(.selection)
                    }
                }
                .onChange(of: viewModel.messages.count) {
                    guard let lastMsg = viewModel.messages.last else { return }

                    if lastMsg.role == .model && settingsStore.settings.hapticsEnabled {
                        WKInterfaceDevice.current().play(.success)
                    }

                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if lastMsg.role == .model {
                            proxy.scrollTo(lastMsg.id, anchor: .top)
                        } else {
                            proxy.scrollTo("bottom_anchor", anchor: .bottom)
                        }
                    }
                    viewModel.scheduleUpdate(onUpdate)
                }
            }

            // MARK: - Input Bar
            inputBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isGenerating {
                    Button {
                        viewModel.stopGeneration()
                    } label: {
                        Image(systemName: "stop.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .onAppear {
            viewModel.configure(settingsStore: settingsStore)
            viewModel.loadConversation(id: conversationId)
        }
        .edgesIgnoringSafeArea(.bottom)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 20)
            GeminiSpark(size: 30)
            Text("How can I help?")
                .font(.headline)
            
            VStack(spacing: 6) {
                ForEach(["Explain concepts", "Summarize text", "Write code"], id: \.self) { prompt in
                    Button {
                        inputText = prompt
                        isInputFocused = true
                    } label: {
                        Text(prompt)
                            .font(.caption2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            Spacer().frame(height: 20)
        }
    }

    // MARK: - Suggestion Chips

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.suggestions, id: \.self) { suggestion in
                    Button {
                        viewModel.sendMessage(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.3))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        TextField(viewModel.editingMessageId == nil ? "Message…" : "Edit…", text: $inputText)
            .textFieldStyle(.plain)
            .focused($isInputFocused)
            .onSubmit {
                sendOrEdit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
    }

    private func sendOrEdit() {
        guard !inputText.isEmpty else { return }
        if let id = viewModel.editingMessageId {
            viewModel.editMessage(id: id, newText: inputText)
        } else {
            viewModel.sendMessage(inputText)
        }
        inputText = ""
    }
}
