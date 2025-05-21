import SwiftUI

struct SidebarView: View {
    @Binding var isShowing: Bool
    @ObservedObject var authManager: AuthManager
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sidebarSection(title: "Appearance") {
                        appearanceSection
                    }
                    
                    sidebarSection(title: "Account") {
                        accountSection
                    }
                }
                .padding(.top)
            }
            
            Spacer()
            
            sidebarFooter
        }
        .frame(width: 280)
        .background(Color.appBackground)
        .edgesIgnoringSafeArea(.bottom)
    }
    
    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scribo")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.appAccent)
            
            Text("Your AI Study Assistant")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appHeaderBackground)
    }
    
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Dark Mode", isOn: $isDarkMode)
                .tint(.appAccent)
        }
    }
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let user = authManager.currentUser {
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Button(action: {
                Task {
                    await authManager.signOut()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.right.square")
                    Text("Sign Out")
                }
                .foregroundColor(.red)
            }
        }
    }
    
    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appHeaderBackground)
    }
    
    private func sidebarSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.appAccent)
            
            content()
        }
        .padding(.horizontal)
    }
} 