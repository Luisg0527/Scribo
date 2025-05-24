import SwiftUI

// MARK: - Login View
struct LoginView: View {
    @ObservedObject var authManager: AuthManager
    @State private var email: String = "santiparedes738@gmail.com"
    @State private var password: String = "admin"
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Logo
                Image("ScriboIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .padding(.top, 80)
                    .padding(.bottom, 40)
                
                // Welcome Text
                Text("Welcome back")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)
                
                Text("Sign in to continue")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 40)
                
                // Input Fields
                VStack(spacing: 16) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        TextField("Enter your email", text: $email)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .textInputAutocapitalization(.never)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        HStack {
                            SecureField("Enter your password", text: $password)
                                .foregroundColor(.black)
                            Image(systemName: "eye.slash")
                                .foregroundColor(.gray)
                                .frame(width: 20, height: 20)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                // Forgot Password
                HStack {
                    Button(action: {
                        showForgotPassword = true
                    }) {
                        Text("Forgot password?")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 124/255, green: 207/255, blue: 255/255))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                
                // Sign In Button
                Button(action: {
                    Task {
                        do {
                            try await authManager.signIn(email: email, password: password)
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }) {
                    Text("Sign In")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0/255, green: 122/255, blue: 255/255))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                // Sign Up Link
                HStack {
                    Text("Don't have an account?")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    Button(action: {
                        showSignUp = true
                    }) {
                        Text("Sign up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 124/255, green: 207/255, blue: 255/255))
                    }
                }
                .padding(.bottom, 32)
                
                // Terms and Privacy
                HStack(spacing: 16) {
                    Button(action: {
                        // Handle Terms of Use
                    }) {
                        Text("Terms of Use")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 124/255, green: 207/255, blue: 255/255))
                    }
                    Text("•")
                        .foregroundColor(.white.opacity(0.7))
                    Button(action: {
                        // Handle Privacy Policy
                    }) {
                        Text("Privacy Policy")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 124/255, green: 207/255, blue: 255/255))
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .background(Color(hex: "#303240"))
        .edgesIgnoringSafeArea(.all)
        .sheet(isPresented: $showSignUp) {
            SignUpView(authManager: authManager)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(authManager: authManager)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

// MARK: - Sign Up View
struct SignUpView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Logo
                Image("ScriboIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .padding(.top, 80)
                    .padding(.bottom, 40)
                
                // Welcome Text
                Text("Create Account")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)
                
                Text("Sign up to get started")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 40)
                
                // Input Fields
                VStack(spacing: 16) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        TextField("Enter your email", text: $email)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .textInputAutocapitalization(.never)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        SecureField("Enter your password", text: $password)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    
                    // Confirm Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        SecureField("Confirm your password", text: $confirmPassword)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                
                // Sign Up Button
                Button(action: {
                    Task {
                        do {
                            if password != confirmPassword {
                                errorMessage = "Passwords do not match"
                                showError = true
                                return
                            }
                            try await authManager.signUp(email: email, password: password)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }) {
                    Text("Sign Up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0/255, green: 122/255, blue: 255/255))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                // Sign In Link
                HStack {
                    Text("Already have an account?")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Sign in")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 124/255, green: 207/255, blue: 255/255))
                    }
                }
                .padding(.bottom, 32)
                
                // Terms and Privacy
                HStack(spacing: 16) {
                    Button(action: {
                        // Handle Terms of Use
                    }) {
                        Text("Terms of Use")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 124/255, green: 207/255, blue: 255/255))
                    }
                    Text("•")
                        .foregroundColor(.white.opacity(0.7))
                    Button(action: {
                        // Handle Privacy Policy
                    }) {
                        Text("Privacy Policy")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 124/255, green: 207/255, blue: 255/255))
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .background(Color(hex: "#303240"))
        .edgesIgnoringSafeArea(.all)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

// MARK: - Forgot Password View
struct ForgotPasswordView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var email: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Logo
                Image("ScriboIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .padding(.top, 80)
                    .padding(.bottom, 40)
                
                // Welcome Text
                Text("Reset Password")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)
                
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                
                // Input Fields
                VStack(spacing: 16) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        TextField("Enter your email", text: $email)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .textInputAutocapitalization(.never)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                
                // Reset Button
                Button(action: {
                    Task {
                        do {
                            try await authManager.resetPassword(email: email)
                            showSuccess = true
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }) {
                    Text("Send Reset Link")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0/255, green: 122/255, blue: 255/255))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                // Back to Login
                Button(action: {
                    dismiss()
                }) {
                    Text("Back to Login")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 124/255, green: 207/255, blue: 255/255))
                }
                .padding(.bottom, 32)
                
                // Terms and Privacy
                HStack(spacing: 16) {
                    Button(action: {
                        // Handle Terms of Use
                    }) {
                        Text("Terms of Use")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 124/255, green: 207/255, blue: 255/255))
                    }
                    Text("•")
                        .foregroundColor(.white.opacity(0.7))
                    Button(action: {
                        // Handle Privacy Policy
                    }) {
                        Text("Privacy Policy")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 124/255, green: 207/255, blue: 255/255))
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .background(Color(hex: "#303240"))
        .edgesIgnoringSafeArea(.all)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Password reset link has been sent to your email.")
        }
    }
}

