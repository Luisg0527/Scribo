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
                    Text("By accessing and using Scribo, you agree to be bound by these Terms of Use. If you do not agree to these terms, please do not use the application.")
                    
                    Text("2. User Accounts")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("• You must be at least 13 years old to use Scribo\n• You are responsible for maintaining the confidentiality of your account\n• You agree to provide accurate and complete information when creating your account\n• You are responsible for all activities that occur under your account")
                    
                    Text("3. User Content")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("• You retain ownership of the content you create\n• You are responsible for the content you create and share\n• You must not create content that is illegal, harmful, or violates others' rights\n• We reserve the right to remove content that violates these terms")
                    
                    Text("4. Prohibited Activities")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("You agree not to:\n• Use the app for any illegal purpose\n• Attempt to gain unauthorized access\n• Interfere with the app's functionality\n• Share your account credentials\n• Use automated systems or bots")
                    
                    Text("5. Intellectual Property")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("• The app and its original content are owned by Scribo\n• You may not copy, modify, or distribute the app without permission\n• Your content remains your property")
                    
                    Text("6. Termination")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("We reserve the right to terminate or suspend your account at any time for violations of these terms or for any other reason at our discretion.")
                    
                    Text("7. Disclaimer")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("The app is provided 'as is' without any warranties. We are not responsible for any loss of data or other damages that may occur from using the app.")
                    
                    Text("8. Changes to Terms")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("We reserve the right to modify these terms at any time. We will notify users of any material changes.")
                    
                    Text("Contact")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("If you have any questions about these Terms of Use, please contact us at:\n[Your Contact Information]")
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}

#Preview {
    TermsOfUse()
} 