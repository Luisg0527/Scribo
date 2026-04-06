import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Share QR sheet (note/topic – full-screen QR view)
struct ShareQRSheetView: View {
    let title: String
    let inviteURL: String
    @Binding var isPresented: Bool
    private let ciContext = CIContext()
    private let qrFilter = CIFilter.qrCodeGenerator()

    @State private var qrModuleColor: Color = .black
    @State private var qrPaperColor: Color = .white
    @State private var qrPulseScale: CGFloat = 1
    @State private var showCopiedTooltip = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    Text("Share")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Spacer()
                    ShareQRToolbarIconButton(icon: "xmark") {
                        isPresented = false
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 8)
                if let image = generateQRCode(from: inviteURL) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260, height: 260)
                        .padding(24)
                        .background(qrPaperColor)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .scaleEffect(qrPulseScale)
                }
                Spacer()
                HStack(alignment: .top, spacing: 0) {
                    ShareQRToolbarButton(icon: "paintpalette.fill", title: "Customize") {
                        randomizeQRTheme()
                    }
                    .frame(maxWidth: .infinity)
                    ShareQRToolbarButton(icon: "square.and.arrow.up", title: "Share") {
                        presentSystemShare()
                    }
                    .frame(maxWidth: .infinity)
                    copyColumn
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 32)
            }
        }
    }

    private func randomizeQRTheme() {
        let pair = Self.pickRandomHighContrastQRPair()
        qrModuleColor = pair.module
        qrPaperColor = pair.paper
        qrPulseScale = 0.9
        withAnimation(.spring(response: 0.52, dampingFraction: 0.62)) {
            qrPulseScale = 1.0
        }
    }

    /// Dark modules + light paper, random hues; WCAG-style contrast ratio ≥ 4:1 (tries a few samples).
    private static func pickRandomHighContrastQRPair() -> (module: Color, paper: Color) {
        for _ in 0..<32 {
            let paperHue = Double.random(in: 0...1)
            let paperSat = Double.random(in: 0.08...0.5)
            let paperBright = Double.random(in: 0.78...1.0)
            let moduleHue = Double.random(in: 0...1)
            let moduleSat = Double.random(in: 0.35...1.0)
            let moduleBright = Double.random(in: 0.04...0.34)

            let paper = Color(hue: paperHue, saturation: paperSat, brightness: paperBright)
            let module = Color(hue: moduleHue, saturation: moduleSat, brightness: moduleBright)
            let ratio = contrastRatio(UIColor(module), UIColor(paper))
            if ratio >= 4.0 {
                return (module, paper)
            }
        }
        return (.black, .white)
    }

    private static func contrastRatio(_ a: UIColor, _ b: UIColor) -> CGFloat {
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        let lighter = max(la, lb)
        let darker = min(la, lb)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func relativeLuminance(_ color: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&r, green: &g, blue: &bl, alpha: &alpha)
        func convert(_ c: CGFloat) -> CGFloat {
            c <= 0.03928 ? (c / 12.92) : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * convert(r) + 0.7152 * convert(g) + 0.0722 * convert(bl)
    }

    /// Copy + tooltip: tooltip is `overlay` so it never widens the column (avoids shoving other buttons left).
    private var copyColumn: some View {
        ShareQRToolbarButton(icon: "doc.on.doc", title: "Copy") {
            UIPasteboard.general.string = inviteURL
            withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                showCopiedTooltip = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut(duration: 0.22)) {
                    showCopiedTooltip = false
                }
            }
        }
        .overlay(alignment: .top) {
            if showCopiedTooltip {
                copiedTooltip
                    .offset(y: -72)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)),
                            removal: .opacity
                        )
                    )
                    .allowsHitTesting(false)
            }
        }
    }

    private var copiedTooltip: some View {
        VStack(spacing: 0) {
            Text("Copied to clipboard")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(white: 0.2))
                        .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 6)
                )
            CopiedTooltipTail()
                .fill(Color(white: 0.2))
                .frame(width: 18, height: 9)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                .offset(y: -1.5)
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        qrFilter.setValue(data, forKey: "inputMessage")
        qrFilter.setValue("M", forKey: "inputCorrectionLevel")
        guard let outputImage = qrFilter.outputImage else { return nil }
        let scale: CGFloat = 20
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let moduleUIColor = UIColor(qrModuleColor)
        let paperUIColor = UIColor(qrPaperColor)
        guard let colorFilter = CIFilter(name: "CIFalseColor") else { return nil }
        colorFilter.setValue(scaled, forKey: kCIInputImageKey)
        colorFilter.setValue(CIColor(color: moduleUIColor), forKey: "inputColor0")
        colorFilter.setValue(CIColor(color: paperUIColor), forKey: "inputColor1")
        guard let colored = colorFilter.outputImage else { return nil }

        let bounds = colored.extent.integral
        guard let cgImage = ciContext.createCGImage(colored, from: bounds) else { return nil }
        return UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
    }

    private func presentSystemShare() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let root = window.rootViewController else { return }
        let vc = UIActivityViewController(activityItems: [inviteURL], applicationActivities: nil)
        root.present(vc, animated: true)
    }
}

// MARK: - Toolbar button (pulse on tap)

private struct ShareQRToolbarButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var pulseScale: CGFloat = 1

    var body: some View {
        Button {
            runPulse()
            action()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 60, height: 60)
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .scaleEffect(pulseScale)
    }

    private func runPulse() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.52)) {
            pulseScale = 1.1
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(130))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.68)) {
                pulseScale = 1.0
            }
        }
    }
}

/// Close control in header: same pulse, no caption.
private struct ShareQRToolbarIconButton: View {
    let icon: String
    let action: () -> Void
    @State private var pulseScale: CGFloat = 1

    var body: some View {
        Button {
            runPulse()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(8)
        }
        .buttonStyle(.plain)
        .scaleEffect(pulseScale)
    }

    private func runPulse() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.52)) {
            pulseScale = 1.08
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.68)) {
                pulseScale = 1.0
            }
        }
    }
}

// MARK: - Tooltip tail (points down toward the Copy button)
private struct CopiedTooltipTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
