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
                            
                            // Native Markdown rendering via LocalizedStringKey
                            Text(LocalizedStringKey(msg.text))
                                .font(.system(size: 13))
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(msg.role == "user" ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2)))
                                // Tight margins for Apple Watch
                                .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                                .listRowBackground(Color.clear)
                                .id(index)
                                .swipeActions(edge: .leading) {
                                    if msg.role == "user" {
                                        Button {
                                            inputText = msg.text
                                            viewModel.editingIndex = index
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.orange)
                                    }
                                }
                        }
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .id(999) // Fixed Int ID to prevent type mismatch
                        }
                    }
                    .listStyle(.plain) // Essential to remove the bulky Watch "platters"
                    .onChange(of: viewModel.messages.count) {
                        let lastIndex = viewModel.messages.count - 1
                        guard lastIndex >= 0 else { return }
                        
                        withAnimation {
                            // If model replies, scroll to START (top) so user can read
                            if viewModel.messages[lastIndex].role == "model" {
                                proxy.scrollTo(lastIndex, anchor: .top)
                            } else {
                                proxy.scrollTo(999, anchor: .bottom)
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
