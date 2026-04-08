import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var otpCode = ""
    @State private var isSignUp = false
    @State private var usePhone = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("PLUR")
                .font(.system(size: 48, weight: .bold))

            if authService.isAwaitingConfirmation {
                otpView
            } else {
                formView
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - OTP Verification

    private var otpView: some View {
        let isPhone = authService.pendingAuthMethod == .phone
        let destination = isPhone
            ? (authService.confirmationPhone ?? phone)
            : (authService.confirmationEmail ?? email)
        let codeLength = isPhone ? 6 : 8

        return VStack(spacing: 16) {
            Image(systemName: isPhone ? "phone.badge.checkmark" : "envelope.badge")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text(isPhone ? "Check your messages" : "Check your email")
                .font(.headline)

            Text("Enter the \(codeLength)-digit code sent to \(destination)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField(String(repeating: "0", count: codeLength), text: $otpCode)
                .multilineTextAlignment(.center)
                .font(.title2.monospaced())
                .tracking(6)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button {
                Task { await verifyCode() }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Verify")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(otpCode.count != codeLength || isLoading)
        }
    }

    // MARK: - Login / Sign Up Form

    @ViewBuilder
    private var formView: some View {
        Picker("Auth method", selection: $usePhone) {
            Text("Email").tag(false)
            Text("Phone").tag(true)
        }
        .pickerStyle(.segmented)

        VStack(spacing: 16) {
            if usePhone {
                TextField("+1 (555) 000-0000", text: $phone)
                    .textContentType(.telephoneNumber)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .keyboardType(.phonePad)
                    #endif
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    #endif
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                SecureField("Password", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }

        if let errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
                .font(.caption)
        }

        Button {
            Task { await authenticate() }
        } label: {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text(usePhone ? "Send Code" : (isSignUp ? "Sign Up" : "Sign In"))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isLoading || (usePhone ? phone.isEmpty : (email.isEmpty || password.isEmpty)))

        if !usePhone {
            Button(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
                isSignUp.toggle()
                errorMessage = nil
            }
            .font(.footnote)
        }
    }

    // MARK: - Actions

    private func authenticate() async {
        isLoading = true
        errorMessage = nil
        do {
            if usePhone {
                try await authService.signInWithPhone(phone: phone)
            } else if isSignUp {
                try await authService.signUp(email: email, password: password)
            } else {
                try await authService.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func verifyCode() async {
        isLoading = true
        errorMessage = nil
        do {
            switch authService.pendingAuthMethod {
            case .phone:
                try await authService.verifyPhoneOTP(
                    phone: authService.confirmationPhone ?? phone,
                    code: otpCode
                )
            case .email:
                try await authService.verifyEmailOTP(
                    email: authService.confirmationEmail ?? email,
                    code: otpCode
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
