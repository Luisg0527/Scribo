import SwiftUI

struct TermsOfUse: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Terms of Use")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom)

                Group {
                    Text("Last Updated: \(Date().formatted(date: .long, time: .omitted))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("1. Acceptance of Terms")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("By using Scribo, you agree to these Terms of Use. If you do not agree, please do not use the app.")

                    Text("2. Eligibility")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("You must be at least 13 years old to use Scribo.")

                    Text("3. User Accounts")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("• You are responsible for your account's security and activity.\n• You agree to provide accurate information.\n• Do not share your credentials.")

                    Text("4. User Content")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("• You retain full ownership of your notes and photos.\n• You are responsible for your content.\n• Do not upload illegal, harmful, or infringing content.\n• We may remove content that violates these terms.")

                    Text("5. Prohibited Activities")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("You agree not to:\n• Use Scribo for illegal purposes\n• Access unauthorized parts of the system\n• Interfere with app functionality\n• Use bots or automation")

                    Text("6. Intellectual Property")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("All content and code in Scribo is owned by the developer. You may not copy, modify, or distribute the app without permission.")

                    Text("7. Termination")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("We may suspend or terminate your access at any time if you violate these terms.")

                    Text("8. Disclaimers")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Scribo is provided 'as is'. We do not guarantee error-free service or data loss protection.")

                    Text("9. Changes to Terms")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("We may update these terms at any time. Continued use of the app means you accept the new terms.")

                    Text("10. Governing Law")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("These terms are governed by the laws of Mexico.")

                    Text("Contact Us")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("For any questions about these Terms of Use, contact us at:\nsantiparedes738@gmail.com")
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}
