import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    // @State so settings refresh when the view appears (e.g. after visiting Settings)
    @State private var settings: AppSettings = PersistenceManager.shared.loadSettings()

    let conversation: Conversation
    var onUpdate: (() -> Void)?

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
                                    settings: settings,
                                    isStreaming: viewModel.streamingMessageId == msg.id
                                )
                                .onLongPressGesture {
                                    if settings.hapticsEnabled {
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
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(6)
                                Spacer()
                            }
                            .id("loader")
                        }

                        // Quick-reply suggestions
                        if !viewModel.suggestions.isEmpty {
                            suggestionChips
                                .id("suggestions")
                                .transition(.opacity)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 80)
                }
                .onChange(of: viewModel.messages.count) {
                    guard let lastMsg = viewModel.messages.last else { return }

                    if lastMsg.role == .model && settings.hapticsEnabled {
                        WKInterfaceDevice.current().play(.success)
                    }

                    // Use Task instead of DispatchQueue so the work can be cancelled with the view
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            proxy.scrollTo(lastMsg.id, anchor: .bottom)
                        }
                    }

                    viewModel.scheduleUpdate(onUpdate)
                }
                .onChange(of: viewModel.suggestions) {
                    guard !viewModel.suggestions.isEmpty,
                          let lastMsg = viewModel.messages.last else { return }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            proxy.scrollTo(lastMsg.id, anchor: .top)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.resetChat()
                    onUpdate?()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                }
            }
        }
        .onAppear {
            viewModel.loadConversation(conversation)
            // Reload settings in case they changed while away
            settings = PersistenceManager.shared.loadSettings()
        }
        .edgesIgnoringSafeArea(.bottom)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer().frame(height: 20)
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(.blue.opacity(0.6))
            Text("Ask Gemini anything")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer().frame(height: 20)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Suggestion Chips

    private var suggestionChips: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(viewModel.suggestions, id: \.self) { suggestion in
                Button {
                    viewModel.sendMessage(suggestion)
                    if settings.hapticsEnabled {
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
            .font(.caption2)
            .frame(height: 32)
            .focused($isInputFocused)
            .handGestureShortcut(.primaryAction)
            .onSubmit {
                sendOrEdit()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: String) -> some View {
        Text(error)
            .font(.system(size: 9))
            .foregroundStyle(.red)
            .padding(4)
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
        if settings.hapticsEnabled {
            WKInterfaceDevice.current().play(.click)
        }
        inputText = ""
    }
}
