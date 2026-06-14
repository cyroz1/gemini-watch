import SwiftUI
import WatchKit

struct ConversationListView: View {
    @State private var conversations: [ConversationMetadata] = []
    @State private var activeConversation: ConversationMetadata?
    @State private var showSettings = false
    @State private var searchText = ""
    @State private var scrollAmount = 0.0

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
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startNewChat()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search")
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
        VStack(spacing: 12) {
            GeminiSpark(size: 32)
                .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            
            Text("No Chats Yet")
                .font(.headline)
            
            Text("Tap + to start a new conversation with \(settingsStore.settings.modelName.replacingOccurrences(of: "gemini-", with: ""))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                startNewChat()
            } label: {
                Text("New Chat")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var conversationList: some View {
        List {
            ForEach(filteredConversations) { convo in
                Button {
                    activeConversation = convo
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(convo.isPinned ? Color.yellow : Color.blue.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .overlay {
                                Image(systemName: convo.isPinned ? "pin.fill" : "bubble.left.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(convo.isPinned ? .black : .blue)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(convo.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Text(convo.updatedAt.relativeString)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white.opacity(0.1))
                        .padding(.vertical, 2)
                )
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
        .listStyle(.carousel) // Modern watchOS list styling
        .focusable()
        .digitalCrownRotation($scrollAmount)
        .onChange(of: scrollAmount) {
            if settingsStore.settings.hapticsEnabled {
                WKInterfaceDevice.current().play(.selection)
            }
        }
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
