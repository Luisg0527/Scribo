import SwiftUI

struct FeedbackView: View {
    @State private var feedbackText = ""
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    let formEndpoint = "https://formspree.io/f/xdkzndaw"

    var body: some View {
        Form {
            Section(header: Text("Suggestions")) {
                TextField("Your feedback or feature request", text: $feedbackText)
                Button(action: submitFeedback) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Label("Submit Feedback", systemImage: "paperplane")
                    }
                }
                .disabled(feedbackText.isEmpty || isSubmitting)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Feedback"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    func submitFeedback() {
        guard let url = URL(string: formEndpoint) else { return }

        isSubmitting = true
        let body: [String: String] = ["message": feedbackText]
        let jsonData = try? JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                isSubmitting = false
                if let error = error {
                    alertMessage = "Failed to send: \(error.localizedDescription)"
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    alertMessage = "Feedback sent successfully. Thank you!"
                    feedbackText = ""
                } else {
                    alertMessage = "Failed to send feedback. Please try again."
                }
                showAlert = true
            }
        }.resume()
    }
} 