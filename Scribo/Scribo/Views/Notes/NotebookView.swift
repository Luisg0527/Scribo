import SwiftUI
import UIKit

// MARK: - Topic Color Storage (for space/notebook color coding)
enum TopicColorStore {
    private static let prefix = "topic_color_"
    static func colorHex(for topicId: UUID) -> String? {
        UserDefaults.standard.string(forKey: prefix + topicId.uuidString)
    }
    static func setColorHex(_ hex: String?, for topicId: UUID) {
        if let hex = hex {
            UserDefaults.standard.set(hex, forKey: prefix + topicId.uuidString)
        } else {
            UserDefaults.standard.removeObject(forKey: prefix + topicId.uuidString)
        }
    }
    static func color(for topicId: UUID) -> Color? {
        guard let hex = colorHex(for: topicId) else { return nil }
        return Color(hex: hex)
    }
}

/// 16 colors for the pick-a-color wheel (matches design)
private let notebookColorPalette: [String] = [
    "#FF3B30", "#00C7BE", "#8E8E93", "#FF2D55", "#1C1C1E", "#5AC8FA",
    "#32ADE6", "#FF9F0A", "#30D158", "#FF9500", "#64D2FF", "#FF6482",
    "#FFCC00", "#AF52DE", "#A2845E", "#007AFF"
]

private struct CreationBadgeIconView: View {
    @State private var didAnimate = false
    @State private var scale: CGFloat = 0.78

    var body: some View {
        Image("ScriboLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 96, height: 96)
            .scaleEffect(scale)
            .onAppear {
                guard !didAnimate else { return }
                didAnimate = true

                scale = 0.78
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    scale = 1.0
                }
            }
    }
}

// MARK: - Highlighted Text View
struct HighlightedText: View {
    let text: String
    let searchText: String
    
    var body: some View {
        if searchText.isEmpty {
            Text(text)
        } else {
            let parts = text.components(separatedBy: searchText)
            HStack(spacing: 0) {
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    Text(part)
                    if index < parts.count - 1 {
                        Text(searchText)
                            .foregroundColor(.appAccent1)
                    }
                }
            }
        }
    }
}

@ViewBuilder
private func bulkSelectionBadge(isSelected: Bool) -> some View {
    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(isSelected ? Color.appAccent1 : Color.primary.opacity(0.4))
        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
        .padding(8)
}

// MARK: - Shared notebook in “My notebooks” (library card + detail loader)

/// Title + menu sit outside the navigation link so the menu does not open the notebook.
private enum NotebookLibraryCardLayout {
    static var subheadlineLineHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .subheadline).lineHeight
    }

    /// Reserved height for up to two `.subheadline` lines; ellipsis is centered in this band on every card.
    static var titleRowHeight: CGFloat {
        ceil(subheadlineLineHeight * 2)
    }

    static let previewHeight: CGFloat = 130
    static let titleTopPadding: CGFloat = 8
    static let gridSpacing: CGFloat = 8

    static var gridCellHeight: CGFloat {
        previewHeight + gridSpacing + titleTopPadding + titleRowHeight
    }
}

private struct NotebookLibraryTitleMeasuredHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct NotebookLibraryCardTitleRow: View {
    let title: String
    let allowsRename: Bool
    var showsShare: Bool = true
    let onRename: () -> Void
    let onDelete: () -> Void
    let onShare: () -> Void

    @State private var measuredTitleHeight: CGFloat = 0

    private var isTwoLineTitle: Bool {
        measuredTitleHeight > NotebookLibraryCardLayout.subheadlineLineHeight + 1
    }

    private var rowAlignment: VerticalAlignment {
        isTwoLineTitle ? .top : .center
    }

    var body: some View {
        HStack(alignment: rowAlignment, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.regular)
                .foregroundColor(Color(.secondaryLabel))
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: isTwoLineTitle ? .topLeading : .leading)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: NotebookLibraryTitleMeasuredHeightKey.self,
                            value: geometry.size.height
                        )
                    }
                }

            Menu {
                notebookLibraryMenuActions(
                    allowsRename: allowsRename,
                    showsShare: showsShare,
                    onRename: onRename,
                    onShare: onShare,
                    onDelete: onDelete
                )
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(.secondaryLabel))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: NotebookLibraryCardLayout.titleRowHeight, alignment: .center)
        }
        .frame(height: NotebookLibraryCardLayout.titleRowHeight, alignment: isTwoLineTitle ? .top : .center)
        .onPreferenceChange(NotebookLibraryTitleMeasuredHeightKey.self) { measuredTitleHeight = $0 }
        .onChange(of: title) { _, _ in measuredTitleHeight = 0 }
        .padding(.top, 8)
        .padding(.leading, 4)
        .padding(.trailing, 16)
        .frame(width: 168, alignment: .leading)
    }
}

private struct NotebookLibrarySharedBadge: View {
    var body: some View {
        Image(systemName: "person.2.circle.fill")
            .font(.system(size: 18, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Color(.secondaryLabel))
            .padding(8)
    }
}

/// Tappable stacked-card preview — opens the shared notebook.
private struct SharedNotebookLibraryCardPreview: View {
    let entry: SavedSharedNotebookEntry
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(colorScheme == .dark ? .systemGray3 : .systemGray4))
                .frame(width: 160, height: 124)
                .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                .rotationEffect(.degrees(-6))
                .offset(x: -6, y: 4)
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let snippet = entry.previewSnippet, !snippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(snippet)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(14)
                            .background(Color(.systemBackground))
                    } else {
                        Color.white
                    }
                }
                NotebookLibrarySharedBadge()
            }
            .frame(width: 160, height: 124)
            .clipped()
            .cornerRadius(8)
        }
        .frame(width: 168, height: 130)
    }
}

@ViewBuilder
private func notebookLibraryMenuActions(
    allowsRename: Bool,
    showsShare: Bool = true,
    onRename: @escaping () -> Void,
    onShare: @escaping () -> Void,
    onDelete: @escaping () -> Void
) -> some View {
    if allowsRename {
        Button(action: onRename) {
            Label("Rename", systemImage: "pencil")
        }
    }
    if showsShare {
        Button(action: onShare) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }
    Button(role: .destructive, action: onDelete) {
        Label("Delete", systemImage: "trash")
    }
}

private struct SharedNotebookDetailLoaderView: View {
    let entry: SavedSharedNotebookEntry
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var searchState: SearchState
    @State private var topic: Topic?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let topic = topic {
                TopicPreviewView(
                    topic: topic,
                    isReadOnlySharedNotebook: true,
                    isPresented: .constant(true),
                    dataManager: dataManager
                )
                .environmentObject(searchState)
            } else if loadFailed {
                VStack(spacing: 12) {
                    Text("Couldn’t load this notebook")
                        .font(.headline)
                    Text("The link may have been revoked.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: entry.shareToken) {
            loadFailed = false
            topic = nil
            do {
                guard let payload = try await dataManager.fetchSharedNotebookPayload(shareToken: entry.shareToken) else {
                    await MainActor.run { loadFailed = true }
                    return
                }
                await dataManager.addOrUpdateSharedNotebookInLibrary(shareToken: entry.shareToken, payload: payload)
                await MainActor.run {
                    topic = payload.asTopic()
                }
            } catch {
                await MainActor.run { loadFailed = true }
            }
        }
    }
}

// MARK: - Topic Preview View
struct TopicPreviewView: View {
    let topic: Topic
    /// When true, UI is browse-only (opened from a `/b/…` share link snapshot).
    var isReadOnlySharedNotebook: Bool = false
    @Environment(\.dismiss) var dismiss
    @Binding var isPresented: Bool
    @EnvironmentObject var searchState: SearchState
    @ObservedObject var dataManager: DataManager
    @State private var isShowingShareSheet: Bool = false
    @State private var notebookShareSheetURL: String?
    @State private var isBulkSelectingSubtopics = false
    @State private var selectedSubtopicIdsForDeletion: Set<UUID> = []
    @State private var confirmBulkDeleteSubtopics = false
    @State private var isShowingNewSubtopicSheet = false
    @State private var isShowingEditSubtopicSheet = false
    @State private var subtopicForEdit: Subtopic?
    @State private var subtopicToDelete: Subtopic?
    @State private var editedTopicTitle = ""
    @FocusState private var isTopicTitleFocused: Bool
    @State private var topicTitleHasChanges = false
    
    private var displayTopicTitle: String {
        if isReadOnlySharedNotebook { return topic.title }
        return dataManager.topics.first(where: { $0.id == topic.id })?.title ?? editedTopicTitle
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerView
                    subtopicsGridView
                }
                .padding(.vertical)
            }
            .background(Color.appBackground)
            .overlay(alignment: .bottom) {
                TabBarContentBottomFade()
            }
            if !isBulkSelectingSubtopics, !isReadOnlySharedNotebook {
                Button(action: { isShowingNewSubtopicSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.appAccent1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 30)
                .padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isBulkSelectingSubtopics {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        Text("Tap subtopics to select")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Delete") {
                            confirmBulkDeleteSubtopics = true
                        }
                        .fontWeight(.semibold)
                        .disabled(selectedSubtopicIdsForDeletion.isEmpty)
                        .foregroundColor(selectedSubtopicIdsForDeletion.isEmpty ? Color(.systemGray3) : .red)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.appBackground)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $isShowingShareSheet, onDismiss: { notebookShareSheetURL = nil }) {
            if let url = notebookShareSheetURL {
                ShareQRSheetView(
                    title: displayTopicTitle,
                    inviteURL: url,
                    isPresented: $isShowingShareSheet
                )
            }
        }
        .fullScreenCover(isPresented: $isShowingNewSubtopicSheet) {
            NewSubtopicView(topic: topic, dataManager: dataManager)
        }
        .sheet(isPresented: $isShowingEditSubtopicSheet) {
            if let subtopic = subtopicForEdit,
               let currentTopic = dataManager.topics.first(where: { $0.id == topic.id }),
               let currentSubtopic = currentTopic.subtopics.first(where: { $0.id == subtopic.id }) {
                EditSubtopicView(subtopic: currentSubtopic, topic: currentTopic, dataManager: dataManager)
            }
        }
        .onAppear {
            syncTopicTitleFromDataManager()
        }
        .alert("Delete Subtopic", isPresented: .init(
            get: { subtopicToDelete != nil },
            set: { if !$0 { subtopicToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                subtopicToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let subtopic = subtopicToDelete,
                   let currentTopic = dataManager.topics.first(where: { $0.id == topic.id }) {
                    dataManager.deleteSubtopic(subtopic, from: currentTopic)
                }
                subtopicToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this subtopic? This will also delete all its notes.")
        }
        .alert("Delete selected subtopics?", isPresented: $confirmBulkDeleteSubtopics) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                let ids = selectedSubtopicIdsForDeletion
                for id in ids {
                    guard let t = dataManager.topics.first(where: { $0.id == topic.id }),
                          let st = t.subtopics.first(where: { $0.id == id }) else { continue }
                    dataManager.deleteSubtopic(st, from: t)
                }
                selectedSubtopicIdsForDeletion = []
                isBulkSelectingSubtopics = false
            }
        } message: {
            Text("This will permanently remove \(selectedSubtopicIdsForDeletion.count) subtopic(s) and all notes inside them.")
        }
    }
    
    private var headerView: some View {
        HStack(alignment: .center, spacing: 4) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.appText)
                    .frame(width: 44, height: 44)
            }
            Group {
                if isReadOnlySharedNotebook {
                    Text(displayTopicTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.appText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                } else {
                    TextField("Untitled", text: $editedTopicTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.appText)
                        .multilineTextAlignment(.center)
                        .focused($isTopicTitleFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.appText, lineWidth: 2)
                                .opacity(isTopicTitleFocused ? 1 : 0)
                        )
                        .animation(.easeInOut(duration: 0.25), value: isTopicTitleFocused)
                        .onChange(of: editedTopicTitle) { _, _ in topicTitleHasChanges = true }
                        .onChange(of: isTopicTitleFocused) { _, focused in
                            if !focused && topicTitleHasChanges { Task { await saveTopicTitleIfNeeded() } }
                        }
                        .disabled(isBulkSelectingSubtopics)
                }
            }
            .frame(maxWidth: .infinity)
            if isBulkSelectingSubtopics {
                Button("Cancel") {
                    isBulkSelectingSubtopics = false
                    selectedSubtopicIdsForDeletion = []
                }
                .font(.body.weight(.medium))
                .foregroundColor(.appAccent1)
                .frame(width: 60, alignment: .trailing)
            } else if isReadOnlySharedNotebook {
                Color.clear
                    .frame(width: 44, height: 44)
            } else {
                Menu {
                    Button(action: { Task { await beginNotebookShareFlow() } }) {
                        Label("Share notebook", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive, action: {
                        selectedSubtopicIdsForDeletion = []
                        isBulkSelectingSubtopics = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.appText)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, -8)
        .padding(.bottom, 4)
    }
    
    private func syncTopicTitleFromDataManager() {
        editedTopicTitle = dataManager.topics.first(where: { $0.id == topic.id })?.title ?? topic.title
        topicTitleHasChanges = false
    }
    
    private func beginNotebookShareFlow() async {
        guard !isReadOnlySharedNotebook else { return }
        do {
            let token = try await dataManager.ensureActiveTopicShareLink(forTopicId: topic.id)
            let url = NoteShareInviteURL.httpsNotebookInviteURL(for: token)
            await MainActor.run {
                notebookShareSheetURL = url
                isShowingShareSheet = true
            }
        } catch {
            await MainActor.run { }
        }
    }

    private func saveTopicTitleIfNeeded() async {
        guard !isReadOnlySharedNotebook else {
            await MainActor.run { topicTitleHasChanges = false }
            return
        }
        let trimmed = editedTopicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let t = dataManager.topics.first(where: { $0.id == topic.id }) else {
            await MainActor.run { topicTitleHasChanges = false }
            return
        }
        let newTitle = trimmed.isEmpty ? t.title : trimmed
        guard newTitle != t.title else {
            await MainActor.run {
                topicTitleHasChanges = false
                editedTopicTitle = t.title
            }
            return
        }
        do {
            try await dataManager.updateTopic(t, newTitle: newTitle)
            await MainActor.run {
                topicTitleHasChanges = false
                editedTopicTitle = newTitle
            }
        } catch {
            await MainActor.run {
                editedTopicTitle = t.title
                topicTitleHasChanges = false
            }
        }
    }
                
    private var subtopicsGridView: some View {
        LazyVGrid(columns: [
            GridItem(.fixed(200), spacing: 2),
            GridItem(.fixed(200), spacing: 2)
        ], spacing: 2) {
            ForEach(Array(topic.subtopics.enumerated()), id: \.element.id) { index, subtopic in
                subtopicCard(subtopic)
                    .staggeredCardPopIn(delay: Double(index) * 0.05)
            }
        }
        .padding(.horizontal)
    }
    
    private func subtopicCard(_ subtopic: Subtopic) -> some View {
        let displayTitle = dataManager.topics.first(where: { $0.id == topic.id })?
            .subtopics.first(where: { $0.id == subtopic.id })?.title ?? subtopic.title

        return VStack(spacing: 8) {
            Group {
                if isBulkSelectingSubtopics {
                    Button {
                        if selectedSubtopicIdsForDeletion.contains(subtopic.id) {
                            selectedSubtopicIdsForDeletion.remove(subtopic.id)
                        } else {
                            selectedSubtopicIdsForDeletion.insert(subtopic.id)
                        }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            SubtopicCardPreview(subtopic: subtopic, dataManager: dataManager)
                            bulkSelectionBadge(isSelected: selectedSubtopicIdsForDeletion.contains(subtopic.id))
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink(destination: SubtopicPreviewView(
                        subtopic: subtopic,
                        topic: topic,
                        isPresented: $isPresented,
                        dataManager: dataManager,
                        isReadOnlySharedNotebook: isReadOnlySharedNotebook
                    )) {
                        SubtopicCardPreview(subtopic: subtopic, dataManager: dataManager)
                    }
                    .buttonStyle(.plain)
                }
            }

            NotebookLibraryCardTitleRow(
                title: displayTitle,
                allowsRename: !isReadOnlySharedNotebook,
                showsShare: false,
                onRename: {
                    subtopicForEdit = subtopic
                    isShowingEditSubtopicSheet = true
                },
                onDelete: { subtopicToDelete = subtopic },
                onShare: {}
            )
        }
        .frame(width: 168, height: NotebookLibraryCardLayout.gridCellHeight)
        .padding()
        .background(Color.clear)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        .contextMenu {
            if !isBulkSelectingSubtopics {
                notebookLibraryMenuActions(
                    allowsRename: !isReadOnlySharedNotebook,
                    showsShare: false,
                    onRename: {
                        subtopicForEdit = subtopic
                        isShowingEditSubtopicSheet = true
                    },
                    onShare: {},
                    onDelete: { subtopicToDelete = subtopic }
                )
            }
        }
    }
    
    private var addSubtopicButton: some View {
                Button(action: {
                    isShowingNewSubtopicSheet = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.appAccent1)
        }
    }
}

// MARK: - Subtopic Preview View
struct SubtopicPreviewView: View {
    let subtopic: Subtopic
    let topic: Topic
    @Binding var isPresented: Bool
    @EnvironmentObject var noteDisplayState: NoteDisplayState
    @ObservedObject var dataManager: DataManager
    var isReadOnlySharedNotebook: Bool = false
    @State private var isBulkSelectingNotes = false
    @State private var selectedNoteIdsForDeletion: Set<UUID> = []
    @State private var confirmBulkDeleteNotes = false
    @State private var isShowingNewNoteSheet = false
    @State private var newNoteDraftPhotos: [PendingNotePhoto] = []
    @State private var newNoteDraftBody: String = ""
    @State private var newNoteCameraPresented = false
    @State private var newNoteDocPickerPresented = false
    @State private var newNotePickedDocument: URL?
    @State private var newNoteDocImportError = false
    @State private var editedSubtopicTitle = ""
    @FocusState private var isSubtopicTitleFocused: Bool
    @State private var subtopicTitleHasChanges = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                headerView
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 0)
                    ], spacing: 6) {
                        ForEach(Array(subtopic.notes.enumerated()), id: \.element.id) { index, note in
                            Group {
                                if isBulkSelectingNotes {
                                    Button {
                                        if selectedNoteIdsForDeletion.contains(note.id) {
                                            selectedNoteIdsForDeletion.remove(note.id)
                                        } else {
                                            selectedNoteIdsForDeletion.insert(note.id)
                                        }
                                    } label: {
                                        ZStack(alignment: .topTrailing) {
                                            NoteCardView(note: note, dataManager: dataManager, expanded: true)
                                            bulkSelectionBadge(isSelected: selectedNoteIdsForDeletion.contains(note.id))
                                        }
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    NavigationLink(destination: NoteView(note: note, isPresented: $isPresented, dataManager: dataManager)
                                        .onAppear {
                                            Task {
                                                do {
                                                    if !isReadOnlySharedNotebook {
                                                        try await dataManager.addRecentNote(noteId: note.id.uuidString)
                                                    }
                                                    await MainActor.run {
                                                        noteDisplayState.currentNote = note
                                                        noteDisplayState.currentTopic = topic
                                                        noteDisplayState.currentSubtopic = subtopic
                                                        if isReadOnlySharedNotebook {
                                                            noteDisplayState.isReadOnlySharePresentation = true
                                                        }
                                                    }
                                                } catch {
                                                    print("Error updating recent notes: \(error)")
                                                }
                                            }
                                        }
                                        .onDisappear {
                                            noteDisplayState.currentNote = nil
                                        }
                                    ) {
                                        NoteCardView(note: note, dataManager: dataManager, expanded: true)
                                    }
                                }
                            }
                            .staggeredCardPopIn(delay: Double(index) * 0.045)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 20)
                }
                .overlay(alignment: .top) {
                    ScrollContentTopFade()
                }
                .overlay(alignment: .bottom) {
                    TabBarContentBottomFade()
                }
            }
            if !isBulkSelectingNotes, !isReadOnlySharedNotebook {
                Button(action: {
                    newNoteDraftPhotos = []
                    newNoteDraftBody = ""
                    isShowingNewNoteSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.appAccent1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 15)
                .padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isBulkSelectingNotes {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        Text("Tap notes to select")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Delete") {
                            confirmBulkDeleteNotes = true
                        }
                        .fontWeight(.semibold)
                        .disabled(selectedNoteIdsForDeletion.isEmpty)
                        .foregroundColor(selectedNoteIdsForDeletion.isEmpty ? Color(.systemGray3) : .red)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.appBackground)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $isShowingNewNoteSheet) {
            CreateNoteSheetView(
                isPresented: $isShowingNewNoteSheet,
                pendingPhotos: $newNoteDraftPhotos,
                noteBody: $newNoteDraftBody,
                dataManager: dataManager,
                initialTopic: topic,
                initialSubtopic: subtopic,
                onRequestCamera: { newNoteCameraPresented = true },
                onRequestDocument: { newNoteDocPickerPresented = true }
            )
        }
        .fullScreenCover(isPresented: $newNoteCameraPresented) {
            CameraView { image in
                if let image = image {
                    handleNewNoteCameraImage(image)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $newNoteDocPickerPresented) {
            DocumentPicker(selectedDocument: $newNotePickedDocument)
        }
        .onChange(of: newNotePickedDocument) { _, newValue in
            guard let url = newValue else { return }
            Task {
                await handleNewNotePickedDocument(url: url)
                await MainActor.run { newNotePickedDocument = nil }
            }
        }
        .alert("Couldn’t read file", isPresented: $newNoteDocImportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Try an image, PDF, or plain text.")
        }
        .onAppear {
            noteDisplayState.currentNote = nil
            syncSubtopicTitleFromDataManager()
        }
        .alert("Delete selected notes?", isPresented: $confirmBulkDeleteNotes) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                let ids = selectedNoteIdsForDeletion
                for id in ids {
                    guard let t = dataManager.topics.first(where: { $0.id == topic.id }),
                          let st = t.subtopics.first(where: { $0.id == subtopic.id }),
                          let n = st.notes.first(where: { $0.id == id }) else { continue }
                    dataManager.deleteNote(n, from: st, from: t)
                }
                selectedNoteIdsForDeletion = []
                isBulkSelectingNotes = false
            }
        } message: {
            Text("This will permanently remove \(selectedNoteIdsForDeletion.count) note(s).")
        }
    }

    private func mergeNewNoteDraft(photos: [PendingNotePhoto], text: String) {
        if isShowingNewNoteSheet {
            newNoteDraftPhotos.append(contentsOf: photos)
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty {
                if newNoteDraftBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    newNoteDraftBody = t
                } else {
                    newNoteDraftBody += "\n\n" + t
                }
            }
        } else {
            newNoteDraftPhotos = photos
            newNoteDraftBody = text
            isShowingNewNoteSheet = true
        }
    }

    private func handleNewNoteCameraImage(_ image: UIImage) {
        let entry = PendingNotePhoto(image: image, photoLibraryAssetId: nil)
        mergeNewNoteDraft(photos: [entry], text: "")
    }

    private func handleNewNotePickedDocument(url: URL) async {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsAccess { url.stopAccessingSecurityScopedResource() }
        }
        let (photos, text) = CreateNoteDraftDocument.load(url: url)
        await MainActor.run {
            if photos.isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                newNoteDocImportError = true
                return
            }
            mergeNewNoteDraft(photos: photos, text: text)
        }
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 4) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.appText)
                    .frame(width: 44, height: 44)
            }
            Group {
                if isReadOnlySharedNotebook {
                    Text(subtopic.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.appText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                } else {
                    TextField("Untitled", text: $editedSubtopicTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.appText)
                        .multilineTextAlignment(.center)
                        .focused($isSubtopicTitleFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.appText, lineWidth: 2)
                                .opacity(isSubtopicTitleFocused ? 1 : 0)
                        )
                        .animation(.easeInOut(duration: 0.25), value: isSubtopicTitleFocused)
                        .onChange(of: editedSubtopicTitle) { _, _ in subtopicTitleHasChanges = true }
                        .onChange(of: isSubtopicTitleFocused) { _, focused in
                            if !focused && subtopicTitleHasChanges { Task { await saveSubtopicTitleIfNeeded() } }
                        }
                        .disabled(isBulkSelectingNotes)
                }
            }
            .frame(maxWidth: .infinity)
            if isBulkSelectingNotes {
                Button("Cancel") {
                    isBulkSelectingNotes = false
                    selectedNoteIdsForDeletion = []
                }
                .font(.body.weight(.medium))
                .foregroundColor(.appAccent1)
                .frame(width: 60, alignment: .trailing)
            } else if isReadOnlySharedNotebook {
                Color.clear
                    .frame(width: 44, height: 44)
            } else {
                Menu {
                    Button(role: .destructive, action: {
                        selectedNoteIdsForDeletion = []
                        isBulkSelectingNotes = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.appText)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    private func syncSubtopicTitleFromDataManager() {
        if let t = dataManager.topics.first(where: { $0.id == topic.id }),
           let st = t.subtopics.first(where: { $0.id == subtopic.id }) {
            editedSubtopicTitle = st.title
        } else {
            editedSubtopicTitle = subtopic.title
        }
        subtopicTitleHasChanges = false
    }
    
    private func saveSubtopicTitleIfNeeded() async {
        guard !isReadOnlySharedNotebook else {
            await MainActor.run { subtopicTitleHasChanges = false }
            return
        }
        let trimmed = editedSubtopicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let t = dataManager.topics.first(where: { $0.id == topic.id }),
              let st = t.subtopics.first(where: { $0.id == subtopic.id }) else {
            await MainActor.run { subtopicTitleHasChanges = false }
            return
        }
        let newTitle = trimmed.isEmpty ? st.title : trimmed
        guard newTitle != st.title else {
            await MainActor.run {
                subtopicTitleHasChanges = false
                editedSubtopicTitle = st.title
            }
            return
        }
        do {
            try await dataManager.updateSubtopic(st, in: t, newTitle: newTitle)
            await MainActor.run {
                subtopicTitleHasChanges = false
                editedSubtopicTitle = newTitle
                if noteDisplayState.currentSubtopic?.id == subtopic.id,
                   let t2 = dataManager.topics.first(where: { $0.id == topic.id }),
                   let st2 = t2.subtopics.first(where: { $0.id == subtopic.id }) {
                    noteDisplayState.currentSubtopic = st2
                }
            }
        } catch {
            await MainActor.run {
                editedSubtopicTitle = st.title
                subtopicTitleHasChanges = false
            }
        }
    }
}

// MARK: - Stacked card preview note (image-first, then first text note)
private func resolvePreviewNoteForSubtopic(_ subtopic: Subtopic, dataManager: DataManager) async -> Note? {
    for note in subtopic.notes {
        do {
            let attachments = try await dataManager.getAttachments(forNoteId: note.id)
            if attachments.contains(where: { $0.isImageLike }) {
                return note
            }
        } catch {
            continue
        }
    }
    if let textNote = subtopic.notes.first(where: { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
        return textNote
    }
    return subtopic.notes.first
}

private func resolvePreviewNoteForTopic(_ topic: Topic, dataManager: DataManager) async -> Note? {
    let ordered = topic.subtopics.flatMap(\.notes)
    for note in ordered {
        do {
            let attachments = try await dataManager.getAttachments(forNoteId: note.id)
            if attachments.contains(where: { $0.isImageLike }) {
                return note
            }
        } catch {
            continue
        }
    }
    if let textNote = ordered.first(where: { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
        return textNote
    }
    return ordered.first
}

// MARK: - Subtopic Card Preview (stacked note preview only; title + menu live on the grid cell)
private struct SubtopicCardPreview: View {
    let subtopic: Subtopic
    @ObservedObject var dataManager: DataManager
    @Environment(\.colorScheme) var colorScheme
    @State private var thumbnailImage: UIImage?
    @State private var previewNote: Note?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(colorScheme == .dark ? .systemGray3 : .systemGray4))
                .frame(width: 160, height: 124)
                .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                .rotationEffect(.degrees(-6))
                .offset(x: -6, y: 4)
            cardMediaBlock
                .frame(width: 160, height: 124)
                .clipped()
                .cornerRadius(8)
        }
        .frame(width: 168, height: 130)
        .task(id: "\(subtopic.id.uuidString)-\(subtopic.notes.count)") {
            await MainActor.run {
                thumbnailImage = nil
                previewNote = nil
            }
            let resolved = await resolvePreviewNoteForSubtopic(subtopic, dataManager: dataManager)
            guard let note = resolved else { return }
            do {
                let attachments = try await dataManager.getAttachments(forNoteId: note.id)
                if let att = attachments.first(where: { $0.isImageLike }),
                   let image = await dataManager.loadUIImage(for: att) {
                    await MainActor.run {
                        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
                            previewNote = note
                            thumbnailImage = image
                        }
                    }
                    return
                }
            } catch {}
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                    previewNote = note
                    thumbnailImage = nil
                }
            }
        }
    }
    
    @ViewBuilder
    private var cardMediaBlock: some View {
        if let note = previewNote {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 124)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)),
                        removal: .opacity
                    ))
            } else if !note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(note.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(14)
                    .background(Color(.systemBackground))
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                placeholderBlock
            }
        } else {
            placeholderBlock
        }
    }
    
    private var placeholderBlock: some View {
        Color.white
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Topic Card View (All Notebooks — same stacked-card layout as SubtopicCardPreview)
private struct TopicCardPreview: View {
    let topic: Topic
    @ObservedObject var dataManager: DataManager
    @Environment(\.colorScheme) var colorScheme
    @State private var thumbnailImage: UIImage?
    @State private var previewNote: Note?

    private var orderedNotes: [Note] {
        topic.subtopics.flatMap(\.notes)
    }

    /// Rear “peek” card uses the notebook color; falls back to neutral gray if unset.
    private var stackedBackCardFill: Color {
        if let c = TopicColorStore.color(for: topic.id) {
            return c.opacity(colorScheme == .dark ? 0.55 : 0.72)
        }
        return Color(colorScheme == .dark ? .systemGray3 : .systemGray4)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(stackedBackCardFill)
                .frame(width: 160, height: 124)
                .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                .rotationEffect(.degrees(-6))
                .offset(x: -6, y: 4)
            cardMediaBlock
                .frame(width: 160, height: 124)
                .clipped()
                .cornerRadius(8)
        }
        .frame(width: 168, height: 130)
        .task(id: "\(topic.id.uuidString)-\(orderedNotes.count)") {
            await MainActor.run {
                thumbnailImage = nil
                previewNote = nil
            }
            let resolved = await resolvePreviewNoteForTopic(topic, dataManager: dataManager)
            guard let note = resolved else { return }
            do {
                let attachments = try await dataManager.getAttachments(forNoteId: note.id)
                if let att = attachments.first(where: { $0.isImageLike }),
                   let image = await dataManager.loadUIImage(for: att) {
                    await MainActor.run {
                        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
                            previewNote = note
                            thumbnailImage = image
                        }
                    }
                    return
                }
            } catch {}
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                    previewNote = note
                    thumbnailImage = nil
                }
            }
        }
    }

    @ViewBuilder
    private var cardMediaBlock: some View {
        if let note = previewNote {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 124)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)),
                        removal: .opacity
                    ))
            } else if !note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(note.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(14)
                    .background(Color(.systemBackground))
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                placeholderBlock
            }
        } else {
            placeholderBlock
        }
    }

    private var placeholderBlock: some View {
        Color.white
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NoteCardView: View {
    let note: Note
    @ObservedObject var dataManager: DataManager
    /// Full-width layout for single-column grids (e.g. subtopic note list).
    var expanded: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var thumbnailImage: UIImage?

    private var mediaHeight: CGFloat { expanded ? 240 : 168 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardMediaBlock
                .frame(minWidth: expanded ? 0 : 200, maxWidth: expanded ? .infinity : 160)
                .frame(height: mediaHeight)
                .clipped()
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                .shadow(color: Color.black.opacity(0.06), radius: 1, x: 0, y: 1)

            Group {
                if note.title.isEmpty {
                    Color.clear
                        .frame(height: expanded ? 0 : 40)
                } else {
                    Text(note.title)
                        .font(expanded ? .body : .subheadline)
                        .fontWeight(.regular)
                        .foregroundColor(Color(.secondaryLabel))
                        .lineLimit(expanded ? 4 : 2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(minHeight: expanded ? (note.title.isEmpty ? 0 : 48) : 40, maxHeight: expanded ? nil : 40)
        }
        .frame(maxWidth: expanded ? .infinity : nil)
        .frame(width: expanded ? nil : 160, height: expanded ? nil : 180)
        .padding(expanded ? EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12) : EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        .background(Color.clear)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        .task(id: note.id) {
            await loadThumbnail()
        }
    }

    @ViewBuilder
    private var cardMediaBlock: some View {
        if let image = thumbnailImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.94)),
                    removal: .opacity
                ))
        } else if !note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(note.content)
                .font(expanded ? .body : .subheadline)
                .foregroundColor(.secondary)
                .lineLimit(expanded ? 10 : 3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(expanded ? 18 : 14)
                .background(Color(colorScheme == .dark ? .systemGray5 : .systemGray6))
        } else {
            ZStack {
                Color(colorScheme == .dark ? .systemGray5 : .systemGray6)
                Image(systemName: "photo.on.rectangle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: expanded ? 56 : 40, height: expanded ? 56 : 40)
                    .foregroundColor(.gray.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func loadThumbnail() async {
        do {
            let attachments = try await dataManager.getAttachments(forNoteId: note.id)
            let imageAttachment = attachments.first(where: { $0.isImageLike })
            guard let att = imageAttachment else { return }
            guard let image = await dataManager.loadUIImage(for: att) else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
                    thumbnailImage = image
                }
            }
        } catch {
            // Ignore; card will show text preview or placeholder
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        // Try a fallback format if needed
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return fallbackFormatter.date(from: dateString)
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today at " + formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Yesterday at " + formatter.string(from: date)
        } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Notebook Empty State (match design: "Maybe what you need is some notes" + CREATE A NOTEBOOK)
struct NotebookEmptyStateView: View {
    let onCreateTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("The start of a beautiful journey!")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: onCreateTapped) {
                HStack(spacing: 10) {
                    Image(systemName: "circle.grid.2x2")
                        .font(.title2)
                        .foregroundColor(.appAccent1)
                    Text("CREATE A NOTEBOOK")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(.secondaryLabel))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.tertiarySystemFill))
                .cornerRadius(14)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack(alignment: .top) {
                Color(.systemBackground)
                LinearGradient(
                    colors: [
                        Color(hex: "E85D04"),
                        Color(hex: "FF9500").opacity(0.5),
                        Color(hex: "FF9500").opacity(0.4),
                        Color(hex: "FF9500").opacity(0.2),
                        Color(hex: "FF9500").opacity(0.1),
                        Color(hex: "FF9500").opacity(0.05),
                        Color(hex: "FF9500").opacity(0.01),
                        Color(hex: "FF9500").opacity(0.005),
                        Color(hex: "FF9500").opacity(0.002),
                        Color(hex: "FF9500").opacity(0.001),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)
                .ignoresSafeArea(edges: .top)
            }
        )
    }
}

// MARK: - Create New Notebook Flow (step 1: name → step 2: pick color → save) — full view with fade
struct CreateNewNotebookFlowView: View {
    private static let searchBarHeight: CGFloat = 52
    private static let searchBarCornerRadius: CGFloat = 12
    
    @Binding var isPresented: Bool
    @ObservedObject var dataManager: DataManager
    @State private var step: CreateNotebookStep = .name
    @State private var spaceName: String = ""
    @State private var selectedColorIndex: Int = 0
    @State private var isSaving = false
    
    enum CreateNotebookStep {
        case name
        case color
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            ZStack {
                if step == .name {
                    createNewSpaceStep
                        .transition(.opacity)
                } else {
                    pickColorStep
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: step)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }
        }
    }
    
    private var createNewSpaceStep: some View {
        VStack(spacing: 24) {
            Spacer()
            CreationBadgeIconView()
            Text("Create new notebook")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Text("Upload directly into a notebook, or pick a note from the overview.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            TextField("Name your new notebook", text: $spaceName)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .frame(height: Self.searchBarHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: Self.searchBarCornerRadius)
                        .stroke(Color(hex: "C6C6CB").opacity(0.5), lineWidth: 0.5)
                )
                .padding(.horizontal, 32)
                .padding(.top, 8)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.35)) { step = .color }
            }) {
                Text("NEXT STEP")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color(.tertiaryLabel))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .disabled(spaceName.trimmingCharacters(in: .whitespaces).isEmpty)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var pickColorStep: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Pick a color")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Text("Color coding your space helps you to spot it a lot easier when you need it.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            colorWheel
            Button(action: finishAndSave) {
                Text("FINISH & SAVE")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.appAccent1)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            if isSaving {
                ProgressView()
                    .padding(.top, 4)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var colorWheel: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(0..<16, id: \.self) { index in
                Circle()
                    .strokeBorder(
                        Color(hex: notebookColorPalette[index]),
                        lineWidth: selectedColorIndex == index ? 6 : 2
                    )
                    .background(Circle().fill(Color(.systemBackground)))
                    .frame(width: 44, height: 44)
                    .scaleEffect(selectedColorIndex == index ? 1.08 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.8), value: selectedColorIndex)
                    .onTapGesture { selectedColorIndex = index }
            }
        }
        .padding(.horizontal, 48)
    }
    
    private func finishAndSave() {
        let name = spaceName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isSaving = true
        Task {
            do {
                let topic = try await dataManager.addTopic(title: name)
                TopicColorStore.setColorHex(notebookColorPalette[selectedColorIndex], for: topic.id)
                await dataManager.loadTopics()
                await MainActor.run {
                    isPresented = false
                }
            } catch {
                await MainActor.run { isSaving = false }
            }
        }
    }
}

// MARK: - Notebook View

private enum NotebookLibrarySectionFilter: Equatable {
    case all
    case mineOnly
    case sharedOnly
}

struct NotebookView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var noteDisplayState: NoteDisplayState
    @StateObject private var searchState = SearchState()
    @StateObject private var dataManager = DataManager.shared
    @Binding var isPresented: Bool
    @State private var topicPresentedFromQR: Topic?
    @State private var selectedTopic: Topic?
    @State private var selectedSubtopic: Subtopic?
    @State private var isShowingNewTopicSheet = false
    @State private var isShowingCreateNewNotebookFlow = false
    @State private var isShowingNewSubtopicSheet = false
    @State private var isShowingNewNoteSheet = false
    @State private var topicToDelete: Topic?
    @State private var subtopicToDelete: (Topic, Subtopic)?
    @State private var noteToDelete: (Topic, Subtopic, Note)?
    @State private var isShowingEditTopicSheet = false
    @State private var isShowingEditSubtopicSheet = false
    /// Tap the section title to cycle: All → My → Shared → All (skips empty legs).
    @State private var librarySectionFilter: NotebookLibrarySectionFilter = .all
    /// Bumps on every real filter change so grid `.id` never repeats when cycling back to the same mode (.all, etc.).
    @State private var libraryGridAnimationEpoch = 0
    @State private var sharedEntryToDelete: SavedSharedNotebookEntry?
    @State private var isShowingLibraryShareSheet = false
    @State private var libraryShareSheetURL: String?
    @State private var libraryShareSheetTitle = ""

    private var hasNotebookLibraryContent: Bool {
        !dataManager.topics.isEmpty || !dataManager.savedSharedNotebookEntries.isEmpty
    }

    private var hasSharedNotebookEntries: Bool {
        !dataManager.savedSharedNotebookEntries.isEmpty
    }

    private var hasOwnedNotebooks: Bool {
        !dataManager.topics.isEmpty
    }

    private var librarySectionTitle: String {
        switch librarySectionFilter {
        case .all: return "All Notebooks"
        case .mineOnly: return "My Notebooks"
        case .sharedOnly: return "Shared Notebooks"
        }
    }

    private func updateLibrarySectionFilter(_ new: NotebookLibrarySectionFilter) {
        guard new != librarySectionFilter else { return }
        librarySectionFilter = new
        libraryGridAnimationEpoch += 1
    }

    private func advanceNotebookLibrarySectionFilter() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            let hasMine = hasOwnedNotebooks
            let hasShared = hasSharedNotebookEntries
            switch librarySectionFilter {
            case .all:
                if hasMine {
                    updateLibrarySectionFilter(.mineOnly)
                } else if hasShared {
                    updateLibrarySectionFilter(.sharedOnly)
                }
            case .mineOnly:
                if hasShared {
                    updateLibrarySectionFilter(.sharedOnly)
                } else {
                    updateLibrarySectionFilter(.all)
                }
            case .sharedOnly:
                updateLibrarySectionFilter(.all)
            }
        }
    }

    private func libraryFilterAccessibilityHint() -> String {
        switch librarySectionFilter {
        case .all: return "Show my notebooks only"
        case .mineOnly: return hasSharedNotebookEntries ? "Show shared notebooks only" : "Show all notebooks"
        case .sharedOnly: return "Show all notebooks"
        }
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    if !hasNotebookLibraryContent {
                        NotebookEmptyStateView(onCreateTapped: {
                            isShowingCreateNewNotebookFlow = true
                        })
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                Button(action: advanceNotebookLibrarySectionFilter) {
                                    HStack(spacing: 8) {
                                        Text(librarySectionTitle)
                                            .font(.headline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        Image(systemName: "line.3.horizontal.decrease.circle")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.appAccent1.opacity(0.9))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint(libraryFilterAccessibilityHint())
                                .disabled(!hasOwnedNotebooks && !hasSharedNotebookEntries)

                                LazyVGrid(columns: [
                                    GridItem(.fixed(200), spacing: 2),
                                    GridItem(.fixed(200), spacing: 2)
                                ], spacing: 2) {
                                    if librarySectionFilter != .sharedOnly {
                                        ForEach(Array(dataManager.topics.enumerated()), id: \.element.id) { index, topic in
                                            let displayTitle = dataManager.topics.first(where: { $0.id == topic.id })?.title ?? topic.title
                                            VStack(spacing: 8) {
                                                NavigationLink(
                                                    destination: TopicPreviewView(
                                                        topic: topic,
                                                        isReadOnlySharedNotebook: false,
                                                        isPresented: $isPresented,
                                                        dataManager: dataManager
                                                    )
                                                    .environmentObject(searchState)
                                                ) {
                                                    TopicCardPreview(topic: topic, dataManager: dataManager)
                                                }
                                                .buttonStyle(.plain)

                                                NotebookLibraryCardTitleRow(
                                                    title: displayTitle,
                                                    allowsRename: true,
                                                    onRename: { beginRenameOwnedTopic(topic) },
                                                    onDelete: { topicToDelete = topic },
                                                    onShare: { presentShareSheetForOwnedTopic(topic) }
                                                )
                                            }
                                            .frame(width: 168, height: NotebookLibraryCardLayout.gridCellHeight)
                                            .padding()
                                            .background(Color.clear)
                                            .cornerRadius(14)
                                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                                            .staggeredCardPopIn(delay: Double(index) * 0.04, style: .bounce)
                                            // Identity includes a monotonic epoch so returning to .all still replays the pop-in.
                                            .id("owned-\(topic.id)-\(libraryGridAnimationEpoch)")
                                            .contextMenu {
                                                notebookLibraryMenuActions(
                                                    allowsRename: true,
                                                    onRename: { beginRenameOwnedTopic(topic) },
                                                    onShare: { presentShareSheetForOwnedTopic(topic) },
                                                    onDelete: { topicToDelete = topic }
                                                )
                                            }
                                        }
                                    }
                                    if librarySectionFilter != .mineOnly {
                                        ForEach(Array(dataManager.savedSharedNotebookEntries.enumerated()), id: \.element.id) { index, entry in
                                            VStack(spacing: 8) {
                                                NavigationLink(
                                                    destination: SharedNotebookDetailLoaderView(entry: entry, dataManager: dataManager)
                                                        .environmentObject(searchState)
                                                        .environmentObject(noteDisplayState)
                                                ) {
                                                    SharedNotebookLibraryCardPreview(entry: entry)
                                                }
                                                .buttonStyle(.plain)

                                                NotebookLibraryCardTitleRow(
                                                    title: entry.title,
                                                    allowsRename: false,
                                                    onRename: {},
                                                    onDelete: { sharedEntryToDelete = entry },
                                                    onShare: { presentShareSheetForSharedNotebook(entry) }
                                                )
                                            }
                                            .frame(width: 168, height: NotebookLibraryCardLayout.gridCellHeight)
                                            .padding()
                                            .background(Color.clear)
                                            .cornerRadius(14)
                                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                                            .staggeredCardPopIn(
                                                delay: Double(
                                                    (librarySectionFilter == .all ? dataManager.topics.count : 0) + index
                                                ) * 0.04,
                                                style: .bounce
                                            )
                                            .id("shared-\(entry.id)-\(libraryGridAnimationEpoch)")
                                            .contextMenu {
                                                notebookLibraryMenuActions(
                                                    allowsRename: false,
                                                    onRename: {},
                                                    onShare: { presentShareSheetForSharedNotebook(entry) },
                                                    onDelete: { sharedEntryToDelete = entry }
                                                )
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical)
                        }
                        .background(Color.appBackground)
                        .onChange(of: dataManager.savedSharedNotebookEntries.count) { _, count in
                            if librarySectionFilter == .sharedOnly && count == 0 {
                                updateLibrarySectionFilter(.all)
                            }
                        }
                        .onChange(of: dataManager.topics.count) { _, count in
                            if librarySectionFilter == .mineOnly && count == 0 {
                                updateLibrarySectionFilter(hasSharedNotebookEntries ? .sharedOnly : .all)
                            }
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    TabBarContentBottomFade()
                }
                if hasNotebookLibraryContent {
                    Button(action: { isShowingCreateNewNotebookFlow = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.appAccent1)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 30)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $isShowingCreateNewNotebookFlow) {
                CreateNewNotebookFlowView(isPresented: $isShowingCreateNewNotebookFlow, dataManager: dataManager)
            }
            .sheet(isPresented: $isShowingNewTopicSheet) {
                NewTopicView(dataManager: dataManager)
            }
            .fullScreenCover(isPresented: $isShowingNewSubtopicSheet) {
                if let topic = selectedTopic {
                    NewSubtopicView(topic: topic, dataManager: dataManager)
                }
            }
            .sheet(isPresented: $isShowingNewNoteSheet) {
                if let topic = selectedTopic, let subtopic = selectedSubtopic {
                    NewNoteView(topic: topic, subtopic: subtopic, dataManager: dataManager)
                }
            }
            .sheet(isPresented: $isShowingEditTopicSheet) {
                if let topic = selectedTopic {
                    EditTopicView(topic: topic, dataManager: dataManager)
                }
            }
            .sheet(isPresented: $isShowingEditSubtopicSheet) {
                if let topic = selectedTopic, let subtopic = selectedSubtopic {
                    EditSubtopicView(subtopic: subtopic, topic: topic, dataManager: dataManager)
                }
            }
            .alert("Delete Topic", isPresented: .init(
                get: { topicToDelete != nil },
                set: { if !$0 { topicToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    topicToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let topic = topicToDelete {
                        dataManager.deleteTopic(topic)
                    }
                    topicToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this topic? This will also delete all its subtopics and notes.")
            }
            .alert("Delete Subtopic", isPresented: .init(
                get: { subtopicToDelete != nil },
                set: { if !$0 { subtopicToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    subtopicToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let (topic, subtopic) = subtopicToDelete {
                        dataManager.deleteSubtopic(subtopic, from: topic)
                    }
                    subtopicToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this subtopic? This will also delete all its notes.")
            }
            .alert("Delete Note", isPresented: .init(
                get: { noteToDelete != nil },
                set: { if !$0 { noteToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    noteToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let (topic, subtopic, note) = noteToDelete {
                        dataManager.deleteNote(note, from: subtopic, from: topic)
                    }
                    noteToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this note?")
            }
            .alert("Remove notebook?", isPresented: .init(
                get: { sharedEntryToDelete != nil },
                set: { if !$0 { sharedEntryToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    sharedEntryToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let entry = sharedEntryToDelete {
                        Task {
                            await dataManager.removeSavedSharedNotebook(shareToken: entry.shareToken)
                        }
                    }
                    sharedEntryToDelete = nil
                }
            } message: {
                if let entry = sharedEntryToDelete {
                    Text("Remove “\(entry.title)” from your notebooks? The shared notebook will still be available via its link.")
                }
            }
            .fullScreenCover(isPresented: $isShowingLibraryShareSheet, onDismiss: {
                libraryShareSheetURL = nil
                libraryShareSheetTitle = ""
            }) {
                if let url = libraryShareSheetURL {
                    ShareQRSheetView(
                        title: libraryShareSheetTitle,
                        inviteURL: url,
                        isPresented: $isShowingLibraryShareSheet
                    )
                }
            }
            .onAppear { presentTopicFromPendingQRIfNeeded() }
            .onChange(of: noteDisplayState.pendingNotebookTopicToPresent?.id) { _, _ in
                presentTopicFromPendingQRIfNeeded()
            }
            .fullScreenCover(item: $topicPresentedFromQR) { topic in
                TopicPreviewView(
                    topic: topic,
                    isReadOnlySharedNotebook: false,
                    isPresented: Binding(
                        get: { topicPresentedFromQR != nil },
                        set: { if !$0 { topicPresentedFromQR = nil } }
                    ),
                    dataManager: dataManager
                )
                .environmentObject(searchState)
            }
        }
        .background(Color.appBackground)
        .environmentObject(searchState)
    }

    private func presentTopicFromPendingQRIfNeeded() {
        guard let topic = noteDisplayState.pendingNotebookTopicToPresent else { return }
        topicPresentedFromQR = topic
        noteDisplayState.pendingNotebookTopicToPresent = nil
    }

    private func beginRenameOwnedTopic(_ topic: Topic) {
        selectedTopic = topic
        isShowingEditTopicSheet = true
    }

    private func presentShareSheetForOwnedTopic(_ topic: Topic) {
        Task {
            do {
                let token = try await dataManager.ensureActiveTopicShareLink(forTopicId: topic.id)
                let title = dataManager.topics.first(where: { $0.id == topic.id })?.title ?? topic.title
                await MainActor.run {
                    libraryShareSheetTitle = title
                    libraryShareSheetURL = NoteShareInviteURL.httpsNotebookInviteURL(for: token)
                    isShowingLibraryShareSheet = true
                }
            } catch { }
        }
    }

    private func presentShareSheetForSharedNotebook(_ entry: SavedSharedNotebookEntry) {
        libraryShareSheetTitle = entry.title
        libraryShareSheetURL = NoteShareInviteURL.httpsNotebookInviteURL(for: entry.shareToken)
        isShowingLibraryShareSheet = true
    }
}

struct SubtopicRow: View {
    let subtopic: Subtopic
    let topic: Topic
    @Binding var selectedSubtopic: Subtopic?
    @Binding var selectedNote: Note?
    @Binding var isPresented: Bool
    @ObservedObject var dataManager: DataManager
    @Binding var subtopicToDelete: (Topic, Subtopic)?
    @Binding var noteToDelete: (Topic, Subtopic, Note)?
    var isExpanded: Bool
    var onExpandChange: (Bool, UUID) -> Void
    var searchText: String
    @Binding var isShowingEditSubtopicSheet: Bool
    @Binding var isShowingNewSubtopicSheet: Bool
    @Binding var selectedTopic: Topic?
    @State private var localIsExpanded: Bool = false
    @State private var isActive = false
    @State private var isShowingNewNoteSheet = false

    var body: some View {
        DisclosureGroup(isExpanded: Binding(
            get: { isExpanded },
            set: { newValue in
                localIsExpanded = newValue
                onExpandChange(newValue, subtopic.id)
            }
        )) {
            ForEach(subtopic.notes) { note in
                NoteRow(
                    note: note,
                    topic: topic,
                    subtopic: subtopic,
                    selectedNote: $selectedNote,
                    isPresented: $isPresented,
                    dataManager: dataManager,
                    noteToDelete: $noteToDelete
                )
                .padding(.leading, 16)
            }
        } label: {
            NavigationLink(
                destination: SubtopicPreviewView(subtopic: subtopic, topic: topic, isPresented: $isPresented, dataManager: dataManager),
                isActive: $isActive
            ) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.appAccent2)
                    HighlightedText(text: subtopic.title, searchText: searchText)
                        .font(.subheadline)
                    Spacer()
                    Text("\(subtopic.notes.count)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.appTextSecondary)
                        .padding(.trailing, 8)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedSubtopic = subtopic
                    selectedTopic = topic
                    isActive = true
                }
            }
            .buttonStyle(PlainButtonStyle())
            .contextMenu {
                Button(action: {
                    selectedSubtopic = subtopic
                    selectedTopic = topic
                    isShowingEditSubtopicSheet = true
                }) {
                    Label("Edit Subtopic", systemImage: "pencil")
                }
                Button(role: .destructive, action: {
                    subtopicToDelete = (topic, subtopic)
                }) {
                    Label("Delete Subtopic", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $isShowingNewNoteSheet) {
            if let selectedTopic = selectedTopic, let selectedSubtopic = selectedSubtopic {
                NewNoteView(topic: selectedTopic, subtopic: selectedSubtopic, dataManager: dataManager)
            }
        }
    }
}

struct NoteRow: View {
    let note: Note
    let topic: Topic
    let subtopic: Subtopic
    @Binding var selectedNote: Note?
    @Binding var isPresented: Bool
    @ObservedObject var dataManager: DataManager
    @Binding var noteToDelete: (Topic, Subtopic, Note)?
    @EnvironmentObject var searchState: SearchState
    @EnvironmentObject var noteDisplayState: NoteDisplayState

    var body: some View {
        HStack {
            Image(systemName: "note.text")
                .foregroundColor(.appAccent2)
                .accessibilityHidden(true)
            HighlightedText(text: note.title, searchText: searchState.searchText)
                .font(.subheadline)
                .accessibilityLabel("Note: \(note.title)")
                .accessibilityHint("Double tap to open note")
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            Task {
                do {
                    try await dataManager.addRecentNote(noteId: note.id.uuidString)
                    await MainActor.run {
                        noteDisplayState.currentNote = note
                        noteDisplayState.currentTopic = topic
                        noteDisplayState.currentSubtopic = subtopic
                        noteDisplayState.isShowingNote = true
                    }
                } catch {
                    print("Error updating recent notes: \(error)")
                }
            }
        }
        .contextMenu {
            Button(role: .destructive, action: {
                noteToDelete = (topic, subtopic, note)
            }) {
                Label("Delete Note", systemImage: "trash")
            }
            .accessibilityLabel("Delete note")
            .accessibilityHint("Double tap to delete this note")
        }
    }
}

struct NoteDetailView: View {
    let note: Note
    @EnvironmentObject var searchState: SearchState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HighlightedText(text: note.title, searchText: searchState.searchText)
                    .font(.title)
                    .fontWeight(.bold)
                
                HighlightedText(text: note.content, searchText: searchState.searchText)
                    .font(.body)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

struct NewTopicView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var dataManager: DataManager
    @State private var title = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isQuickNote = false
    @State private var subtopicTitle = ""
    @State private var noteTitle = ""
    @State private var noteContent = ""
    @EnvironmentObject var noteDisplayState: NoteDisplayState
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Topic Title", text: $title)
                }
                
                if isQuickNote {
                    Section(header: Text("Quick Note Details")) {
                        TextField("Subtopic Title", text: $subtopicTitle)
                        TextField("Note Title", text: $noteTitle)
                        TextEditor(text: $noteContent)
                            .frame(height: 100)
                    }
                }
                
                Section {
                    Toggle("Create Quick Note", isOn: $isQuickNote)
                }
            }
            .navigationTitle("New Topic")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Add") {
                    Task {
                        await saveTopic()
                    }
                }
                .disabled(title.isEmpty || isSaving || (isQuickNote && (subtopicTitle.isEmpty || noteTitle.isEmpty)))
            )
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func saveTopic() async {
        isSaving = true
        do {
            let newTopic = try await dataManager.addTopic(title: title)
            
            if isQuickNote {
                let newSubtopic = try await dataManager.addSubtopic(to: newTopic, title: subtopicTitle)
                let newNote = try await dataManager.addNote(
                    to: newSubtopic,
                    in: newTopic,
                    title: noteTitle,
                    content: noteContent
                )
                
                // Reload topics to ensure we have the latest data
                await dataManager.loadTopics()
                
                await MainActor.run {
                    noteDisplayState.currentTopic = newTopic
                    noteDisplayState.currentSubtopic = newSubtopic
                    noteDisplayState.currentNote = newNote
                    noteDisplayState.isShowingNote = true
                    dismiss()
                }
            } else {
                // Reload topics to ensure we have the latest data
                await dataManager.loadTopics()
                await MainActor.run {
                    dismiss()
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        isSaving = false
    }
}

struct NewSubtopicView: View {
    @Environment(\.dismiss) var dismiss
    let topic: Topic
    @ObservedObject var dataManager: DataManager
    @State private var title = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                CreationBadgeIconView()

                Text("Create new subtopic")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("Add a subtopic inside \(topic.title) to organize your notes.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                TextField("Name your new subtopic", text: $title)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "C6C6CB").opacity(0.5), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                Button("CREATE SUBTOPIC") {
                    Task {
                        await saveSubtopic()
                    }
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.appAccent1)
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)

                if isSaving {
                    ProgressView()
                        .padding(.top, 4)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func saveSubtopic() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        isSaving = true
        do {
            _ = try await dataManager.addSubtopic(to: topic, title: trimmedTitle)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        isSaving = false
    }
}

struct NewNoteView: View {
    @Environment(\.dismiss) var dismiss
    let topic: Topic
    let subtopic: Subtopic
    @ObservedObject var dataManager: DataManager
    @State private var title = ""
    @State private var content = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Note Title", text: $title)
                TextEditor(text: $content)
                    .frame(height: 200)
            }
            .navigationTitle("New Note")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Add") {
                    Task {
                        await saveNote()
                    }
                }
                .disabled(title.isEmpty || isSaving)
            )
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func saveNote() async {
        isSaving = true
        do {
            _ = try await dataManager.addNote(to: subtopic, in: topic, title: title, content: content)
            await MainActor.run {
                dismiss()
                // Play completion sound
                print("🎵 About to play completion sound for NewNoteView")
                SoundManager.shared.playCompletionSound()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        isSaving = false
    }
}

struct EditTopicView: View {
    @Environment(\.dismiss) var dismiss
    let topic: Topic
    @ObservedObject var dataManager: DataManager
    @State private var title: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    init(topic: Topic, dataManager: DataManager) {
        self.topic = topic
        self.dataManager = dataManager
        self._title = State(initialValue: topic.title)
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Topic Title", text: $title)
            }
            .navigationTitle("Edit Topic")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    Task {
                        await saveTopic()
                    }
                }
                .disabled(title.isEmpty || isSaving)
            )
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func saveTopic() async {
        isSaving = true
        do {
            try await dataManager.updateTopic(topic, newTitle: title)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        isSaving = false
    }
}

struct EditSubtopicView: View {
    @Environment(\.dismiss) var dismiss
    let subtopic: Subtopic
    let topic: Topic
    @ObservedObject var dataManager: DataManager
    @State private var title: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    init(subtopic: Subtopic, topic: Topic, dataManager: DataManager) {
        self.subtopic = subtopic
        self.topic = topic
        self.dataManager = dataManager
        self._title = State(initialValue: subtopic.title)
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Subtopic Title", text: $title)
            }
            .navigationTitle("Edit Subtopic")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    Task {
                        await saveSubtopic()
                    }
                }
                .disabled(title.isEmpty || isSaving)
            )
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func saveSubtopic() async {
        isSaving = true
        do {
            try await dataManager.updateSubtopic(subtopic, in: topic, newTitle: title)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        isSaving = false
    }
}

struct NotebookView_Previews: PreviewProvider {
    static var previews: some View {
        NotebookView(isPresented: .constant(true))
            .environmentObject(NoteDisplayState())
    }
}
