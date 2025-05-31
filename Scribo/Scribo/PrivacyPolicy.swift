import SwiftUI

struct PrivacyPolicy: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom)

                Group {
                    Text("Last Updated: \(Date().formatted(date: .long, time: .omitted))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Introduction")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Scribo is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our note-taking application.")

                    Text("Information We Collect")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("• Account Information: Your email and name used for authentication.\n• Notes: Text content and images you create.\n• Photos: Images you capture or upload.\n• Device Information: Basic data to ensure app functionality.")

                    Text("How We Use Your Information")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("• To provide and maintain Scribo.\n• To notify you about changes or updates.\n• To provide customer support.\n• To detect, prevent, and fix technical issues.")

                    Text("Data Storage and Security")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("• Your notes and photos are stored locally on your device.\n• Your account data is securely managed using Supabase authentication.\n• No actual photos are uploaded to external servers; only local references are stored.\n• Appropriate security measures are in place, but no system is 100% secure.")

                    Text("Third-Party Services")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("We use Supabase for authentication and database functionality. By using Scribo, you agree to Supabase’s handling of your data in accordance with their privacy policy.")

                    Text("Photo and Camera Access")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("• Scribo requests camera and photo library access to allow image capture and attachment.\n• These images are saved locally and not uploaded to any server.\n• You may revoke access at any time in your device settings.")

                    Text("Your Rights")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("You have the right to:\n• Access your personal data\n• Correct inaccurate information\n• Request deletion of your data\n• Export your data\n• Revoke permissions")

                    Text("Children's Privacy")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Scribo is not intended for children under the age of 13. We do not knowingly collect data from users under 13 years of age.")

                    Text("Contact Us")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("If you have any questions about this Privacy Policy, please contact us at:\nsantiparedes738@gmail.com")
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}
