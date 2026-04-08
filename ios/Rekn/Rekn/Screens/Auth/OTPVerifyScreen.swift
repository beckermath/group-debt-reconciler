import SwiftUI

struct OTPVerifyScreen: View {
    let phoneNumber: String
    @Environment(AuthManager.self) private var authManager
    @State private var code = ""
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var resendTimer = 60
    @State private var showingSetup = false
    @State private var verifiedPhone = ""
    @FocusState private var codeFocused: Bool

    private var maskedPhone: String {
        guard phoneNumber.count > 4 else { return phoneNumber }
        let visible = phoneNumber.suffix(4)
        let masked = String(repeating: "•", count: phoneNumber.count - 4)
        return masked + visible
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("Enter verification code")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Sent to \(maskedPhone)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Code input
            TextField("000000", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($codeFocused)
                .multilineTextAlignment(.center)
                .font(.system(size: 32, weight: .semibold, design: .monospaced))
                .tracking(12)
                .padding()
                .background(Color(.systemGray6), in: .rect(cornerRadius: 12))
                .onChange(of: code) { _, newValue in
                    code = String(newValue.filter(\.isNumber).prefix(6))
                    if code.count == 6 {
                        codeFocused = false
                        Task { await verify() }
                    }
                }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.balanceNegative)
            }

            Button {
                Task { await verify() }
            } label: {
                if isSubmitting {
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
            .disabled(code.count != 6 || isSubmitting)

            if resendTimer > 0 {
                Text("Resend code in \(resendTimer)s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("Resend code") {
                    Task { await resend() }
                }
                .font(.caption)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
        .navigationDestination(isPresented: $showingSetup) {
            NameSetupScreen(phoneNumber: verifiedPhone)
        }
        .onAppear { codeFocused = true }
        .task {
            while resendTimer > 0 {
                try? await Task.sleep(for: .seconds(1))
                resendTimer -= 1
            }
        }
    }

    private func verify() async {
        error = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let result = try await authManager.verifyOtp(phoneNumber: phoneNumber, code: code)
            switch result {
            case .existingUser:
                // AuthManager already set isAuthenticated = true
                break
            case .newUser(let phone):
                verifiedPhone = phone
                showingSetup = true
            }
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = "Something went wrong"
        }
    }

    private func resend() async {
        error = nil
        do {
            try await authManager.sendOtp(phoneNumber: phoneNumber)
            resendTimer = 60
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = "Failed to resend"
        }
    }
}

#Preview {
    NavigationStack {
        OTPVerifyScreen(phoneNumber: "+12125551234")
            .environment(AuthManager())
    }
}
