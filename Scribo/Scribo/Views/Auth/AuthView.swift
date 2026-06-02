import SwiftUI

private enum AuthStyle {
    static let background = Color(red: 0.1, green: 0.1, blue: 0.2)
    static let link = Color.white.opacity(0.86)
}

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
private enum AuthDestination: Hashable {
    case forgotPassword
    case signUp(email: String)
}

struct LoginMethodView: View {
    @ObservedObject var authManager: AuthManager
    @State private var navigationPath = NavigationPath()
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPasswordStep = false
    @State private var showPasswordVisible = false
    @State private var isSigningIn = false
    @State private var isCheckingEmail = false
    @State private var showTermsOfUse = false
    @State private var showPrivacyPolicy = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AuthStyle.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Image("ScriboIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 70, height: 70)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            .padding(.top, 48)
                            
                        VStack(spacing: 16) {
                            Text(showPasswordStep ? "Welcome back" : "Log in or sign up")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            ZStack(alignment: .trailing) {
                                TextField("", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.emailAddress)
                                    .padding(.leading, 12)
                                    .padding(.trailing, !showPasswordStep && !email.isEmpty ? 44 : 12)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.9))
                                    .foregroundColor(.black)
                                    .cornerRadius(12)
                                
                                if !showPasswordStep && !email.isEmpty {
                                    Button(action: {
                                        email = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                            .frame(width: 24, height: 24)
                                    }
                                    .padding(.trailing, 14)
                                }
                            }
                            .overlay(
                                Group {
                                    if email.isEmpty {
                                        Text("Email")
                                            .foregroundColor(.gray)
                                            .padding(.leading, 14)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .allowsHitTesting(false)
                                    }
                                }
                            )
                            
                            if showPasswordStep {
                                ZStack(alignment: .trailing) {
                                    Group {
                                        if showPasswordVisible {
                                            TextField("", text: $password)
                                        } else {
                                            SecureField("", text: $password)
                                        }
                                    }
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(.leading, 12)
                                    .padding(.trailing, 44)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.9))
                                    .foregroundColor(.black)
                                    .cornerRadius(12)
                                    
                                    Button(action: {
                                        showPasswordVisible.toggle()
                                    }) {
                                        Image(systemName: showPasswordVisible ? "eye.fill" : "eye.slash.fill")
                                            .foregroundColor(.gray)
                                            .frame(width: 24, height: 24)
                                    }
                                    .padding(.trailing, 14)
                                }
                                .overlay(
                                    Group {
                                        if password.isEmpty {
                                            Text("Password")
                                                .foregroundColor(.gray)
                                                .padding(.leading, 14)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                )
                                
                                if !errorMessage.isEmpty {
                                    Text(errorMessage)
                                        .font(.system(size: 14))
                                        .foregroundColor(.red.opacity(0.9))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                Button(action: {
                                    navigationPath.append(AuthDestination.forgotPassword)
                                }) {
                                    Text("Forgot password?")
                                        .font(.system(size: 15))
                                        .foregroundColor(AuthStyle.link)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Button(action: handleContinueTapped) {
                                Group {
                                    if isSigningIn || isCheckingEmail {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text(showPasswordStep ? "Log In" : "Continue")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(red: 0.19, green: 0.20, blue: 0.25))
                                .cornerRadius(12)
                            }
                            .disabled(isSigningIn || isCheckingEmail)
                            .transaction { $0.animation = nil }
                            
                            if !showPasswordStep {
                                Text("or")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.vertical, 2)
                                
                                VStack(spacing: 16) {
                                    Button(action: {
                                        Task {
                                            await authManager.signInWithGoogle()
                                        }
                                    }) {
                                        HStack(spacing: 12) {
                                            Image("google_logo")
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
                                    
                                    Button(action: {
                                        Task {
                                            await authManager.signInWithApple()
                                        }
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "apple.logo")
                                                .font(.system(size: 24))
                                            Text("Continue with Apple")
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
                                
                                Button(action: {
                                    navigationPath.append(AuthDestination.forgotPassword)
                                }) {
                                    Text("Need help signing in?")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AuthStyle.link)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 8)
                                
                                Text("By signing up, you are creating a Scribo account and agree to Scribo's [Terms of Use](scribo://terms) and [Privacy Policy](scribo://privacy).")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.55))
                                    .tint(AuthStyle.link)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 8)
                                    .environment(\.openURL, OpenURLAction { url in
                                        switch url.host {
                                        case "terms":
                                            showTermsOfUse = true
                                        case "privacy":
                                            showPrivacyPolicy = true
                                        default:
                                            break
                                        }
                                        return .handled
                                    })
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                        .animation(.none, value: showPasswordStep)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if showPasswordStep {
                        Button(action: {
                            setPasswordStep(false)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20))
                                Text("Back")
                                    .font(.system(size: 16))
                            }
                            .foregroundColor(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: AuthDestination.self) { destination in
                switch destination {
                case .forgotPassword:
                    ForgotPasswordView(authManager: authManager, showForgotPassword: .constant(false))
                case .signUp(let signUpEmail):
                    SignUpView(
                        authManager: authManager,
                        showSignUp: .constant(false),
                        initialEmail: signUpEmail
                    )
                }
            }
        }
        .sheet(isPresented: $showTermsOfUse) {
            NavigationView {
                TermsOfUse()
                    .navigationBarItems(trailing: Button("Done") {
                        showTermsOfUse = false
                    })
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            NavigationView {
                PrivacyPolicy()
                    .navigationBarItems(trailing: Button("Done") {
                        showPrivacyPolicy = false
                    })
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
    
    private func setPasswordStep(_ active: Bool) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showPasswordStep = active
            if !active {
                password = ""
                errorMessage = ""
            }
        }
    }
    
    private func handleContinueTapped() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !showPasswordStep {
            guard !trimmedEmail.isEmpty else {
                errorMessage = "Please enter your email."
                showError = true
                return
            }
            
            isCheckingEmail = true
            errorMessage = ""
            Task {
                do {
                    let exists = try await authManager.checkEmailExists(email: trimmedEmail)
                    email = trimmedEmail
                    if exists {
                        setPasswordStep(true)
                    } else {
                        navigationPath.append(AuthDestination.signUp(email: email))
                    }
                } catch {
                    let details = error.localizedDescription.lowercased()
                    print("❌ Email check failed: \(error.localizedDescription)")
                    if details.contains("email_exists")
                        || details.contains("pgrst202")
                        || details.contains("42883")
                        || details.contains("permission denied") {
                        errorMessage = "Email check isn't configured in Supabase. Run Documentation/Supabase_email_exists.sql in the SQL editor for this project."
                    } else {
                        errorMessage = "Couldn't verify that email. Please try again."
                    }
                    showError = true
                }
                isCheckingEmail = false
            }
            return
        }
        
        guard !password.isEmpty else {
            errorMessage = "Please enter your password."
            showError = true
            return
        }
        
        isSigningIn = true
        errorMessage = ""
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSigningIn = false
        }
    }
}

// MARK: - Login View
struct LoginView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var password: String = ""
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var showTermsOfUse = false
    @State private var showPrivacyPolicy = false
    
    init(authManager: AuthManager, initialEmail: String = "") {
        self.authManager = authManager
        _email = State(initialValue: initialEmail)
    }
    
    var body: some View {
        Group {
            if showSignUp {
                SignUpView(authManager: authManager, showSignUp: $showSignUp)
            } else if showForgotPassword {
                ForgotPasswordView(authManager: authManager, showForgotPassword: $showForgotPassword)
            } else {
                ZStack {
                    AuthStyle.background
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Back Button
                        HStack {
                            Button(action: {
                                dismiss()
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
                                .foregroundColor(AuthStyle.link)
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
                                    .foregroundColor(AuthStyle.link)
                            }
                        }
                        .padding(.bottom, 32)
                        
                        Spacer()
                        
                        // Terms and Privacy
                        HStack(spacing: 16) {
                            Button(action: {
                                showTermsOfUse = true
                            }) {
                                Text("Terms of Use")
                                    .font(.system(size: 13))
                                    .foregroundColor(AuthStyle.link)
                            }
                            Text("|")
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                            Button(action: {
                                showPrivacyPolicy = true
                            }) {
                                Text("Privacy Policy")
                                    .font(.system(size: 13))
                                    .foregroundColor(AuthStyle.link)
                            }
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationBarHidden(true)
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
    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @Binding var showSignUp: Bool
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var isLoading = false
    @State private var showTermsOfUse = false
    @State private var showPrivacyPolicy = false
    
    init(authManager: AuthManager, showSignUp: Binding<Bool>, initialEmail: String = "") {
        self.authManager = authManager
        _showSignUp = showSignUp
        _email = State(initialValue: initialEmail)
    }
    
    var body: some View {
        ZStack {
            AuthStyle.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Back Button
                HStack {
                    Button(action: {
                        showSignUp = false
                        dismiss()
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
                            .foregroundColor(AuthStyle.link)
                    }
                }
                .padding(.bottom, 32)
                
                Spacer()
                
                // Terms and Privacy
                HStack(spacing: 16) {
                    Button(action: {
                        showTermsOfUse = true
                    }) {
                        Text("Terms of Use")
                            .font(.system(size: 13))
                            .foregroundColor(AuthStyle.link)
                    }
                    Text("|")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                    Button(action: {
                        showPrivacyPolicy = true
                    }) {
                        Text("Privacy Policy")
                            .font(.system(size: 13))
                            .foregroundColor(AuthStyle.link)
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
        .navigationBarHidden(true)
        .sheet(isPresented: $showTermsOfUse) {
            NavigationView {
                TermsOfUse()
                    .navigationBarItems(trailing: Button("Done") {
                        showTermsOfUse = false
                    })
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            NavigationView {
                PrivacyPolicy()
                    .navigationBarItems(trailing: Button("Done") {
                        showPrivacyPolicy = false
                    })
            }
        }
    }
}

// MARK: - Forgot Password View
struct ForgotPasswordView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var showTermsOfUse = false
    @State private var showPrivacyPolicy = false
    @Binding var showForgotPassword: Bool
    
    var body: some View {
        ZStack {
            AuthStyle.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Back Button
                HStack {
                    Button(action: {
                        showForgotPassword = false
                        dismiss()
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
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.bottom, 8)
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
                

                
                Spacer()
                
                // Terms and Privacy
                HStack(spacing: 16) {
                    Button(action: {
                        showTermsOfUse = true
                    }) {
                        Text("Terms of Use")
                            .font(.system(size: 13))
                            .foregroundColor(AuthStyle.link)
                    }
                    Text("|")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                    Button(action: {
                        showPrivacyPolicy = true
                    }) {
                        Text("Privacy Policy")
                            .font(.system(size: 13))
                            .foregroundColor(AuthStyle.link)
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
                dismiss()
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
        .navigationBarHidden(true)
        .sheet(isPresented: $showTermsOfUse) {
            NavigationView {
                TermsOfUse()
                    .navigationBarItems(trailing: Button("Done") {
                        showTermsOfUse = false
                    })
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            NavigationView {
                PrivacyPolicy()
                    .navigationBarItems(trailing: Button("Done") {
                        showPrivacyPolicy = false
                    })
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
    @State private var showTermsOfUse = false
    @State private var showPrivacyPolicy = false
    
    var body: some View {
        ZStack {
            AuthStyle.background
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
                        showTermsOfUse = true
                    }) {
                        Text("Terms of Use")
                            .font(.system(size: 13))
                            .foregroundColor(AuthStyle.link)
                    }
                    Text("|")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                    Button(action: {
                        showPrivacyPolicy = true
                    }) {
                        Text("Privacy Policy")
                            .font(.system(size: 13))
                            .foregroundColor(AuthStyle.link)
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
        .sheet(isPresented: $showTermsOfUse) {
            NavigationView {
                TermsOfUse()
                    .navigationBarItems(trailing: Button("Done") {
                        showTermsOfUse = false
                    })
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            NavigationView {
                PrivacyPolicy()
                    .navigationBarItems(trailing: Button("Done") {
                        showPrivacyPolicy = false
                    })
            }
        }
    }
}

