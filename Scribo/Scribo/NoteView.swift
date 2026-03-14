import SwiftUI
import UIKit

// MARK: - Dominant color from image (Instagram stories–style background)
private func extractDominantColor(from image: UIImage) -> Color? {
    guard let cgImage = image.cgImage else { return nil }
    let width = min(cgImage.width, 20)
    let height = min(cgImage.height, 20)
    let size = CGSize(width: width, height: height)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else { return nil }
    context.draw(cgImage, in: CGRect(origin: .zero, size: size))
    guard let data = context.data else { return nil }
    let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
    var r: Double = 0, g: Double = 0, b: Double = 0
    let count = width * height
    for i in 0..<count {
        let offset = i * 4
        r += Double(buffer[offset]) / 255.0
        g += Double(buffer[offset + 1]) / 255.0
        b += Double(buffer[offset + 2]) / 255.0
    }
    r /= Double(count)
    g /= Double(count)
    b /= Double(count)
    return Color(red: r, green: g, blue: b)
}

struct ClearBackgroundTextEditor: UIViewRepresentable {
    @Binding var text: String
    var font: UIFont?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear  // Make UITextView background clear here
        textView.isScrollEnabled = true
        textView.font = font ?? UIFont.preferredFont(forTextStyle: .body)
        textView.textColor = UIColor.label
        textView.text = text
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.font = font ?? UIFont.preferredFont(forTextStyle: .body)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: ClearBackgroundTextEditor
        init(parent: ClearBackgroundTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

struct NoteView: View {
    @EnvironmentObject var noteDisplayState: NoteDisplayState
    @Binding var isPresented: Bool
    @ObservedObject var dataManager: DataManager
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var isFromChatView: Bool = false

    @State private var editedTitle: String
    @State private var editedContent: String
    @State private var tags: [String] = ["Note"]
    @State private var mindNotesText: String = ""
    @State private var showAddTagAlert = false
    @State private var newTagText = ""
    @State private var showDeleteConfirm = false
    @State private var showShareQR = false
    @State private var lastSavedText = "Just now"
    @State private var showingSaveAlert = false
    @State private var hasChanges: Bool = false
    @State private var noteImages: [UIImage] = []
    @State private var dominantColor: Color?
    @State private var selectedImageIndex: Int = 0
    @FocusState private var isTitleFocused: Bool

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    let isNewNote: Bool

    init(note: Note?, isPresented: Binding<Bool>, dataManager: DataManager) {
        self._isPresented = isPresented
        self._editedTitle = State(initialValue: note?.title ?? "")
        self._editedContent = State(initialValue: note?.content ?? "")
        self.isNewNote = note == nil
        self.dataManager = dataManager
        self._isFromChatView = State(initialValue: isPresented.wrappedValue)
    }

    // Match EverythingCardSheetView styling
    private var cardBg: Color { Color(red: 0.98, green: 0.98, blue: 0.99) }
    private var sheetBg: Color { Color(red: 0.95, green: 0.95, blue: 0.97) }

    var body: some View {
        ZStack {
            sheetBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    headerView
                    mainContentView
                    mindTagsSection
                    mindNotesSection
                    Spacer(minLength: 24)
                    bottomBarView
                    statusView
                }
            }
        }
        .background(sheetBg)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .alert("Save Changes?", isPresented: $showingSaveAlert) {
            Button("Don't Save", role: .destructive) {
                if isFromChatView {
                    noteDisplayState.isShowingNote = false
                    noteDisplayState.currentNote = nil
                    noteDisplayState.currentTopic = nil
                    noteDisplayState.currentSubtopic = nil
                } else {
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                Task {
                    await saveNote()
                    if isFromChatView {
                        noteDisplayState.isShowingNote = false
                        noteDisplayState.currentNote = nil
                        noteDisplayState.currentTopic = nil
                        noteDisplayState.currentSubtopic = nil
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .alert("Add tag", isPresented: $showAddTagAlert) {
            TextField("Tag name", text: $newTagText)
            Button("Cancel", role: .cancel) { newTagText = "" }
            Button("Add") {
                let t = newTagText.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { tags.append(t) }
                newTagText = ""
            }
        } message: {
            Text("Enter a tag for this note.")
        }
        .alert("Delete Note", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let topic = noteDisplayState.currentTopic,
                   let subtopic = noteDisplayState.currentSubtopic,
                   let note = noteDisplayState.currentNote {
                    dataManager.deleteNote(note, from: subtopic, from: topic)
                }
                if isFromChatView {
                    noteDisplayState.isShowingNote = false
                    noteDisplayState.currentNote = nil
                    noteDisplayState.currentTopic = nil
                    noteDisplayState.currentSubtopic = nil
                } else {
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete this note?")
        }
        .fullScreenCover(isPresented: $showShareQR) {
            ShareQRSheetView(
                title: editedTitle.isEmpty ? "Untitled" : editedTitle,
                inviteURL: noteDisplayState.currentNote.map { "https://scribo.app/note/\($0.id.uuidString)" } ?? "https://scribo.app",
                isPresented: $showShareQR
            )
        }
        .task(id: noteDisplayState.currentNote?.id) {
            await loadNoteImages()
        }
    }

    private var headerView: some View {
        HStack {
            Button(action: {
                if hasChanges {
                    showingSaveAlert = true
                } else {
                    if isFromChatView {
                        noteDisplayState.isShowingNote = false
                        noteDisplayState.currentNote = nil
                        noteDisplayState.currentTopic = nil
                        noteDisplayState.currentSubtopic = nil
                    } else {
                        dismiss()
                    }
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.appText)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            TextField("Untitled", text: $editedTitle)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.appText)
                .multilineTextAlignment(.center)
                .focused($isTitleFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.appAccent1, lineWidth: 2)
                        .opacity(isTitleFocused ? 1 : 0)
                )
                .animation(.easeInOut(duration: 0.25), value: isTitleFocused)
                .onChange(of: editedTitle) { _, _ in hasChanges = true }
                .onChange(of: isTitleFocused) { _, focused in
                    if !focused && hasChanges { Task { await saveNote() } }
                }
            Spacer()
            Menu {
                Button(action: { showShareQR = true }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive, action: { showDeleteConfirm = true }) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.appText)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(sheetBg)
    }

    private var mainContentView: some View {
        Group {
            if noteImages.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                    TextEditor(text: $editedContent)
                        .font(.body)
                        .foregroundColor(.appText)
                        .scrollContentBackground(.hidden)
                        .frame(maxWidth: .infinity, minHeight: 252, alignment: .topLeading)
                        .padding(16)
                        .onChange(of: editedContent) { _, _ in hasChanges = true }
                    Divider()
                }
                .background(sheetBg)
            } else {
                imageMainContent
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var imageMainContent: some View {
        let fillColor = dominantColor ?? sheetBg
        return VStack(spacing: 0) {
            Divider()
            ZStack {
                fillColor
                    .ignoresSafeArea(edges: .horizontal)
                if noteImages.count == 1 {
                    imageCard(noteImages[0])
                } else {
                    TabView(selection: $selectedImageIndex) {
                        ForEach(Array(noteImages.enumerated()), id: \.offset) { index, img in
                            imageCard(img)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(0..<noteImages.count, id: \.self) { index in
                                Circle()
                                    .fill(index == selectedImageIndex ? Color.white : Color.white.opacity(0.4))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.bottom, 12)
                    }
                }
            }
            .frame(minHeight: 280)
            Divider()
        }
        .background(sheetBg)
    }

    private func imageCard(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
    }

    private var mindTagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NOTE TAGS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.appTextSecondary)
            HStack(spacing: 10) {
                Button(action: { showAddTagAlert = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Add tag")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.appAccent1)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                ForEach(tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.subheadline)
                        .foregroundColor(.appTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(cardBg)
                        .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    private var mindNotesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EXTRA NOTES")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.appTextSecondary)
            Group {
                if noteImages.isEmpty {
                    TextField("Type here to add a note...", text: $mindNotesText, axis: .vertical)
                } else {
                    TextField("Type here to add a note...", text: $editedContent, axis: .vertical)
                }
            }
            .textFieldStyle(.plain)
            .foregroundColor(.appText)
            .lineLimit(3...8)
            .padding(12)
            .background(cardBg)
            .cornerRadius(12)
            .onChange(of: editedContent) { _, _ in if !noteImages.isEmpty { hasChanges = true } }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var bottomBarView: some View {
        HStack(spacing: 10) {
            Button(action: {
                Task { await saveNote() }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "circle.grid.2x2")
                        .font(.system(size: 16))
                    Text("Save")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.appText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(cardBg)
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            Button(action: { showShareQR = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                    Text("Share")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.appText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(cardBg)
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            if !isNewNote {
                Button(action: { showDeleteConfirm = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                        Text("Delete")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var statusView: some View {
        Text("Saved to your notebook, \(lastSavedText)")
            .font(.caption)
            .foregroundColor(.appTextSecondary)
            .padding(.vertical, 12)
    }

    private func loadNoteImages() async {
        guard let noteId = noteDisplayState.currentNote?.id else {
            await MainActor.run {
                noteImages = []
                dominantColor = nil
                selectedImageIndex = 0
            }
            return
        }
        do {
            let attachments = try await dataManager.getAttachments(forNoteId: noteId)
            let imageAttachments = attachments.filter { att in
                let mime = att.mime_type?.lowercased() ?? ""
                return mime.hasPrefix("image/") || att.kind.lowercased() == "photo" || att.kind.lowercased() == "camera" || att.kind.lowercased() == "scanned"
            }
            let dir = dataManager.getDocumentsDirectory()
            var loaded: [UIImage] = []
            for att in imageAttachments {
                let fileURL = dir.appendingPathComponent(att.storage_path)
                guard FileManager.default.fileExists(atPath: fileURL.path),
                      let data = try? Data(contentsOf: fileURL),
                      let image = UIImage(data: data) else { continue }
                loaded.append(image)
            }
            var color: Color?
            if let first = loaded.first {
                color = extractDominantColor(from: first)
            }
            await MainActor.run {
                noteImages = loaded
                dominantColor = color
                selectedImageIndex = 0
            }
        } catch {
            await MainActor.run {
                noteImages = []
                dominantColor = nil
            }
        }
    }

    private func saveNote() async {
        do {
            guard let topic = noteDisplayState.currentTopic,
                  let subtopic = noteDisplayState.currentSubtopic else { return }

            if isNewNote {
                let newNote = try await dataManager.addNote(
                    to: subtopic,
                    in: topic,
                    title: editedTitle,
                    content: editedContent
                )
                await MainActor.run {
                    noteDisplayState.currentNote = newNote
                    lastSavedText = "just now"
                    hasChanges = false
                }
                notificationManager.playSound(.success)
                notificationManager.scheduleNotification(
                    title: "New Note Created",
                    body: "Your note '\(editedTitle)' has been created successfully"
                )
            } else if let note = noteDisplayState.currentNote {
                _ = try await dataManager.updateNote(
                    note,
                    in: subtopic,
                    in: topic,
                    newTitle: editedTitle,
                    newContent: editedContent
                )
                await MainActor.run {
                    lastSavedText = "just now"
                    hasChanges = false
                }
                notificationManager.playSound(.save)
                notificationManager.scheduleNotification(
                    title: "Note Saved",
                    body: "Your note '\(editedTitle)' has been saved successfully"
                )
            }
        } catch {
            print("Error saving note: \(error)")
            notificationManager.playSound(.error)
        }
    }
}
