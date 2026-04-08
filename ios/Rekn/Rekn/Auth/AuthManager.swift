import Foundation
import Observation

@Observable
final class AuthManager: @unchecked Sendable {
    var isAuthenticated = false
    var isGuest = false
    var currentUser: AuthUser?

    struct AuthUser {
        let id: String
        let name: String?
        let phoneNumber: String?
        let isGuest: Bool
        let imageUrl: String?
    }

    func checkExistingSession() async {
        guard let _ = await KeychainService.shared.getToken() else {
            isAuthenticated = false
            return
        }

        do {
            let user: MeResponse = try await APIClient.shared.request(
                Endpoint(path: "user")
            )
            currentUser = AuthUser(
                id: user.id,
                name: user.name,
                phoneNumber: user.phoneNumber,
                isGuest: false,
                imageUrl: user.image
            )
            isAuthenticated = true
        } catch {
            await KeychainService.shared.deleteToken()
            isAuthenticated = false
        }
    }

    // MARK: - Send OTP

    func sendOtp(phoneNumber: String) async throws(APIError) {
        struct Body: Encodable { let phoneNumber: String }
        let _: SendOtpResponse = try await APIClient.shared.request(
            Endpoint(path: "auth/send-otp", method: .post, body: Body(phoneNumber: phoneNumber))
        )
    }

    // MARK: - Verify OTP

    func verifyOtp(phoneNumber: String, code: String) async throws(APIError) -> VerifyResult {
        struct Body: Encodable { let phoneNumber: String; let code: String }
        let result: VerifyOtpResponse = try await APIClient.shared.request(
            Endpoint(path: "auth/verify-otp", method: .post, body: Body(phoneNumber: phoneNumber, code: code))
        )

        if result.isNewUser {
            return .newUser(phoneNumber: result.phoneNumber ?? phoneNumber)
        }

        if let token = result.token, let user = result.user {
            await KeychainService.shared.saveToken(token)
            currentUser = AuthUser(
                id: user.id,
                name: user.name,
                phoneNumber: user.phoneNumber,
                isGuest: user.isGuest,
                imageUrl: nil
            )
            isGuest = user.isGuest
            isAuthenticated = true
            return .existingUser
        }

        throw .badRequest("Unexpected response")
    }

    // MARK: - Complete Setup

    func completeSetup(name: String, phoneNumber: String) async throws(APIError) {
        struct Body: Encodable { let name: String; let phoneNumber: String }
        let result: SetupResponse = try await APIClient.shared.request(
            Endpoint(path: "auth/complete-setup", method: .post, body: Body(name: name, phoneNumber: phoneNumber))
        )

        await KeychainService.shared.saveToken(result.token)
        currentUser = AuthUser(
            id: result.user.id,
            name: result.user.name,
            phoneNumber: result.user.phoneNumber,
            isGuest: result.user.isGuest,
            imageUrl: nil
        )
        isGuest = false
        isAuthenticated = true
    }

    // MARK: - Guest Session

    func startGuestSession() async throws(APIError) {
        let result: SetupResponse = try await APIClient.shared.request(
            Endpoint(path: "auth/guest", method: .post)
        )

        await KeychainService.shared.saveToken(result.token)
        currentUser = AuthUser(
            id: result.user.id,
            name: result.user.name,
            phoneNumber: nil,
            isGuest: true,
            imageUrl: nil
        )
        isGuest = true
        isAuthenticated = true
    }

    // MARK: - Update Image

    func updateImageUrl(_ url: String?) {
        guard let user = currentUser else { return }
        currentUser = AuthUser(
            id: user.id,
            name: user.name,
            phoneNumber: user.phoneNumber,
            isGuest: user.isGuest,
            imageUrl: url
        )
    }

    // MARK: - Sign Out

    func signOut() async {
        await KeychainService.shared.deleteToken()
        currentUser = nil
        isGuest = false
        isAuthenticated = false
    }
}

// MARK: - Result Types

enum VerifyResult {
    case existingUser
    case newUser(phoneNumber: String)
}

// MARK: - Response Models

private struct SendOtpResponse: Decodable {
    let sent: Bool
    let phoneNumber: String
}

private struct VerifyOtpResponse: Decodable {
    let isNewUser: Bool
    let token: String?
    let phoneNumber: String?
    let user: UserResponse?
}

private struct SetupResponse: Decodable {
    let token: String
    let user: UserResponse
}

private struct UserResponse: Decodable {
    let id: String
    let name: String?
    let phoneNumber: String?
    let isGuest: Bool
}

private struct MeResponse: Decodable {
    let id: String
    let name: String?
    let phoneNumber: String?
    let image: String?
}
