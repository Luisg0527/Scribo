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

private struct NoteScrollContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
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

/// Drives which main body to show so we never flash the text editor while image attachments are still resolving.
private enum NoteAttachmentDisplayPhase: Equatable {
    /// Waiting on `note_attachments` metadata (fast).
    case resolvingKind
    case text
    case images
}

private struct NoteImageFullscreenSelection: Identifiable, Hashable {
    let id: Int
}

private struct ShareInviteSheetItem: Identifiable {
    let id = UUID()
    let url: String
    /// Notebook (topic) title — link shares the whole notebook, not just this note.
    let sheetTitle: String
}

/// Drag-based stacked carousel: center card full size, side cards peek with scale and spring snap.
private struct Carousel: View {
    let images: [UIImage]
    @Binding var selectedIndex: Int
    let contentWidth: CGFloat
    let contentHeight: CGFloat
    var cornerRadius: CGFloat = 24
    var transitionNamespace: Namespace.ID
    var onImageTap: (Int) -> Void

    @GestureState private var dragOffset: CGFloat = 0

    private let cardSpacing: CGFloat = 18
    private let sidePeek: CGFloat = 46
    private let sideScale: CGFloat = 0.92
    private let sideOpacity: CGFloat = 0.72

    var body: some View {
        GeometryReader { geo in
            let cardWidth = contentWidth - sidePeek * 2
            let step = cardWidth + cardSpacing

            ZStack {
                ForEach(images.indices, id: \.self) { index in
                    let relativeIndex = CGFloat(index - selectedIndex)
                    let progress = dragOffset / step
                    let currentRelative = relativeIndex + progress

                    Image(uiImage: images[index])
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardWidth, height: contentHeight)
                        .clipped()
                        .matchedTransitionSource(id: index, in: transitionNamespace) { source in
                            source.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .shadow(color: .black.opacity(index == selectedIndex ? 0.18 : 0.08), radius: 12, x: 0, y: 6)
                        .rotationEffect(.degrees(rotation(for: currentRelative)))
                        .scaleEffect(scale(for: currentRelative))
                        .opacity(opacity(for: currentRelative))
                        .offset(x: currentRelative * step)
                        .zIndex(zIndex(for: currentRelative))
                        .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.82), value: selectedIndex)
                        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.9), value: dragOffset)
                        .accessibilityLabel("Image \(index + 1) of \(images.count)")
                        .accessibilityHint("Tap to view full screen and zoom")
                        .onTapGesture {
                            onImageTap(index)
                        }
                }
            }
            .frame(width: geo.size.width, height: contentHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 14)
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let predicted = value.predictedEndTranslation.width
                        let threshold = step * 0.22

                        var newIndex = selectedIndex

                        if predicted < -threshold || value.translation.width < -threshold {
                            newIndex += 1
                        } else if predicted > threshold || value.translation.width > threshold {
                            newIndex -= 1
                        }

                        selectedIndex = max(0, min(images.count - 1, newIndex))
                    }
            )
        }
        .frame(height: contentHeight)
    }

    private func scale(for relative: CGFloat) -> CGFloat {
        let distance = min(abs(relative), 1.0)
        return 1.0 - (distance * (1.0 - sideScale))
    }

    private func opacity(for relative: CGFloat) -> CGFloat {
        let distance = min(abs(relative), 1.0)
        return 1.0 - (distance * (1.0 - sideOpacity))
    }

    private func zIndex(for relative: CGFloat) -> Double {
        100 - Double(abs(relative))
    }

    private func rotation(for relative: CGFloat) -> Double {
        let clamped = max(-1, min(1, relative))
        return -Double(clamped * 2.4)
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
    @State private var shareInviteSheetItem: ShareInviteSheetItem?
    @State private var lastSavedText = "Just now"
    @State private var showingSaveAlert = false
    @State private var hasChanges: Bool = false
    @State private var noteImages: [UIImage] = []
    @State private var dominantColor: Color?
    @State private var selectedImageIndex: Int = 0
    @State private var fullscreenImageSelection: NoteImageFullscreenSelection?
    @Namespace private var noteCarouselImageNamespace
    @State private var attachmentDisplayPhase: NoteAttachmentDisplayPhase
    /// Width of the scroll content (for sizing carousel from image aspect ratios).
    @State private var scrollContentWidth: CGFloat = 0
    @FocusState private var isTitleFocused: Bool

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    let isNewNote: Bool
    /// Note passed at presentation time; `noteDisplayState.currentNote` can lag one frame (e.g. NavigationLink `onAppear`).
    private let sourceNote: Note?

    init(note: Note?, isPresented: Binding<Bool>, dataManager: DataManager) {
        self._isPresented = isPresented
        self._editedTitle = State(initialValue: note?.title ?? "")
        self._editedContent = State(initialValue: note?.content ?? "")
        self.isNewNote = note == nil
        self.sourceNote = note
        self.dataManager = dataManager
        self._isFromChatView = State(initialValue: isPresented.wrappedValue)
        self._attachmentDisplayPhase = State(initialValue: note == nil ? .text : .resolvingKind)
    }

    private var noteIdForAttachments: UUID? {
        noteDisplayState.currentNote?.id ?? sourceNote?.id
    }

    private var isReadOnlyShare: Bool {
        noteDisplayState.isReadOnlySharePresentation
    }

    private func closeNotePresentation() {
        if noteDisplayState.isReadOnlySharePresentation {
            noteDisplayState.isReadOnlySharePresentation = false
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

    // Match EverythingCardSheetView styling
    private var cardBg: Color { Color(red: 0.98, green: 0.98, blue: 0.99) }
    private var sheetBg: Color { Color(red: 0.917, green: 0.917, blue: 0.917) }

    /// Tags, extra notes, and action bar — always on the light sheet background.
    private var noteMetadataAndChrome: some View {
        VStack(spacing: 0) {
            mindTagsSection
            mindNotesSection
            Spacer(minLength: 24)
            bottomBarView
            statusView
        }
        .frame(maxWidth: .infinity)
        .background(sheetBg)
        /// Clears the tab bar + `TabBarContentBottomFade` overlap so the last line stays readable.
        .padding(.bottom, 36)
    }

    /// Fixed inset from screen edges to image (reference ~20–24pt).
    private static let carouselHorizontalInset: CGFloat = 12

    private var carouselContentWidth: CGFloat {
        let full = scrollContentWidth > 1 ? scrollContentWidth : UIScreen.main.bounds.width
        return max(80, full - 2 * Self.carouselHorizontalInset)
    }

    private var carouselImageAreaHeight: CGFloat {
        let w = carouselContentWidth
        if noteImages.isEmpty {
            if attachmentDisplayPhase == .images {
                return Self.imageCarouselPlaceholderHeight
            }
            return 0
        }
        if noteImages.count == 1 {
            return Self.displayHeight(for: noteImages[0], contentWidth: w)
        }
        return Self.maxDisplayHeight(for: noteImages, contentWidth: w)
    }

    private static let imageCarouselPlaceholderHeight: CGFloat = 220

    private static func displayHeight(for image: UIImage, contentWidth: CGFloat) -> CGFloat {
        let iw = image.size.width
        let ih = image.size.height
        guard iw > 0, ih > 0, contentWidth > 0 else { return 200 }
        let raw = contentWidth * (ih / iw)
        let cap = UIScreen.main.bounds.height * 0.62
        return min(max(raw, 120), cap)
    }

    private static func maxDisplayHeight(for images: [UIImage], contentWidth: CGFloat) -> CGFloat {
        images.map { displayHeight(for: $0, contentWidth: contentWidth) }.max() ?? 200
    }

    var body: some View {
        ZStack {
            sheetBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    switch attachmentDisplayPhase {
                    case .text:
                        headerView
                        textOnlyMainContent
                        noteMetadataAndChrome
                    case .resolvingKind:
                        headerView
                        noteResolvingKindPlaceholder
                        noteMetadataAndChrome
                    case .images:
                        VStack(spacing: 0) {
                            headerView
                            imageMainContent
                        }
                        .frame(maxWidth: .infinity)
                        .background(
                            (dominantColor ?? sheetBg)
                                .ignoresSafeArea(edges: [.top, .leading, .trailing])
                        )
                        noteMetadataAndChrome
                    }
                }
                .frame(maxWidth: .infinity)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: NoteScrollContentWidthKey.self, value: proxy.size.width)
                    }
                )
                .onPreferenceChange(NoteScrollContentWidthKey.self) { newWidth in
                    if abs(newWidth - scrollContentWidth) > 0.5 {
                        scrollContentWidth = newWidth
                    }
                }
            }
            .scrollContentBackground(.hidden)
           
        }
        .background(sheetBg)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(attachmentDisplayPhase == .images ? .hidden : .automatic, for: .navigationBar)
        .alert("Save Changes?", isPresented: $showingSaveAlert) {
            Button("Don't Save", role: .destructive) {
                hasChanges = false
                closeNotePresentation()
            }
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                Task {
                    await saveNote()
                    closeNotePresentation()
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
        .fullScreenCover(item: $shareInviteSheetItem) { item in
            ShareQRSheetView(
                title: item.sheetTitle,
                inviteURL: item.url,
                isPresented: Binding(
                    get: { shareInviteSheetItem != nil },
                    set: { if !$0 { shareInviteSheetItem = nil } }
                )
            )
        }
        .fullScreenCover(item: $fullscreenImageSelection) { selection in
            if noteImages.indices.contains(selection.id) {
                FullscreenImageViewer(
                    image: noteImages[selection.id],
                    allImages: noteImages,
                    currentIndex: selection.id,
                    isPresented: Binding(
                        get: { fullscreenImageSelection != nil },
                        set: { if !$0 { fullscreenImageSelection = nil } }
                    ),
                    transitionNamespace: noteCarouselImageNamespace,
                    zoomTransitionSourceID: selection.id
                )
            }
        }
        .task(id: noteIdForAttachments) {
            await MainActor.run {
                noteImages = []
                dominantColor = nil
                selectedImageIndex = 0
                attachmentDisplayPhase = isNewNote ? .text : .resolvingKind
            }
            await loadNoteImages()
        }
    }

    private var headerView: some View {
        HStack {
            Button(action: {
                if hasChanges && !isReadOnlyShare {
                    showingSaveAlert = true
                } else {
                    closeNotePresentation()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.appText)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Group {
                if isReadOnlyShare {
                    Text(editedTitle.isEmpty ? "Untitled" : editedTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.appText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                } else {
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
                                .strokeBorder(Color.appText, lineWidth: 2)
                                .opacity(isTitleFocused ? 1 : 0)
                        )
                        .animation(.easeInOut(duration: 0.25), value: isTitleFocused)
                        .onChange(of: editedTitle) { _, _ in hasChanges = true }
                        .onChange(of: isTitleFocused) { _, focused in
                            if !focused && hasChanges { Task { await saveNote() } }
                        }
                }
            }
            Spacer()
            if isReadOnlyShare {
                Color.clear.frame(width: 44, height: 44)
            } else {
                Menu {
                    Button(action: { beginShareFlow() }) {
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
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(attachmentDisplayPhase == .images ? Color.clear : sheetBg)
    }

    private var noteResolvingKindPlaceholder: some View {
        VStack(spacing: 0) {
            Divider()
            ProgressView()
                .progressViewStyle(.circular)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 280)
            Divider()
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
        .background(sheetBg)
    }

    private var textOnlyMainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            if isReadOnlyShare {
                Text(editedContent)
                    .font(.body)
                    .foregroundColor(.appText)
                    .frame(maxWidth: .infinity, minHeight: 252, alignment: .topLeading)
                    .padding(16)
            } else {
                TextEditor(text: $editedContent)
                    .font(.body)
                    .foregroundColor(.appText)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, minHeight: 252, alignment: .topLeading)
                    .padding(16)
                    .onChange(of: editedContent) { _, _ in hasChanges = true }
            }
            Divider()
        }
        .background(sheetBg)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// Carousel: fixed side margins, dynamic height, rounded images; dots sit below (never overlapping).
    private var imageMainContent: some View {
        let dotDiameter: CGFloat = 6
        let activePillWidth: CGFloat = 22
        let imageH = carouselImageAreaHeight
        let innerW = carouselContentWidth
        return VStack(spacing: 0) {
            Divider()
            VStack(spacing: 12) {
                Group {
                    if attachmentDisplayPhase == .images, noteImages.isEmpty {
                        RoundedRectangle(cornerRadius: Self.imageCornerRadius, style: .continuous)
                            .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
                            .frame(width: innerW, height: imageH)
                            .overlay {
                                ProgressView()
                            }
                    } else if noteImages.count == 1 {
                        noteImagePage(noteImages[0], contentWidth: innerW, contentHeight: imageH) {
                            fullscreenImageSelection = NoteImageFullscreenSelection(id: 0)
                        }
                    } else if noteImages.count > 1 {
                        Carousel(
                            images: noteImages,
                            selectedIndex: $selectedImageIndex,
                            contentWidth: innerW,
                            contentHeight: imageH,
                            cornerRadius: Self.imageCornerRadius,
                            transitionNamespace: noteCarouselImageNamespace,
                            onImageTap: { index in
                                fullscreenImageSelection = NoteImageFullscreenSelection(id: index)
                            }
                        )
                        .frame(height: imageH)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Self.carouselHorizontalInset)

                if noteImages.count > 1 {
                    carouselPageIndicators(
                        count: noteImages.count,
                        selectedIndex: selectedImageIndex,
                        dotDiameter: dotDiameter,
                        activePillWidth: activePillWidth
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
                }
            }
            .padding(.vertical, 12)
            Divider()
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
    }

    private func carouselPageIndicators(count: Int, selectedIndex: Int, dotDiameter: CGFloat, activePillWidth: CGFloat) -> some View {
        let inactiveFill = Color(red: 0.22, green: 0.22, blue: 0.24)
        return HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                if index == selectedIndex {
                    Capsule()
                        .fill(Color.white)
                        .frame(width: activePillWidth, height: dotDiameter)
                } else {
                    Circle()
                        .fill(inactiveFill)
                        .frame(width: dotDiameter, height: dotDiameter)
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: selectedIndex)
    }

    private static let imageCornerRadius: CGFloat = 24

    private func noteImagePage(_ image: UIImage, contentWidth: CGFloat, contentHeight: CGFloat, onTap: @escaping () -> Void) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: contentWidth, height: contentHeight)
            .clipped()
            .matchedTransitionSource(id: 0, in: noteCarouselImageNamespace) { source in
                source.clipShape(RoundedRectangle(cornerRadius: Self.imageCornerRadius, style: .continuous))
            }
            .clipShape(RoundedRectangle(cornerRadius: Self.imageCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 5)
            .accessibilityLabel("Attached image")
            .accessibilityHint("Tap to view full screen and zoom")
            .onTapGesture(perform: onTap)
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
                .disabled(isReadOnlyShare)
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
        .padding(.top, 30)
    }

    private var mindNotesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EXTRA NOTES")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.appTextSecondary)
            Group {
                if attachmentDisplayPhase == .text {
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
            .disabled(isReadOnlyShare)
            .onChange(of: editedContent) { _, _ in
                if attachmentDisplayPhase == .images { hasChanges = true }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var bottomBarView: some View {
        Group {
            if isReadOnlyShare {
                Text("Viewing a shared note (read-only)")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
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
                    Button(action: { beginShareFlow() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16))
                            Text("Share notebook")
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
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var statusView: some View {
        Text(isReadOnlyShare ? "Opened from a share link" : "Saved to your notebook, \(lastSavedText)")
            .font(.caption)
            .foregroundColor(.appTextSecondary)
            .padding(.vertical, 12)
    }

    /// Share is Drive-style: one link for the whole notebook (topic) that contains this note.
    private func beginShareFlow() {
        guard !isReadOnlyShare else { return }
        guard let topicId = topicIdForNotebookShare() else { return }
        Task {
            do {
                let token = try await dataManager.ensureActiveTopicShareLink(forTopicId: topicId)
                let url = NoteShareInviteURL.httpsNotebookInviteURL(for: token)
                let title = notebookShareSheetTitle(forTopicId: topicId)
                await MainActor.run {
                    shareInviteSheetItem = ShareInviteSheetItem(url: url, sheetTitle: title)
                }
            } catch {
                await MainActor.run { notificationManager.playSound(.error) }
                print("Share link error: \(error)")
            }
        }
    }

    private func topicIdForNotebookShare() -> UUID? {
        if let t = noteDisplayState.currentTopic { return t.id }
        guard let noteId = noteIdForAttachments else { return nil }
        for topic in dataManager.topics {
            for sub in topic.subtopics where sub.notes.contains(where: { $0.id == noteId }) {
                return topic.id
            }
        }
        return nil
    }

    private func notebookShareSheetTitle(forTopicId topicId: UUID) -> String {
        dataManager.topics.first(where: { $0.id == topicId })?.title ?? "Shared notebook"
    }

    private func loadNoteImages() async {
        guard let noteId = noteIdForAttachments else {
            await MainActor.run {
                noteImages = []
                dominantColor = nil
                selectedImageIndex = 0
                attachmentDisplayPhase = .text
            }
            return
        }
        do {
            let attachments = try await dataManager.getAttachments(forNoteId: noteId)
            let imageAttachments = attachments.filter { $0.isImageLike }
            await MainActor.run {
                if imageAttachments.isEmpty {
                    attachmentDisplayPhase = .text
                } else {
                    attachmentDisplayPhase = .images
                }
            }
            var loaded: [UIImage] = []
            for att in imageAttachments {
                if let image = await dataManager.loadUIImage(for: att) {
                    loaded.append(image)
                }
            }
            var color: Color?
            if let first = loaded.first {
                color = extractDominantColor(from: first)
            }
            await MainActor.run {
                noteImages = loaded
                dominantColor = color
                selectedImageIndex = 0
                if !imageAttachments.isEmpty {
                    attachmentDisplayPhase = .images
                }
            }
        } catch {
            await MainActor.run {
                noteImages = []
                dominantColor = nil
                attachmentDisplayPhase = .text
            }
        }
    }

    private func saveNote() async {
        guard !noteDisplayState.isReadOnlySharePresentation else { return }
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
