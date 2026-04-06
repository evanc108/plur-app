import Foundation
import Supabase
import Observation

@Observable
final class AuthService {
    var isAuthenticated = false
    var isAwaitingConfirmation = false
    var confirmationEmail: String?
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

    func signUp(email: String, password: String) async throws {
        try await client.auth.signUp(email: email, password: password)
        confirmationEmail = email
        isAwaitingConfirmation = true
    }

    /// Verify the 6-digit OTP code from the confirmation email.
    func verifyOTP(email: String, code: String) async throws {
        let session = try await client.auth.verifyOTP(
            email: email,
            token: code,
            type: .signup
        )
        currentUserId = session.user.id
        isAuthenticated = true
        isAwaitingConfirmation = false
        confirmationEmail = nil
    }

    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        currentUserId = session.user.id
        isAuthenticated = true
    }

    func signOut() async throws {
        try await client.auth.signOut()
        isAuthenticated = false
        currentUserId = nil
    }
}
