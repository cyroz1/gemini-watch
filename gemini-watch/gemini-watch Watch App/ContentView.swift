import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""
    
    var body: some View {
        VStack {
            // Message List
            ScrollViewReader { proxy in
                List {
                    ForEach(viewModel.messages.indices, id: \.self) { index in
                        let msg = viewModel.messages[index]
                        Text(msg.text)
                            .padding(8)
                            .background(msg.role == "user" ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .listRowInsets(EdgeInsets()) // Removes default list padding
                            .id(index) // For auto-scrolling
                    }
                    if viewModel.isLoading {
                        ProgressView()
                            .id("loading")
                    }
                }
                .onChange(of: viewModel.messages.count) {
                    withAnimation {
                        proxy.scrollTo(viewModel.messages.count - 1, anchor: .bottom)
                    }
                }
            }
            
            // Input Area
            HStack {
                TextField("Ask Gemini...", text: $inputText)
                    .onSubmit {
                        viewModel.sendMessage(inputText)
                        inputText = "" // Clear input
                    }
            }
            .padding(.top, 5)
        }
        .padding()
    }
}
