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
                    Text("• Account Information: Email address and name for authentication\n• Notes: Text content and images you create\n• Photos: Images you capture or upload\n• Device Information: Basic device information for app functionality")
                    
                    Text("How We Use Your Information")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("• To provide and maintain our service\n• To notify you about changes to our app\n• To provide customer support\n• To detect, prevent and address technical issues")
                    
                    Text("Data Storage")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("• Your notes and images are stored securely on your device\n• Account information is stored securely using Supabase authentication\n• We implement appropriate security measures to protect your data")
                    
                    Text("Photo Access")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("• We request access to your camera and photo library to enable note creation with images\n• Photos are stored locally on your device\n• You can revoke photo access at any time through your device settings")
                    
                    Text("Data Security")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("We implement appropriate security measures to protect your personal information. However, no method of transmission over the Internet or electronic storage is 100% secure.")
                    
                    Text("Your Rights")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("You have the right to:\n• Access your personal data\n• Correct inaccurate data\n• Request deletion of your data\n• Export your data\n• Opt-out of certain data collection")
                    
                    Text("Contact Us")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("If you have any questions about this Privacy Policy, please contact us at:\n[Your Contact Information]")
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}

#Preview {
    PrivacyPolicy()
} 