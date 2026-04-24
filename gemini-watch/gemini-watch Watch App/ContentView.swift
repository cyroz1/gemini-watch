import SwiftUI
import WatchKit

struct ContentView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    @EnvironmentObject private var settingsStore: AppSettingsStore
    @EnvironmentObject private var speaker: Speaker

    let conversationId: UUID
    var onUpdate: (() -> Void)?

    init(conversationId: UUID, onUpdate: (() -> Void)? = nil) {
        self.conversationId = conversationId
        self.onUpdate = onUpdate
        // ViewModel created here; settingsStore injected after init via configure()
        _viewModel = StateObject(wrappedValue: ChatViewModel())
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: - Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        if viewModel.messages.isEmpty {
                            emptyState
                        }

                        ForEach(viewModel.messages) { msg in
                            HStack {
                                if msg.role == .user { Spacer(minLength: 16) }

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
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                            .padding(.horizontal, 3)
                            .id(msg.id)
                        }

                        // Loading indicator
                        if viewModel.isLoading {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Thinking…")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .id("loader")
                        }

                        // Quick-reply suggestions
                        if !viewModel.suggestions.isEmpty {
                            suggestionChips
                                .id("suggestions")
                                .transition(.opacity)
                        }

                        Color.clear.frame(height: 80)
                            .id("bottom_anchor")
                    }
                    .padding(.top, 4)
                }
                .onChange(of: viewModel.messages.count) {
                    guard let lastMsg = viewModel.messages.last else { return }

                    if lastMsg.role == .model && settingsStore.settings.hapticsEnabled {
                        WKInterfaceDevice.current().play(.success)
                    }

                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if lastMsg.role == .model {
                                proxy.scrollTo(lastMsg.id, anchor: .top)
                            } else {
                                proxy.scrollTo("bottom_anchor", anchor: .bottom)
                            }
                        }
                    }

                    viewModel.scheduleUpdate(onUpdate)
                }
                .onChange(of: viewModel.suggestions) {
                    guard !viewModel.suggestions.isEmpty else { return }
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if let lastMsg = viewModel.messages.last, lastMsg.role == .model {
                                proxy.scrollTo(lastMsg.id, anchor: .top)
                            } else {
                                proxy.scrollTo("bottom_anchor", anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // MARK: - Input Bar
            inputBar

            // MARK: - Error
            if let error = viewModel.errorMessage {
                errorBanner(error)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isGenerating {
                    Button {
                        viewModel.stopGeneration()
                        if settingsStore.settings.hapticsEnabled {
                            WKInterfaceDevice.current().play(.stop)
                        }
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } else {
                    Button {
                        viewModel.resetChat()
                        onUpdate?()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption)
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

    private static let examplePrompts = [
        "Explain a concept",
        "Summarize this idea",
        "Translate to Spanish",
        "Help me decide",
    ]

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 14)
            GeminiSpark(size: 22)
            Text("Ask Gemini anything")
                .font(.caption2)
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                ForEach(Self.examplePrompts, id: \.self) { prompt in
                    Button {
                        inputText = prompt
                        isInputFocused = true
                        if settingsStore.settings.hapticsEnabled {
                            WKInterfaceDevice.current().play(.click)
                        }
                    } label: {
                        Text(prompt)
                            .font(.system(size: 10, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 4)

            Spacer().frame(height: 14)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Suggestion Chips

    private var suggestionChips: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(viewModel.suggestions, id: \.self) { suggestion in
                Button {
                    viewModel.sendMessage(suggestion)
                    if settingsStore.settings.hapticsEnabled {
                        WKInterfaceDevice.current().play(.click)
                    }
                } label: {
                    Text(suggestion)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        TextField(viewModel.editingMessageId == nil ? "Ask Gemini…" : "Editing…", text: $inputText)
            .textFieldStyle(.plain)
            .buttonStyle(.plain)
            .font(.caption2)
            .frame(height: 28)
            .focused($isInputFocused)
            .handGestureShortcut(.primaryAction)
            .onSubmit {
                sendOrEdit()
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 14)
            .background(.ultraThinMaterial)
            .clipShape(ContainerRelativeShape())
            .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: String) -> some View {
        VStack(spacing: 6) {
            Text(error)
                .font(.system(size: 9))
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)

            Button("Retry") {
                viewModel.retry()
            }
            .font(.system(size: 10, weight: .medium))
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.mini)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.1))
        .cornerRadius(6)
        .padding(.horizontal, 6)
        .padding(.bottom, 46)
        .transition(.opacity)
    }

    // MARK: - Actions

    private func sendOrEdit() {
        if let id = viewModel.editingMessageId {
            viewModel.editMessage(id: id, newText: inputText)
            viewModel.editingMessageId = nil
        } else {
            viewModel.sendMessage(inputText)
        }
        if settingsStore.settings.hapticsEnabled {
            WKInterfaceDevice.current().play(.click)
        }
        inputText = ""
    }
}
