import Foundation
import Supabase
import Combine

@MainActor
final class AuthService: ObservableObject {
    @Published var userId: UUID?
    @Published var email: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    var isAuthenticated: Bool { userId != nil }

    func restoreSession() async {
        do {
            let session = try await SupabaseService.client.auth.session
            userId = session.user.id
            email = session.user.email
        } catch {
            userId = nil
            email = nil
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let session = try await SupabaseService.client.auth.signIn(email: email, password: password)
            userId = session.user.id
            self.email = session.user.email
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Returns true if signup succeeded but requires email confirmation (no session yet).
    @discardableResult
    func signUp(email: String, password: String) async -> SignUpResult {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await SupabaseService.client.auth.signUp(
                email: email,
                password: password,
                redirectTo: URL(string: "https://cache.kozlowski.download/auth/callback")
            )
            if response.session != nil {
                userId = response.user.id
                self.email = response.user.email
                return .signedIn
            } else {
                // confirm email enabled — user needs to click the link
                return .needsConfirmation
            }
        } catch {
            errorMessage = error.localizedDescription
            return .failure
        }
    }

    enum SignUpResult { case signedIn, needsConfirmation, failure }

    func signOut() async {
        do {
            try await SupabaseService.client.auth.signOut()
            userId = nil
            email = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updatePassword(newPassword: String) async -> Bool {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await SupabaseService.client.auth.update(user: UserAttributes(password: newPassword))
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func sendPasswordReset(email: String) async -> Bool {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            try await SupabaseService.client.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "https://cache.kozlowski.download/auth/callback?next=/reset-password")
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteAccount() async -> Bool {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            try await SupabaseService.client.rpc("delete_my_account").execute()
            try? await SupabaseService.client.auth.signOut()
            userId = nil
            email = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
