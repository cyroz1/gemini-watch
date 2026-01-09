import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    List {
                        ForEach(viewModel.messages.indices, id: \.self) { index in
                            let msg = viewModel.messages[index]
                            
                            HStack {
                                if msg.role == "user" { Spacer(minLength: 20) }
                                
                                // Native Markdown rendering via LocalizedStringKey
                                if msg.role == "model" && msg.text.isEmpty && viewModel.isLoading {
                                    ProgressView()
                                        .padding(8)
                                        .background(RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.gray.opacity(0.2)))
                                } else {
                                    Text(LocalizedStringKey(msg.text))
                                        .font(.system(size: 13))
                                        .padding(8)
                                        .background(RoundedRectangle(cornerRadius: 12)
                                            .fill(msg.role == "user" ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2)))
                                        // Smoothly animate text growth and layout changes
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: msg.text)
                                        .contextMenu {
                                            if msg.role == "user" {
                                                Button {
                                                    inputText = msg.text
                                                    viewModel.editingIndex = index
                                                } label: {
                                                    Label("Edit", systemImage: "pencil")
                                                }
                                            }
                                        }
                                }
                                
                                if msg.role == "model" { Spacer(minLength: 20) }
                            }
                            // Minimal margins for Apple Watch
                            .listRowInsets(EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 2))
                            .listRowBackground(Color.clear)
                            .id(index)
                        }
                    }
                    .listStyle(.plain) // Essential to remove the bulky Watch "platters"
                    .onChange(of: viewModel.messages.count) {
                        let lastIndex = viewModel.messages.count - 1
                        guard lastIndex >= 0 else { return }
                        
                        // Scroll to the top of the new model message immediately
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if viewModel.messages[lastIndex].role == "model" {
                                proxy.scrollTo(lastIndex, anchor: .top)
                            } else {
                                proxy.scrollTo(lastIndex, anchor: .bottom)
                            }
                        }
                    }
                }

                TextField(viewModel.editingIndex == nil ? "Ask Gemini..." : "Editing...", text: $inputText)
                    .font(.system(size: 14))
                    .padding(.horizontal, 4)
                    .onSubmit {
                        if let index = viewModel.editingIndex {
                            viewModel.editMessage(at: index, newText: inputText)
                            viewModel.editingIndex = nil
                        } else {
                            viewModel.sendMessage(inputText)
                        }
                        inputText = ""
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
