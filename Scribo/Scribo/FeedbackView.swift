import SwiftUI

struct FeedbackView: View {
    @State private var feedbackText = ""
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss

    let formEndpoint = "https://formspree.io/f/xdkzndaw"

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Your Feedback")) {
                    TextEditor(text: $feedbackText)
                        .frame(minHeight: 100)
                        .accessibilityLabel("Feedback text")
                        .accessibilityHint("Enter your feedback or feature request")
                }
                
                Section {
                    Button(action: submitFeedback) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text(isSubmitting ? "Submitting..." : "Submit Feedback")
                        }
                    }
                    .disabled(feedbackText.isEmpty || isSubmitting)
                    .accessibilityLabel("Submit feedback")
                    .accessibilityHint("Double tap to submit your feedback")
                }
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Feedback", isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    if alertMessage.contains("successfully") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
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