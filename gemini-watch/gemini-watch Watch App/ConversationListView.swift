import SwiftUI

struct ConversationListView: View {
    @State private var conversations: [Conversation] = []
    @State private var activeConversation: Conversation?
    @State private var showSettings = false
    
    private let persistence = PersistenceManager.shared
    
    var body: some View {
        NavigationStack {
            Group {
                if conversations.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
            .navigationTitle("Gemini")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startNewChat()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption)
                    }
                }
            }
            .navigationDestination(item: $activeConversation) { conversation in
                ContentView(conversation: conversation, onUpdate: refreshList)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(onClearAll: {
                    conversations = []
                })
            }
            .onAppear {
                refreshList()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.blue.opacity(0.7))
            Text("No Chats Yet")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                startNewChat()
            } label: {
                Label("New Chat", systemImage: "plus")
                    .font(.caption2)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var conversationList: some View {
        List {
            ForEach(conversations) { convo in
                Button {
                    activeConversation = convo
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(convo.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(convo.updatedAt.relativeString)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            }
            .onDelete(perform: deleteConversations)
        }
        .listStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func startNewChat() {
        let newConvo = Conversation()
        persistence.saveConversation(newConvo)
        activeConversation = newConvo
        refreshList()
    }
    
    private func refreshList() {
        conversations = persistence.loadConversations()
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    
    private func deleteConversations(at offsets: IndexSet) {
        for idx in offsets {
            persistence.deleteConversation(id: conversations[idx].id)
        }
        refreshList()
    }
}

// MARK: - Relative Date Formatting

extension Date {
    var relativeString: String {
        let interval = -self.timeIntervalSinceNow
        if interval < 60     { return "Just now" }
        if interval < 3600   { return "\(Int(interval / 60))m ago" }
        if interval < 86400  { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        return Date.relativeDateFormatter.string(from: self)
    }

    private static let relativeDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
}
