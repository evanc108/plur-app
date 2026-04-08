import Foundation
import Supabase
import Observation

enum AuthMethod {
    case email
    case phone
}

@Observable
final class AuthService {
    var isAuthenticated = false
    var isAwaitingConfirmation = false
    var pendingAuthMethod: AuthMethod = .email
    var confirmationEmail: String?
    var confirmationPhone: String?
    var currentUserId: UUID?

    private var client: SupabaseClient { SupabaseService.client }

    func checkSession() async {
        do {
            let session = try await client.auth.session
            currentUserId = session.user.id
            isAuthenticated = true
        } catch {
            isAuthenticated = false
            currentUserId = nil
        }
    }

    // MARK: - Email Auth

    func signUp(email: String, password: String) async throws {
        try await client.auth.signUp(email: email, password: password)
        confirmationEmail = email
        pendingAuthMethod = .email
        isAwaitingConfirmation = true
    }

    func verifyEmailOTP(email: String, code: String) async throws {
        let response = try await client.auth.verifyOTP(
            email: email,
            token: code,
            type: .signup
        )
        currentUserId = response.user.id
        completeAuth()
    }

    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        currentUserId = session.user.id
        isAuthenticated = true
    }

    // MARK: - Phone Auth

    func signInWithPhone(phone: String) async throws {
        try await client.auth.signInWithOTP(phone: phone)
        confirmationPhone = phone
        pendingAuthMethod = .phone
        isAwaitingConfirmation = true
    }

    func verifyPhoneOTP(phone: String, code: String) async throws {
        let response = try await client.auth.verifyOTP(
            phone: phone,
            token: code,
            type: .sms
        )
        currentUserId = response.user.id
        completeAuth()
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await client.auth.signOut()
        isAuthenticated = false
        currentUserId = nil
    }

    private func completeAuth() {
        isAuthenticated = true
        isAwaitingConfirmation = false
        confirmationEmail = nil
        confirmationPhone = nil
    }
}
