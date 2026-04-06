import SwiftUI
import UIKit
import AVFoundation
import PencilKit

private enum CreateNoteAttachmentEditTool: Equatable {
    case none
    case draw
    case text
}

private enum CreateNoteAttachmentTextStyle: String, CaseIterable {
    case classic = "Classic"
    case minimal = "Minimal"
    case headline = "Headline"
}

private enum CreateNoteAttachmentImageUtils {
    static func drawText(
        _ text: String,
        on image: UIImage,
        alignment: NSTextAlignment,
        color: UIColor,
        style: CreateNoteAttachmentTextStyle
    ) -> UIImage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(at: .zero)
            let fontSize = max(18, min(image.size.width, image.size.height) * 0.045)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = alignment
            let fontWeight: UIFont.Weight = {
                switch style {
                case .classic: return .semibold
                case .minimal: return .regular
                case .headline: return .heavy
                }
            }()
            let strokeWidth: CGFloat = {
                switch style {
                case .classic: return -3
                case .minimal: return 0
                case .headline: return -5
                }
            }()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: fontWeight),
                .foregroundColor: color,
                .paragraphStyle: paragraph,
                .strokeColor: UIColor.black,
                .strokeWidth: strokeWidth
            ]
            let inset = fontSize * 0.75
            let rect = CGRect(
                x: inset,
                y: image.size.height * 0.42,
                width: image.size.width - inset * 2,
                height: image.size.height * 0.2
            )
            (trimmed as NSString).draw(
                with: rect,
                options: [.usesLineFragmentOrigin],
                attributes: attrs,
                context: nil
            )
        }
    }
}

private final class PencilMergeHostView: UIView {
    let imageView = UIImageView()
    let canvasView = PKCanvasView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        if #available(iOS 14.0, *) {
            canvasView.tool = PKInkingTool(.pen, color: .white, width: 4)
        }
        addSubview(imageView)
        addSubview(canvasView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let img = imageView.image, img.size.width > 0, img.size.height > 0 else {
            imageView.frame = bounds
            canvasView.frame = bounds
            return
        }
        let rect = AVMakeRect(aspectRatio: img.size, insideRect: bounds)
        imageView.frame = rect
        canvasView.frame = rect
    }

    func setImage(_ image: UIImage) {
        imageView.image = image
        setNeedsLayout()
    }

    func mergeDrawingIntoImage() -> UIImage {
        guard let base = imageView.image else { return UIImage() }
        let drawing = canvasView.drawing
        guard !drawing.strokes.isEmpty else { return base }
        let strokeBounds = canvasView.bounds
        canvasView.drawing = PKDrawing()
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = base.scale
        let renderer = UIGraphicsImageRenderer(size: base.size, format: format)
        let merged = renderer.image { _ in
            base.draw(in: CGRect(origin: .zero, size: base.size))
            let strokeImage = drawing.image(from: strokeBounds, scale: UIScreen.main.scale)
            strokeImage.draw(in: CGRect(origin: .zero, size: base.size))
        }
        imageView.image = merged
        return merged
    }
}

private struct AttachmentPencilKitOverlay: UIViewRepresentable {
    @Binding var image: UIImage
    var isActive: Bool
    var flushToken: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PencilMergeHostView {
        PencilMergeHostView()
    }

    func updateUIView(_ uiView: PencilMergeHostView, context: Context) {
        let c = context.coordinator
        let shouldFlush = (c.lastFlush != flushToken) || (c.wasDrawingActive && !isActive)
        if shouldFlush && !uiView.canvasView.drawing.strokes.isEmpty {
            let merged = uiView.mergeDrawingIntoImage()
            image = merged
        }
        if c.lastFlush != flushToken {
            c.lastFlush = flushToken
        }
        c.wasDrawingActive = isActive

        uiView.setImage(image)
        uiView.canvasView.isUserInteractionEnabled = isActive
        uiView.canvasView.isHidden = !isActive
    }

    final class Coordinator {
        var lastFlush: UUID?
        var wasDrawingActive = false
    }
}

private struct CreateNoteAttachmentEditorPage: View {
    @Binding var photo: PendingNotePhoto
    var showDrawOverlay: Bool
    var pencilFlushToken: UUID

    var body: some View {
        ZStack {
            Color.black
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if showDrawOverlay {
                AttachmentPencilKitOverlay(
                    image: $photo.image,
                    isActive: true,
                    flushToken: pencilFlushToken
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct CreateNoteAttachmentsEditorView: View {
    @Binding var photos: [PendingNotePhoto]
    @Binding var isPresented: Bool
    @State private var draft: [PendingNotePhoto] = []
    /// Avoid treating initial empty `draft` as “no photos” before `onAppear` copies `photos`.
    @State private var didHydrateDraftFromParent = false
    @State private var selectedPhotoId = UUID()
    @State private var activeTool: CreateNoteAttachmentEditTool = .none
    @State private var pencilFlushToken = UUID()
    @State private var textDraft = ""
    @State private var showAttachmentInlineMenu = false
    @State private var textOverlayStyle: CreateNoteAttachmentTextStyle = .classic
    @State private var textOverlayAlignment: NSTextAlignment = .center
    @State private var textOverlayColorIndex = 0
    @FocusState private var isTextOverlayFieldFocused: Bool

    private let textOverlayColors: [Color] = [.white, .black, .yellow, .cyan, .mint, .orange]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()

                if !didHydrateDraftFromParent {
                    ProgressView()
                        .tint(.white)
                } else if draft.isEmpty {
                    Color.black
                        .onAppear { isPresented = false }
                } else {
                    TabView(selection: $selectedPhotoId) {
                        ForEach(Array(draft.enumerated()), id: \.element.id) { index, photo in
                            CreateNoteAttachmentEditorPage(
                                photo: draftPhotoBinding(at: index),
                                showDrawOverlay: activeTool == .draw && photo.id == selectedPhotoId,
                                pencilFlushToken: pencilFlushToken
                            )
                            .tag(photo.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    if activeTool != .text {
                        attachmentEditorBottomBar
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                    }

                    if showAttachmentInlineMenu {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .onTapGesture { showAttachmentInlineMenu = false }

                        attachmentInlineMenu
                            .padding(.trailing, 24)
                            .padding(.bottom, 92)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottomTrailing)))
                    }

                    if activeTool == .text {
                        textEditingOverlay
                            .transition(.opacity)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.94), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        pencilFlushToken = UUID()
                        photos = draft
                        isPresented = false
                    } label: {
                        Text("Next")
                            .fontWeight(.semibold)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.white))
                    }
                }
            }
        }
        .onAppear {
            draft = photos
            didHydrateDraftFromParent = true
            if let first = draft.first {
                selectedPhotoId = first.id
            }
        }
        .onChange(of: selectedPhotoId) { _, _ in
            pencilFlushToken = UUID()
        }
        .onChange(of: activeTool) { _, new in
            if new != .draw {
                pencilFlushToken = UUID()
            }
            if new == .text {
                showAttachmentInlineMenu = false
                DispatchQueue.main.async {
                    isTextOverlayFieldFocused = true
                }
            } else {
                isTextOverlayFieldFocused = false
            }
        }
        .onChange(of: draft.count) { _, count in
            if count == 0 {
                isPresented = false
                return
            }
            if !draft.contains(where: { $0.id == selectedPhotoId }) {
                selectedPhotoId = draft.first?.id ?? selectedPhotoId
            }
        }
        .animation(.easeInOut(duration: 0.16), value: showAttachmentInlineMenu)
    }

    private func draftPhotoBinding(at index: Int) -> Binding<PendingNotePhoto> {
        Binding(
            get: { draft[index] },
            set: { draft[index] = $0 }
        )
    }

    private var attachmentEditorBottomBar: some View {
        HStack(spacing: 20) {
            editorBarIconButton(
                systemName: "pencil.tip",
                isSelected: activeTool == .draw,
                accessibilityLabel: "Draw on image"
            ) {
                if activeTool == .draw {
                    pencilFlushToken = UUID()
                    activeTool = .none
                } else {
                    activeTool = .draw
                }
            }

            editorBarIconButton(
                systemName: "textformat",
                isSelected: activeTool == .text,
                accessibilityLabel: "Add text"
            ) {
                if activeTool == .text {
                    activeTool = .none
                } else {
                    activeTool = .text
                }
            }

            editorBarIconButton(
                systemName: "trash",
                isSelected: false,
                accessibilityLabel: "Delete this image",
                foreground: .red
            ) {
                deleteCurrentDraftPhoto()
            }

            Button {
                showAttachmentInlineMenu.toggle()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(white: 0.28).opacity(0.95))
        )
    }

    private var attachmentInlineMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            inlineMenuButton(title: "Reorder", systemImage: "arrow.triangle.2.circlepath") {
                showAttachmentInlineMenu = false
                moveCurrentPhotoToFront()
            }
            inlineMenuButton(title: "Duplicate", systemImage: "doc.on.doc") {
                showAttachmentInlineMenu = false
                duplicateCurrentPhoto()
            }
            inlineMenuButton(title: "Delete", systemImage: "trash", foreground: .red) {
                showAttachmentInlineMenu = false
                deleteCurrentDraftPhoto()
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.09).opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
    }

    private func inlineMenuButton(
        title: String,
        systemImage: String,
        foreground: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(foreground.opacity(0.95))
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(minWidth: 210, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var textEditingOverlay: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture {
                    isTextOverlayFieldFocused = false
                }

            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    overlayToolIconButton(systemName: "trash") {
                        textDraft = ""
                    }
                    overlayToolIconButton(systemName: alignmentIconName) {
                        cycleTextAlignment()
                    }
                    overlayToolIconButton(systemName: "circle.fill", foreground: textOverlayColors[textOverlayColorIndex]) {
                        cycleTextColor()
                    }
                    overlayToolIconButton(systemName: "textformat.size") {
                        cycleTextStyle()
                    }
                    Spacer(minLength: 6)
                    Button("Done") {
                        applyTextOverlay()
                        activeTool = .none
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.white))
                .padding(.horizontal, 16)

                TextField("Type", text: $textDraft)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(textAlignmentForUI)
                    .font(.system(size: 34, weight: textStyleWeight))
                    .foregroundStyle(textOverlayColors[textOverlayColorIndex])
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.92))
                    )
                    .frame(maxWidth: 260)
                    .focused($isTextOverlayFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        applyTextOverlay()
                        activeTool = .none
                    }

                Spacer(minLength: 0)
            }
            .padding(.top, 14)
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 10) {
                ForEach(CreateNoteAttachmentTextStyle.allCases, id: \.self) { style in
                    Button(style.rawValue) {
                        textOverlayStyle = style
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(
                            style == textOverlayStyle
                            ? Color.green.opacity(0.9)
                            : Color.black.opacity(0.28)
                        )
                    )
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.6), lineWidth: style == textOverlayStyle ? 0 : 1)
                    )
                }
            }
            .padding(.bottom, 80)
        }
    }

    private func overlayToolIconButton(systemName: String, foreground: Color = .black, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(foreground)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
    }

    private var alignmentIconName: String {
        switch textOverlayAlignment {
        case .left: return "text.alignleft"
        case .right: return "text.alignright"
        default: return "text.aligncenter"
        }
    }

    private var textAlignmentForUI: TextAlignment {
        switch textOverlayAlignment {
        case .left: return .leading
        case .right: return .trailing
        default: return .center
        }
    }

    private var textStyleWeight: Font.Weight {
        switch textOverlayStyle {
        case .classic: return .semibold
        case .minimal: return .regular
        case .headline: return .heavy
        }
    }

    private func cycleTextAlignment() {
        switch textOverlayAlignment {
        case .left: textOverlayAlignment = .center
        case .center: textOverlayAlignment = .right
        default: textOverlayAlignment = .left
        }
    }

    private func cycleTextColor() {
        textOverlayColorIndex = (textOverlayColorIndex + 1) % textOverlayColors.count
    }

    private func cycleTextStyle() {
        let all = CreateNoteAttachmentTextStyle.allCases
        guard let idx = all.firstIndex(of: textOverlayStyle) else {
            textOverlayStyle = .classic
            return
        }
        textOverlayStyle = all[(idx + 1) % all.count]
    }

    private func editorBarIconButton(
        systemName: String,
        isSelected: Bool,
        accessibilityLabel: String,
        foreground: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(isSelected ? Color.featureCalloutAccent : foreground.opacity(0.92))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func deleteCurrentDraftPhoto() {
        guard let idx = draft.firstIndex(where: { $0.id == selectedPhotoId }) else { return }
        pencilFlushToken = UUID()
        draft.remove(at: idx)
    }

    private func duplicateCurrentPhoto() {
        guard let idx = draft.firstIndex(where: { $0.id == selectedPhotoId }) else { return }
        let base = draft[idx]
        let copy = PendingNotePhoto(
            image: base.image,
            photoLibraryAssetId: base.photoLibraryAssetId
        )
        draft.insert(copy, at: idx + 1)
        selectedPhotoId = copy.id
    }

    private func moveCurrentPhotoToFront() {
        guard let idx = draft.firstIndex(where: { $0.id == selectedPhotoId }),
              idx > 0 else { return }
        let current = draft.remove(at: idx)
        draft.insert(current, at: 0)
        selectedPhotoId = current.id
    }

    private func applyTextOverlay() {
        guard let idx = draft.firstIndex(where: { $0.id == selectedPhotoId }) else { return }
        let t = textDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        draft[idx].image = CreateNoteAttachmentImageUtils.drawText(
            t,
            on: draft[idx].image,
            alignment: textOverlayAlignment,
            color: UIColor(textOverlayColors[textOverlayColorIndex]),
            style: textOverlayStyle
        )
    }
}
