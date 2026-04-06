import UIKit
import Vision

// MARK: - OCR (shared by document pipeline + Create Note sheet)
func performOCR(on image: UIImage) async -> String? {
    guard let cgImage = image.cgImage else {
        print("Failed to get CGImage from UIImage")
        return nil
    }

    let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.customWords = ["Swift", "SwiftUI", "Xcode", "iOS", "macOS", "UIKit", "AppKit"]

    do {
        try requestHandler.perform([request])
        guard let observations = request.results else {
            print("No text observations found in image")
            return nil
        }

        let sortedObservations = observations.sorted { obs1, obs2 in
            let box1 = obs1.boundingBox
            let box2 = obs2.boundingBox
            return box1.origin.y > box2.origin.y
        }

        var processedLines: [String] = []
        var currentLine: [String] = []
        var lastY: CGFloat = -1
        let yThreshold: CGFloat = 0.05

        for observation in sortedObservations {
            let text = observation.topCandidates(1).first?.string ?? ""
            let box = observation.boundingBox

            if lastY == -1 {
                lastY = box.origin.y
                currentLine.append(text)
            } else if abs(box.origin.y - lastY) < yThreshold {
                currentLine.append(text)
            } else {
                if !currentLine.isEmpty {
                    processedLines.append(currentLine.joined(separator: " "))
                }
                currentLine = [text]
                lastY = box.origin.y
            }
        }

        if !currentLine.isEmpty {
            processedLines.append(currentLine.joined(separator: " "))
        }

        let processedText = processedLines.joined(separator: "\n")

        if processedText.isEmpty {
            print("OCR returned empty text")
            return nil
        }

        return processedText
    } catch {
        print("OCR Error: \(error.localizedDescription)")
        return nil
    }
}
