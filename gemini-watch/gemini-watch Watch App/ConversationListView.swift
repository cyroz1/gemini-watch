import SwiftUI

struct ConversationListView: View {
    @State private var conversations: [ConversationMetadata] = []
    @State private var activeConversation: ConversationMetadata?
    @State private var showSettings = false
    @State private var searchText = ""

    @EnvironmentObject private var settingsStore: AppSettingsStore

    private let persistence = PersistenceManager.shared
    private let geminiService = GeminiService()

    var filteredConversations: [ConversationMetadata] {
        let sorted = conversations.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

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
            .searchable(text: $searchText, prompt: "Search") // (#13)
            .navigationDestination(item: $activeConversation) { metadata in
                ContentView(conversationId: metadata.id, onUpdate: refreshList)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(geminiService: geminiService, onClearAll: {
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
            ForEach(filteredConversations) { convo in
                Button {
                    activeConversation = convo
                } label: {
                    HStack(spacing: 4) {
                        if convo.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.yellow)
                        }
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
                    }
                    .padding(.vertical, 2)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                // Swipe actions: pin/unpin (#9)
                .swipeActions(edge: .leading) {
                    Button {
                        togglePin(convo)
                    } label: {
                        Label(convo.isPinned ? "Unpin" : "Pin", systemImage: convo.isPinned ? "pin.slash" : "pin")
                    }
                    .tint(.yellow)
                }
            }
            .onDelete(perform: deleteConversations)
        }
        .listStyle(.plain)
    }

    // MARK: - Actions

    private func startNewChat() {
        let newConvo = Conversation()
        persistence.saveConversation(newConvo)
        activeConversation = ConversationMetadata(
            id: newConvo.id,
            title: newConvo.title,
            createdAt: newConvo.createdAt,
            updatedAt: newConvo.updatedAt,
            isPinned: false
        )
        refreshList()
    }

    private func refreshList() {
        conversations = persistence.loadConversationsMetadata()
    }

    private func deleteConversations(at offsets: IndexSet) {
        for idx in offsets {
            persistence.deleteConversation(id: filteredConversations[idx].id)
        }
        refreshList()
    }

    private func togglePin(_ convo: ConversationMetadata) {
        var updated = convo
        updated.isPinned.toggle()
        persistence.updateMetadata(updated)
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
