import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            // Message is now Identifiable
                            ForEach(viewModel.messages) { msg in
                                HStack {
                                    if msg.role == .user { Spacer(minLength: 20) }
                                    
                                    MessageView(message: msg)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: msg.text)
                                        .onLongPressGesture {
                                            WKInterfaceDevice.current().play(.click)
                                            inputText = msg.text
                                            viewModel.editingMessageId = msg.id
                                            isInputFocused = true
                                        }
                                    
                                    if msg.role == .model { Spacer(minLength: 20) }
                                }
                                .padding(.horizontal, 4)
                                .id(msg.id) // Use UUID for ID
                            }
                            
                            // Show loader at the end of the list
                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .padding(8)
                                    Spacer()
                                }
                                .id("loader")
                            }
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: viewModel.isLoading) {
                        if viewModel.isLoading {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    proxy.scrollTo("loader", anchor: .bottom)
                                }
                            }
                        }
                    }
                    .onChange(of: viewModel.messages.count) {
                        guard let lastMsg = viewModel.messages.last else { return }
                        
                        // Play haptic when a new model message arrives (simple check)
                        if lastMsg.role == .model {
                            WKInterfaceDevice.current().play(.success)
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                proxy.scrollTo(lastMsg.id, anchor: lastMsg.role == .model ? .top : .bottom)
                            }
                        }
                    }
                }

                TextField(viewModel.editingMessageId == nil ? "Ask Gemini..." : "Editing...", text: $inputText)
                    .font(.body) // Dynamic Type
                    .focused($isInputFocused)
                    .padding(.horizontal, 4)
                    .onSubmit {
                        if let id = viewModel.editingMessageId {
                            viewModel.editMessage(id: id, newText: inputText)
                            viewModel.editingMessageId = nil
                        } else {
                            viewModel.sendMessage(inputText)
                        }
                        WKInterfaceDevice.current().play(.click)
                        inputText = ""
                    }
                
                if let error = viewModel.errorMessage {
                    ScrollView {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding(4)
                    }
                    .frame(maxHeight: 60)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { viewModel.resetChat() }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

