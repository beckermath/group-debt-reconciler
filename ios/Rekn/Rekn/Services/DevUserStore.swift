import Foundation
import Observation

#if DEBUG

@Observable
final class DevUserStore: @unchecked Sendable {
    enum Availability {
        case unknown
        case available
        case unavailable
    }

    var availability: Availability = .unknown
    var users: [APITestUser] = []
    var isSwitching = false
    var lastError: String?

    /// Probe the dev endpoint. Returns true if dev mode is active on the server.
    func probe() async {
        do {
            let result: [APITestUser] = try await APIClient.shared.request(
                DevEndpoint.testUsers()
            )
            users = result
            availability = .available
        } catch {
            users = []
            availability = .unavailable
        }
    }

    /// Switch to the given test user. Re-authenticates via the OTP dev path ("000000").
    /// On success, resets the provided stores and authManager's identity.
    func switchTo(
        user: APITestUser,
        authManager: AuthManager,
        groupStore: GroupStore,
        inviteStore: InviteStore
    ) async {
        isSwitching = true
        lastError = nil
        defer { isSwitching = false }

        do {
            // Sign out first so the new token replaces cleanly.
            await authManager.signOut()

            try await authManager.sendOtp(phoneNumber: user.phoneNumber)
            let result = try await authManager.verifyOtp(phoneNumber: user.phoneNumber, code: "000000")

            switch result {
            case .existingUser:
                groupStore.groupsState = .idle
                groupStore.detailState = .idle
                inviteStore.reset()
            case .newUser:
                lastError = "Test user has no account (this shouldn't happen for seeded users)"
            }
        } catch let error as APIError {
            lastError = error.errorDescription ?? "Switch failed"
        } catch {
            lastError = "Switch failed"
        }
    }
}

#endif
