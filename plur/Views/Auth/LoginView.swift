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
        ZStack {
            Color.plurVoid.ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                Text("PLUR")
                    .font(.plurDisplay())
                    .foregroundStyle(Color.plurGhost)

                if authService.isAwaitingConfirmation {
                    otpView
                } else {
                    formView
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.xxl)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - OTP Verification

    private var otpView: some View {
        let isPhone = authService.pendingAuthMethod == .phone
        let destination = isPhone
            ? (authService.confirmationPhone ?? phone)
            : (authService.confirmationEmail ?? email)
        let codeLength = isPhone ? 6 : 8

        return VStack(spacing: Spacing.md) {
            Image(systemName: isPhone ? "phone.badge.checkmark" : "envelope.badge")
                .font(.system(size: 40))
                .foregroundStyle(Color.plurViolet)

            Text(isPhone ? "Check your messages" : "Check your email")
                .font(.plurH2())
                .foregroundStyle(Color.plurGhost)

            Text("Enter the \(codeLength)-digit code sent to \(destination)")
                .font(.plurBody())
                .foregroundStyle(Color.plurMuted)
                .multilineTextAlignment(.center)

            TextField(String(repeating: "0", count: codeLength), text: $otpCode)
                .multilineTextAlignment(.center)
                .font(.plurHeading(28).monospaced())
                .foregroundStyle(Color.plurGhost)
                .tracking(6)
                .keyboardType(.numberPad)
                .glassField()

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(Color.plurRose)
                    .font(.plurCaption())
            }

            Button {
                Task { await verifyCode() }
            } label: {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Verify")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(PLURButtonStyle())
            .disabled(otpCode.count != codeLength || isLoading)
            .opacity(otpCode.count != codeLength ? 0.5 : 1)
        }
    }

    // MARK: - Login / Sign Up Form

    @ViewBuilder
    private var formView: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach([false, true], id: \.self) { isPhone in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        usePhone = isPhone
                    }
                } label: {
                    Text(isPhone ? "Phone" : "Email")
                        .font(.plurBodyBold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            usePhone == isPhone
                                ? Color.plurViolet.opacity(0.25)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: Radius.activeTab)
                        )
                        .foregroundStyle(usePhone == isPhone ? Color.plurGhost : Color.plurMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: Radius.tab)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.tab)
                        .fill(Color.plurGlass)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.tab)
                        .stroke(Color.plurBorder, lineWidth: 1)
                )
        )

        VStack(spacing: Spacing.md) {
            if usePhone {
                TextField("+1 (555) 000-0000", text: $phone)
                    .font(.plurBody())
                    .foregroundStyle(Color.plurGhost)
                    .textContentType(.telephoneNumber)
                    .autocorrectionDisabled()
                    .keyboardType(.phonePad)
                    .glassField()
            } else {
                TextField("Email", text: $email)
                    .font(.plurBody())
                    .foregroundStyle(Color.plurGhost)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .glassField()

                SecureField("Password", text: $password)
                    .font(.plurBody())
                    .foregroundStyle(Color.plurGhost)
                    .textContentType(isSignUp ? .newPassword : .password)
                    .glassField()
            }
        }

        if let errorMessage {
            Text(errorMessage)
                .foregroundStyle(Color.plurRose)
                .font(.plurCaption())
        }

        Button {
            Task { await authenticate() }
        } label: {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
            } else {
                Text(usePhone ? "Send Code" : (isSignUp ? "Sign Up" : "Sign In"))
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(PLURButtonStyle())
        .disabled(isLoading || (usePhone ? phone.isEmpty : (email.isEmpty || password.isEmpty)))
        .opacity(isLoading || (usePhone ? phone.isEmpty : (email.isEmpty || password.isEmpty)) ? 0.5 : 1)

        if !usePhone {
            Button(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
                isSignUp.toggle()
                errorMessage = nil
            }
            .font(.plurCaption())
            .foregroundStyle(Color.plurMuted)
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
