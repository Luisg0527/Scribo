import SwiftUI
import PhotosUI
import Photos
import UIKit

/// Thrown when classification does not finish within the time limit (Create Note sheet).
private struct ClassificationTimeoutError: Error {}

// MARK: - Create Note Sheet (compose UI + topic picker on save)
struct CreateNoteSheetView: View {
    @Binding var isPresented: Bool
    @Binding var pendingPhotos: [PendingNotePhoto]
    @Binding var noteBody: String
    @ObservedObject var dataManager: DataManager
    private let classificationService: TextClassificationService
    var initialTopic: Topic? = nil
    var initialSubtopic: Subtopic? = nil
    var onRequestCamera: (() -> Void)?
    var onRequestDocument: (() -> Void)?

    @State private var selectedPhotosForNote: [PhotosPickerItem] = []
    @State private var isSaving = false
    @State private var showNeedTopicAlert = false
    @State private var showTopicSubtopicPicker = false
    @State private var selectedTopic: Topic?
    @State private var selectedSubtopic: Subtopic?
    @State private var showConfetti = false
    @State private var isManualNoteMode = false
    @State private var saveErrorMessage: String?
    @State private var isAttachMenuPresented = false
    @State private var isAttachmentsEditorPresented = false
    @FocusState private var isTextFieldFocused: Bool

    private let attachmentSquare: CGFloat = 100

    init(
        isPresented: Binding<Bool>,
        pendingPhotos: Binding<[PendingNotePhoto]>,
        noteBody: Binding<String>,
        dataManager: DataManager,
        classificationService: TextClassificationService = TextClassificationService(
            serverURL: "http://192.168.68.120:8000/classify",
            apiKey: "dev-secret-12345"
        ),
        initialTopic: Topic? = nil,
        initialSubtopic: Subtopic? = nil,
        onRequestCamera: (() -> Void)? = nil,
        onRequestDocument: (() -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self._pendingPhotos = pendingPhotos
        self._noteBody = noteBody
        self.dataManager = dataManager
        self.classificationService = classificationService
        self.initialTopic = initialTopic
        self.initialSubtopic = initialSubtopic
        self.onRequestCamera = onRequestCamera
        self.onRequestDocument = onRequestDocument
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                if showConfetti {
                    LottieView(name: "Confetti", loopMode: .playOnce, playSpeed: 1.0)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("ADD A NEW NOTE")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.featureCalloutAccent)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    TextEditor(text: $noteBody)
                        .font(.body)
                        .foregroundColor(Color(.label))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 160)
                        .focused($isTextFieldFocused)
                        .padding(.horizontal, 15)
                        .padding(.top, 10)
                        .overlay(alignment: .topLeading) {
                            if noteBody.isEmpty {
                                Text("What do you want to talk about?")
                                    .font(.body)
                                    .foregroundColor(Color(.placeholderText))
                                    .padding(.horizontal, 20)
                                    .padding(.top, 18)
                                    .allowsHitTesting(false)
                            }
                        }

                    if !pendingPhotos.isEmpty {
                        VStack(alignment: .trailing, spacing: 8) {
                            HStack(spacing: 6) {
                                Button {
                                    isAttachmentsEditorPresented = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Edit attachments")

                                Button {
                                    pendingPhotos.removeAll()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove all attachments")
                            }
                            .padding(.trailing, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(pendingPhotos) { photo in
                                        pendingAttachmentThumbnail(photo: photo)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .allowsHitTesting(!isAttachMenuPresented)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    composeAccessoryBar
                        .allowsHitTesting(!isAttachMenuPresented)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundColor(Color(.label))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Create a new note")
                        .font(.headline)
                        .foregroundColor(Color(.label))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onSaveTapped) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.body)
                                .foregroundColor(Color.featureCalloutAccent)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                isTextFieldFocused = true
                if let topic = initialTopic, let subtopic = initialSubtopic {
                    selectedTopic = topic
                    selectedSubtopic = subtopic
                }
            }
            .onChange(of: selectedPhotosForNote) { _, newValue in
                Task {
                    await ingestPhotosPickerItems(newValue)
                }
            }
            .alert("Add a topic first", isPresented: $showNeedTopicAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Create a topic and subtopic in the Notebook tab, then you can save notes here.")
            }
            .alert("Couldn’t save", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "")
            }
            .sheet(isPresented: $showTopicSubtopicPicker) {
                TopicSubtopicPickerSheet(
                    dataManager: dataManager,
                    selectedTopic: $selectedTopic,
                    selectedSubtopic: $selectedSubtopic,
                    onConfirm: { saveNoteWithTopicAndSubtopic() },
                    onCancel: { showTopicSubtopicPicker = false }
                )
            }
            .onChange(of: isAttachMenuPresented) { _, isOpen in
                if isOpen {
                    isTextFieldFocused = false
                }
            }
            .sheet(isPresented: $isAttachMenuPresented) {
                attachOptionsSheet
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
                    .presentationBackground(.clear)
                    .presentationBackgroundInteraction(.enabled)
            }
            .fullScreenCover(isPresented: $isAttachmentsEditorPresented) {
                CreateNoteAttachmentsEditorView(
                    photos: $pendingPhotos,
                    isPresented: $isAttachmentsEditorPresented
                )
            }
        }
    }

    private var composeAccessoryBar: some View {
        HStack(spacing: 14) {
            PhotosPicker(
                selection: $selectedPhotosForNote,
                maxSelectionCount: 20,
                matching: .images
            ) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add from photo library")

            Button {
                isAttachMenuPresented = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More attachments")

            Spacer(minLength: 0)

            Button {
                isManualNoteMode.toggle()
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(!isManualNoteMode ? Color.featureCalloutAccent : Color(.secondaryLabel))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Auto classification")
            .accessibilityHint(isManualNoteMode ? "Off. Tap to enable classification for title and placement." : "On. Tap to save as a manual note.")
            .accessibilityAddTraits(!isManualNoteMode ? .isSelected : [])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .background(
            Color(.systemBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var attachOptionsSheet: some View {
        VStack(spacing: 8) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 28),
                    GridItem(.flexible(), spacing: 28),
                    GridItem(.flexible(), spacing: 28)
                ],
                spacing: 32
            ) {
                PhotosPicker(
                    selection: $selectedPhotosForNote,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    attachGridButton(title: "Media", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.plain)

                Button {
                    isAttachMenuPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onRequestDocument?()
                    }
                } label: {
                    attachGridButton(title: "Document", systemImage: "doc.fill")
                }
                .buttonStyle(.plain)

                Button {
                    isAttachMenuPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onRequestCamera?()
                    }
                } label: {
                    attachGridButton(title: "Photo", systemImage: "camera.fill")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 8)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .background(RemoveSheetDropShadow())
    }

    private func attachGridButton(title: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 72, height: 72)
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color(.darkGray))
            }
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func pendingAttachmentThumbnail(photo: PendingNotePhoto) -> some View {
        Image(uiImage: photo.image)
            .resizable()
            .scaledToFill()
            .frame(width: attachmentSquare, height: attachmentSquare)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func ingestPhotosPickerItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        var entries: [PendingNotePhoto] = []
        for item in items {
            let assetId: String? = {
                if #available(iOS 17, *) {
                    return item.itemIdentifier
                }
                return nil
            }()
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                entries.append(PendingNotePhoto(image: image, photoLibraryAssetId: assetId))
            }
        }
        await MainActor.run {
            var next = pendingPhotos
            next.append(contentsOf: entries)
            pendingPhotos = next
            selectedPhotosForNote.removeAll()
            isAttachMenuPresented = false
        }
    }

    private func onSaveTapped() {
        let hasContent = !noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !hasContent && pendingPhotos.isEmpty {
            return
        }
        if isManualNoteMode {
            guard !dataManager.topics.isEmpty else {
                showNeedTopicAlert = true
                return
            }
            if let topic = initialTopic, let subtopic = initialSubtopic {
                saveNoteWithTopicAndSubtopic(topic: topic, subtopic: subtopic)
                return
            }
            showTopicSubtopicPicker = true
            return
        }
        Task { await saveWithClassificationPipeline() }
    }

    private func saveNoteWithTopicAndSubtopic(topic: Topic? = nil, subtopic: Subtopic? = nil) {
        let resolvedTopic = topic ?? selectedTopic
        let resolvedSubtopic = subtopic ?? selectedSubtopic
        guard let topicToUse = resolvedTopic, let subtopicToUse = resolvedSubtopic else { return }
        let content = noteBody
        let hasContent = !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !hasContent && pendingPhotos.isEmpty {
            showTopicSubtopicPicker = false
            return
        }
        isSaving = true
        showTopicSubtopicPicker = false
        Task {
            do {
                let note = try await dataManager.addNote(to: subtopicToUse, in: topicToUse, title: "", content: content)
                for photo in pendingPhotos {
                    guard let data = photo.image.jpegData(compressionQuality: 0.8) else { continue }
                    _ = try await dataManager.createImageAttachment(
                        for: note.id,
                        imageJPEGData: data,
                        assetLocalIdentifier: photo.photoLibraryAssetId
                    )
                }
                await MainActor.run {
                    pendingPhotos = []
                    isSaving = false
                    selectedTopic = topicToUse
                    selectedSubtopic = subtopicToUse
                    showConfetti = true
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    showConfetti = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }

    /// Default save path: OCR on photos + classify typed + extracted text, then create note (and topics if needed).
    private func saveWithClassificationPipeline() async {
        let trimmedTyped = noteBody.trimmingCharacters(in: .whitespacesAndNewlines)
        var ocrParts: [String] = []
        for photo in pendingPhotos {
            if let ocr = await performOCR(on: photo.image) {
                let t = ocr.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { ocrParts.append(t) }
            }
        }
        let combinedForClassification = [trimmedTyped, ocrParts.joined(separator: "\n\n")]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
        let combinedTrimmed = combinedForClassification.trimmingCharacters(in: .whitespacesAndNewlines)

        if combinedTrimmed.isEmpty {
            await MainActor.run {
                saveErrorMessage = "Add text or photos with readable text to classify. Or choose Manual note to save without classification."
            }
            return
        }

        await MainActor.run { isSaving = true }

        do {
            let classification = try await classifyTextWithTenSecondTimeout(combinedTrimmed)

            let topicToUse: Topic
            let subtopicToUse: Subtopic

            if let initialT = initialTopic, let initialS = initialSubtopic {
                topicToUse = initialT
                subtopicToUse = initialS
            } else {
                var topicObj = dataManager.topics.first { $0.title == classification.topic }
                if topicObj == nil {
                    topicObj = try await dataManager.addTopic(title: classification.topic)
                }
                guard let topicObj else {
                    throw NSError(domain: "CreateNote", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not resolve topic"])
                }
                var subtopicObj = topicObj.subtopics.first { $0.title == classification.subtopic }
                if subtopicObj == nil {
                    subtopicObj = try await dataManager.addSubtopic(to: topicObj, title: classification.subtopic)
                }
                guard let subtopicObj else {
                    throw NSError(domain: "CreateNote", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not resolve subtopic"])
                }
                topicToUse = topicObj
                subtopicToUse = subtopicObj
            }

            let noteTitle = classification.note_name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Untitled"
                : classification.note_name

            let contentForNote: String = {
                if ocrParts.isEmpty { return noteBody }
                if trimmedTyped.isEmpty { return ocrParts.joined(separator: "\n\n") }
                return trimmedTyped + "\n\n---\n" + ocrParts.joined(separator: "\n\n")
            }()

            let note = try await dataManager.addNote(
                to: subtopicToUse,
                in: topicToUse,
                title: noteTitle,
                content: contentForNote
            )
            for photo in pendingPhotos {
                guard let data = photo.image.jpegData(compressionQuality: 0.8) else { continue }
                _ = try await dataManager.createImageAttachment(
                    for: note.id,
                    imageJPEGData: data,
                    assetLocalIdentifier: photo.photoLibraryAssetId
                )
            }

            await MainActor.run {
                pendingPhotos = []
                isSaving = false
                selectedTopic = topicToUse
                selectedSubtopic = subtopicToUse
                showConfetti = true
                SoundManager.shared.playCompletionSound()
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                showConfetti = false
                isPresented = false
            }
        } catch {
            let lockedToSubtopic = initialTopic != nil && initialSubtopic != nil
            await MainActor.run {
                isSaving = false
                if lockedToSubtopic {
                    saveErrorMessage = "Classification failed or timed out. Try again, or tap Manual note to save without classification."
                } else {
                    isManualNoteMode = true
                    if dataManager.topics.isEmpty {
                        saveErrorMessage = "Classification failed or timed out. Create a topic in the Notebook tab, then save with Manual note."
                    } else {
                        showTopicSubtopicPicker = true
                    }
                }
            }
        }
    }

    /// First successful result wins; sibling task is cancelled. Times out after 10 seconds.
    private func classifyTextWithTenSecondTimeout(_ text: String) async throws -> TextClassificationResponse {
        try await withThrowingTaskGroup(of: TextClassificationResponse.self) { group in
            group.addTask {
                try await classificationService.classifyText(text)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 10_000_000_000)
                throw ClassificationTimeoutError()
            }
            guard let result = try await group.next() else {
                throw ClassificationTimeoutError()
            }
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Topic / Subtopic Picker (choose where to save the note)
struct TopicSubtopicPickerSheet: View {
    @ObservedObject var dataManager: DataManager
    @Binding var selectedTopic: Topic?
    @Binding var selectedSubtopic: Subtopic?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Topic")) {
                    ForEach(dataManager.topics) { topic in
                        Button(action: {
                            selectedTopic = topic
                            selectedSubtopic = nil
                        }) {
                            HStack {
                                Text(topic.title)
                                Spacer()
                                if selectedTopic?.id == topic.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color.featureCalloutAccent)
                                }
                            }
                        }
                    }
                }
                if let topic = selectedTopic {
                    Section(header: Text("Subtopic")) {
                        ForEach(topic.subtopics) { subtopic in
                            Button(action: { selectedSubtopic = subtopic }) {
                                HStack {
                                    Text(subtopic.title)
                                    Spacer()
                                    if selectedSubtopic?.id == subtopic.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Color.featureCalloutAccent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Save note to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save note") {
                        onConfirm()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color.featureCalloutAccent)
                    .disabled(selectedTopic == nil || selectedSubtopic == nil)
                }
            }
        }
        .onAppear {
            if selectedTopic == nil, let first = dataManager.topics.first {
                selectedTopic = first
                selectedSubtopic = first.subtopics.first
            }
        }
    }
}

// MARK: - Remove system sheet drop shadow
private struct RemoveSheetDropShadow: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            Self.stripShadowsWalkingSuperviews(from: uiView)
            if let vc = uiView.sheetHostingViewController() {
                Self.stripShadowsWalkingSuperviews(from: vc.view)
                var outer = vc.view.superview
                for _ in 0 ..< 32 {
                    guard let v = outer else { break }
                    Self.stripShadows(on: v)
                    outer = v.superview
                }
            }
        }
    }

    private static func stripShadowsWalkingSuperviews(from start: UIView) {
        var view: UIView? = start
        for _ in 0 ..< 60 {
            guard let v = view else { break }
            Self.stripShadows(on: v)
            view = v.superview
        }
    }

    private static func stripShadows(on view: UIView) {
        view.layer.shadowOpacity = 0
        view.layer.shadowRadius = 0
        view.layer.shadowOffset = .zero
        view.layer.shadowColor = UIColor.clear.cgColor
    }
}

private extension UIView {
    /// UIHostingController that owns this sheet’s SwiftUI content.
    func sheetHostingViewController() -> UIViewController? {
        var r: UIResponder? = self
        while let cur = r {
            if let vc = cur as? UIViewController {
                return vc
            }
            r = cur.next
        }
        return nil
    }
}
