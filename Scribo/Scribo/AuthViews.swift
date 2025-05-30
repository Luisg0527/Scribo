import SwiftUI

// Add this at the top of the file, after the imports
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(14)
            .background(Color.white)
            .foregroundColor(.black)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.25), radius: 4, y: 4)
    }
}

// Add this at the top of the file, after the imports
struct CustomSecureFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.trailing, 40) // Make room for the eye icon
            .padding(.leading, 14)
            .padding(.vertical, 14)
            .background(Color.white)
            .foregroundColor(.black)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.25), radius: 4, y: 4)
    }
}

// MARK: - Login Method View
struct LoginMethodView: View {
    @ObservedObject var authManager: AuthManager
    @State private var showLogin = false
    @State private var showSignUp = false
    @State private var animateBackground = false
    
    var body: some View {
        Group {
            if showLogin {
                LoginView(authManager: authManager, showLogin: $showLogin)
            } else if showSignUp {
                SignUpView(authManager: authManager, showSignUp: $showSignUp)
            } else {
                ZStack {
                    // Animated background gradient
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.1, green: 0.1, blue: 0.2),
                            Color(red: 0.2, green: 0.2, blue: 0.3)
                        ]),
                        startPoint: animateBackground ? .topLeading : .bottomLeading,
                        endPoint: animateBackground ? .bottomTrailing : .topTrailing
                    )
                    .ignoresSafeArea()
                    .onAppear {
                        withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: true)) {
                            animateBackground.toggle()
                        }
                    }
                    
                    // Content
                    ScrollView {
                        VStack(spacing: 32) {
                            // Logo and Welcome Text
                            VStack(spacing: 24) {
                                Image("ScriboIcon")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 100, height: 100)
                                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                                
                                VStack(spacing: 8) {
                                    Text("Welcome to Scribo")
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("Your AI-powered writing companion")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding(.top, 60)
                            
                            // Social Login Buttons
                            VStack(spacing: 16) {
                                /* Apple Sign In
                                Button(action: {
                                    Task {
                                        await authManager.signInWithApple()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "apple.logo")
                                            .font(.system(size: 20))
                                        Text("Continue with Apple")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                }
                                */
                                // Google Sign In
                                Button(action: {
                                    Task {
                                        await authManager.signInWithGoogle()
                                    }
                                }) {
                                    HStack {
                                        Image("google_logo") // Make sure to add this asset
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                        Text("Continue with Google")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color(red: 0.2, green: 0.2, blue: 0.25))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                            
                            // Divider
                            HStack {
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 1)
                                Text("or")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.horizontal, 16)
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 1)
                            }
                            .padding(.horizontal, 24)
                            
                            // Email Sign Up Button
                            Button(action: {
                                showSignUp = true
                            }) {
                                Text("Sign up with email")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color(red: 0.2, green: 0.2, blue: 0.25))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal, 24)
                            
                            // Login Link
                            Button(action: {
                                showLogin = true
                            }) {
                                Text("Already have an account? Log in")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            // Terms and Privacy
                            VStack(spacing: 16) {
                                Text("By continuing, you agree to our")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.5))
                                
                                HStack(spacing: 16) {
                                    Button(action: {
                                        // Present Terms of Use
                                        let termsView = TermsOfUse()
                                        let hostingController = UIHostingController(rootView: termsView)
                                        UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)
                                    }) {
                                        Text("Terms of Use")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    
                                    Text("•")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.5))
                                    
                                    Button(action: {
                                        // Present Privacy Policy
                                        let privacyView = PrivacyPolicy()
                                        let hostingController = UIHostingController(rootView: privacyView)
                                        UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)
                                    }) {
                                        Text("Privacy Policy")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                            }
                            .padding(.bottom, 32)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Login View
struct LoginView: View {
    @ObservedObject var authManager: AuthManager
    @State private var email: String = "santiparedes738@gmail.com"
    @State private var password: String = "admin"
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Binding var showLogin: Bool
    @State private var showPassword = false
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if showSignUp {
                SignUpView(authManager: authManager, showSignUp: $showSignUp)
            } else if showForgotPassword {
                ForgotPasswordView(authManager: authManager, showForgotPassword: $showForgotPassword)
            } else {
                ZStack {
                    Color.black
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Back Button
                        HStack {
                            Button(action: {
                                showLogin = false
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 20))
                                    Text("Back")
                                        .font(.system(size: 16))
                                }
                                .foregroundColor(.white)
                            }
                            .padding(.horizontal)
                            .padding(.top, 16)
                            Spacer()
                        }
                        
                        // Logo
                        Image("ScriboIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .padding(.top, 40)
                            .padding(.bottom, 84)
                        
                        // Welcome Text
                        Text("Welcome back")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.bottom, 16)
                        
                        // Input Fields
                        VStack(spacing: 0) {
                            // Email Field
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Email address*")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.black.opacity(0.5))
                                TextField("", text: $email)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.emailAddress)
                                    .overlay(
                                        Group {
                                            if email.isEmpty {
                                                Text("Enter your email")
                                                    .foregroundColor(.gray)
                                                    .padding(.leading, 14)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .allowsHitTesting(false)
                                            }
                                        }
                                    )
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Password*")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.black.opacity(0.5))
                                ZStack(alignment: .trailing) {
                                    if showPassword {
                                        TextField("", text: $password)
                                            .textFieldStyle(CustomSecureFieldStyle())
                                    } else {
                                        SecureField("", text: $password)
                                            .textFieldStyle(CustomSecureFieldStyle())
                                    }
                                    Button(action: {
                                        showPassword.toggle()
                                    }) {
                                        Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                                            .foregroundColor(.gray)
                                            .frame(width: 24, height: 24)
                                    }
                                    .padding(.trailing, 14)
                                }
                                .overlay(
                                    Group {
                                        if password.isEmpty {
                                            Text("Enter your password")
                                                .foregroundColor(.gray)
                                                .padding(.leading, 14)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        
                        // Error Message
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 16)
                        }
                        
                        // Forgot Password
                        Button(action: {
                            showForgotPassword = true
                        }) {
                            Text("Forgot password?")
                                .font(.system(size: 15))
                                .foregroundColor(Color(red: 0.48, green: 0.81, blue: 1).opacity(0.86))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        
                        // Sign In Button
                        Button(action: {
                            isLoading = true
                            errorMessage = ""
                            Task {
                                do {
                                    try await authManager.signIn(email: email, password: password)
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                                isLoading = false
                            }
                        }) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Continue")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.19, green: 0.20, blue: 0.25))
                        .cornerRadius(14)
                        .shadow(color: Color.black.opacity(0.25), radius: 4, y: 4)
                        .disabled(isLoading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        
                        // Sign Up Link
                        HStack {
                            Text("Don't have an account?")
                                .font(.system(size: 15))
                                .foregroundColor(Color.white.opacity(0.86))
                            Button(action: {
                                showSignUp = true
                            }) {
                                Text("Sign up")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(red: 0.48, green: 0.81, blue: 1).opacity(0.86))
                            }
                        }
                        .padding(.bottom, 32)
                        
                        Spacer()
                        
                        // Terms and Privacy
                        HStack(spacing: 16) {
                            Button(action: {
                                // Present Terms of Use
                                let termsView = TermsOfUse()
                                let hostingController = UIHostingController(rootView: termsView)
                                UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)
                            }) {
                                Text("Terms of Use")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(red: 0.48, green: 0.81, blue: 1).opacity(0.86))
                            }
                            Text("|")
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                            Button(action: {
                                // Present Privacy Policy
                                let privacyView = PrivacyPolicy()
                                let hostingController = UIHostingController(rootView: privacyView)
                                UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)
                            }) {
                                Text("Privacy Policy")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(red: 0.48, green: 0.81, blue: 1).opacity(0.86))
                            }
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: authManager.error) { oldValue, newValue in
            if let error = newValue {
                errorMessage = error
                showError = true
            }
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
    @Binding var showSignUp: Bool
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Back Button
                HStack {
                    Button(action: {
                        showSignUp = false
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20))
                            Text("Back")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    Spacer()
                }
                
                // Logo
                Image("ScriboIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .padding(.top, 40)
                    .padding(.bottom, 84)
                
                // Welcome Text
                Text("Create Account")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 16)
                
                // Input Fields
                VStack(spacing: 0) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Email address*")
                            .font(.system(size: 16))
                            .foregroundColor(Color.black.opacity(0.5))
                        TextField("", text: $email)
                            .textFieldStyle(CustomTextFieldStyle())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .overlay(
                                Group {
                                    if email.isEmpty {
                                        Text("Enter your email")
                                            .foregroundColor(.gray)
                                            .padding(.leading, 14)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .allowsHitTesting(false)
                                    }
                                }
                            )
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Password*")
                            .font(.system(size: 16))
                            .foregroundColor(Color.black.opacity(0.5))
                        ZStack(alignment: .trailing) {
                            if showPassword {
                                TextField("", text: $password)
                                    .textFieldStyle(CustomSecureFieldStyle())
                            } else {
                                SecureField("", text: $password)
                                    .textFieldStyle(CustomSecureFieldStyle())
                            }
                            Button(action: {
                                showPassword.toggle()
                            }) {
                                Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 24, height: 24)
                            }
                            .padding(.trailing, 14)
                        }
                        .overlay(
                            Group {
                                if password.isEmpty {
                                    Text("Enter your password")
                                        .foregroundColor(.gray)
                                        .padding(.leading, 14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .allowsHitTesting(false)
                                }
                            }
                        )
                    }
                    
                    // Confirm Password Field
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Confirm Password*")
                            .font(.system(size: 16))
                            .foregroundColor(Color.black.opacity(0.5))
                        ZStack(alignment: .trailing) {
                            if showConfirmPassword {
                                TextField("", text: $confirmPassword)
                                    .textFieldStyle(CustomSecureFieldStyle())
                            } else {
                                SecureField("", text: $confirmPassword)
                                    .textFieldStyle(CustomSecureFieldStyle())
                            }
                            Button(action: {
                                showConfirmPassword.toggle()
                            }) {
                                Image(systemName: showConfirmPassword ? "eye.fill" : "eye.slash.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 24, height: 24)
                            }
                            .padding(.trailing, 14)
                        }
                        .overlay(
                            Group {
                                if confirmPassword.isEmpty {
                                    Text("Confirm your password")
                                        .foregroundColor(.gray)
                                        .padding(.leading, 14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .allowsHitTesting(false)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                // Error Message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
                
                // Sign Up Button
                Button(action: {
                    isLoading = true
                    errorMessage = ""
                    
                    // Validate passwords match
                    if password != confirmPassword {
                        errorMessage = "Passwords do not match"
                        isLoading = false
                        return
                    }
                    
                    // Validate password length
                    if password.count < 6 {
                        errorMessage = "Password must be at least 6 characters long"
                        isLoading = false
                        return
                    }
                    
                    Task {
                        do {
                            try await authManager.signUp(email: email, password: password)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                        isLoading = false
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Continue")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(red: 0.19, green: 0.20, blue: 0.25))
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.25), radius: 4, y: 4)
                .disabled(isLoading)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                // Sign In Link
                HStack {
                    Text("Already have an account?")
                        .font(.system(size: 15))
                        .foregroundColor(Color.white.opacity(0.86))
                    Button(action: {
                        showSignUp = false
                    }) {
                        Text("Sign in")
                            .font(.system(size: 15))
                            .foregroundColor(Color(red: 0.48, green: 0.81, blue: 1).opacity(0.86))
                    }
                }
                .padding(.bottom, 32)
                
                Spacer()
                
                // Terms and Privacy
                HStack(spacing: 16) {
                    Button(action: {
                        // Present Terms of Use
                        let termsView = TermsOfUse()
                        let hostingController = UIHostingController(rootView: termsView)
                        UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)
                    }) {
                        Text("Terms of Use")
                            .font(.system(size: 15))
                            .foregroundColor(Color(red: 0.48, green: 0.81, blue: 1).opacity(0.86))
                    }
                    Text("|")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                    Button(action: {
                        // Present Privacy Policy
                        let privacyView = PrivacyPolicy()
                        let hostingController = UIHostingController(rootView: privacyView)
                        UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)
                    }) {
                        Text("Privacy Policy")
                            .font(.system(size: 15))
                            .foregroundColor(Color(red: 0.48, green: 0.81, blue: 1).opacity(0.86))
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: authManager.error) { oldValue, newValue in
            if let error = newValue {
                errorMessage = error
                showError = true
            }
        }
    }
}

// MARK: - Forgot Password View
struct ForgotPasswordView: View {
    @ObservedObject var authManager: AuthManager
    @State private var email: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @Binding var showForgotPassword: Bool
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Back Button
                HStack {
                    Button(action: {
                        showForgotPassword = false
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20))
                            Text("Back")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    Spacer()
                }
                
                // Logo
                Image("ScriboIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .padding(.top, 40)
                    .padding(.bottom, 84)
                
                // Welcome Text
                Text("Reset Password")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 16)
                
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                
                // Input Fields
                VStack(spacing: 0) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Email address*")
                            .font(.system(size: 16))
                            .foregroundColor(Color.black.opacity(0.5))
                        TextField("", text: $email)
                            .textFieldStyle(CustomTextFieldStyle())
                            .textInputAutocapitalization(.never)
                            .overlay(
                                Group {
                                    if email.isEmpty {
                                        Text("Enter your email")
                                            .foregroundColor(.gray)
                                            .padding(.leading, 14)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .allowsHitTesting(false)
                                    }
                                }
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
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
                    Text("Continue")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.19, green: 0.20, blue: 0.25))
                        .cornerRadius(14)
                        .shadow(color: Color.black.opacity(0.25), radius: 4, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                // Back to Login
                Button(action: {
                    showForgotPassword = false
                }) {
                    Text("Back to Login")
                        .font(.system(size: 15))
                        .foregroundColor(Color(red: 0.48, green: 0.81, blue: 1).opacity(0.86))
                }
                .padding(.bottom, 32)
                
                Spacer()
                
                // Terms and Privacy
                HStack(spacing: 16) {
                    Button(action: {
                        // Present Terms of Use
                        let termsView = TermsOfUse()
                        let hostingController = UIHostingController(rootView: termsView)
                        UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)
                    }) {
                        Text("Terms of Use")
                            .font(.system(size: 15))
                            .foregroundColor(Color(red: 0.48, green: 0.81, blue: 1).opacity(0.86))
                    }
                    Text("|")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                    Button(action: {
                        // Present Privacy Policy
                        let privacyView = PrivacyPolicy()
                        let hostingController = UIHostingController(rootView: privacyView)
                        UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)
                    }) {
                        Text("Privacy Policy")
                            .font(.system(size: 15))
                            .foregroundColor(Color(red: 0.48, green: 0.81, blue: 1).opacity(0.86))
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {
                showForgotPassword = false
            }
        } message: {
            Text("Password reset link has been sent to your email.")
        }
        .onChange(of: authManager.error) { oldValue, newValue in
            if let error = newValue {
                errorMessage = error
                showError = true
            }
        }
    }
}

// Add this after the ForgotPasswordView
struct NewPasswordView: View {
    @ObservedObject var authManager: AuthManager
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Logo
                Image("ScriboIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .padding(.top, 40)
                    .padding(.bottom, 84)
                
                // Welcome Text
                Text("Set New Password")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 16)
                
                Text("Please enter your new password below.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                
                // Input Fields
                VStack(spacing: 0) {
                    // New Password Field
                    VStack(alignment: .leading, spacing: 0) {
                        Text("New Password*")
                            .font(.system(size: 16))
                            .foregroundColor(Color.black.opacity(0.5))
                        ZStack(alignment: .trailing) {
                            if showPassword {
                                TextField("", text: $newPassword)
                                    .textFieldStyle(CustomSecureFieldStyle())
                            } else {
                                SecureField("", text: $newPassword)
                                    .textFieldStyle(CustomSecureFieldStyle())
                            }
                            Button(action: {
                                showPassword.toggle()
                            }) {
                                Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 24, height: 24)
                            }
                            .padding(.trailing, 14)
                        }
                        .overlay(
                            Group {
                                if newPassword.isEmpty {
                                    Text("Enter new password")
                                        .foregroundColor(.gray)
                                        .padding(.leading, 14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .allowsHitTesting(false)
                                }
                            }
                        )
                    }
                    
                    // Confirm Password Field
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Confirm Password*")
                            .font(.system(size: 16))
                            .foregroundColor(Color.black.opacity(0.5))
                        ZStack(alignment: .trailing) {
                            if showConfirmPassword {
                                TextField("", text: $confirmPassword)
                                    .textFieldStyle(CustomSecureFieldStyle())
                            } else {
                                SecureField("", text: $confirmPassword)
                                    .textFieldStyle(CustomSecureFieldStyle())
                            }
                            Button(action: {
                                showConfirmPassword.toggle()
                            }) {
                                Image(systemName: showConfirmPassword ? "eye.fill" : "eye.slash.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 24, height: 24)
                            }
                            .padding(.trailing, 14)
                        }
                        .overlay(
                            Group {
                                if confirmPassword.isEmpty {
                                    Text("Confirm new password")
                                        .foregroundColor(.gray)
                                        .padding(.leading, 14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .allowsHitTesting(false)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                // Update Password Button
                Button(action: {
                    Task {
                        if newPassword != confirmPassword {
                            errorMessage = "Passwords do not match"
                            showError = true
                            return
                        }
                        await authManager.updatePassword(newPassword: newPassword)
                        showSuccess = true
                    }
                }) {
                    Text("Update Password")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.19, green: 0.20, blue: 0.25))
                        .cornerRadius(14)
                        .shadow(color: Color.black.opacity(0.25), radius: 4, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                Spacer()
                
                // Terms and Privacy
                HStack(spacing: 16) {
                    Button(action: {
                        // Present Terms of Use
                        let termsView = TermsOfUse()
                        let hostingController = UIHostingController(rootView: termsView)
                        UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)
                    }) {
                        Text("Terms of Use")
                            .font(.system(size: 15))
                            .foregroundColor(Color(red: 0.48, green: 0.81, blue: 1).opacity(0.86))
                    }
                    Text("|")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                    Button(action: {
                        // Present Privacy Policy
                        let privacyView = PrivacyPolicy()
                        let hostingController = UIHostingController(rootView: privacyView)
                        UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)
                    }) {
                        Text("Privacy Policy")
                            .font(.system(size: 15))
                            .foregroundColor(Color(red: 0.48, green: 0.81, blue: 1).opacity(0.86))
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {
                // Navigate back to login
                authManager.isResettingPassword = false
            }
        } message: {
            Text("Your password has been updated successfully.")
        }
    }
}

