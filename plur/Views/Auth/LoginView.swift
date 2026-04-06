import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @State private var email = ""
    @State private var password = ""
    @State private var otpCode = ""
    @State private var isSignUp = false
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
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text("Check your email")
                .font(.headline)

            Text("Enter the 8-digit code sent to \(authService.confirmationEmail ?? email)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("00000000", text: $otpCode)
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
            .disabled(otpCode.count != 8 || isLoading)
        }
    }

    // MARK: - Login / Sign Up Form

    @ViewBuilder
    private var formView: some View {
        VStack(spacing: 16) {
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
                Text(isSignUp ? "Sign Up" : "Sign In")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(email.isEmpty || password.isEmpty || isLoading)

        Button(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
            isSignUp.toggle()
            errorMessage = nil
        }
        .font(.footnote)
    }

    // MARK: - Actions

    private func authenticate() async {
        isLoading = true
        errorMessage = nil
        do {
            if isSignUp {
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
            try await authService.verifyOTP(
                email: authService.confirmationEmail ?? email,
                code: otpCode
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
