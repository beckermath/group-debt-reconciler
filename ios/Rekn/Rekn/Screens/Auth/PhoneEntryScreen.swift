import SwiftUI

struct PhoneEntryScreen: View {
    @Environment(AuthManager.self) private var authManager
    @State private var phone = ""
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var showingVerify = false
    @FocusState private var phoneFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 8) {
                    Text("Rekn")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.accentColor)
                    Text("Reconcile group debts simply")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Phone input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone number")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    HStack(spacing: 0) {
                        Text("+1")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray5))
                            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 8))
                        TextField("(212) 555-1234", text: $phone)
                            .keyboardType(.phonePad)
                            .focused($phoneFocused)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 8, topTrailingRadius: 8))
                            .onChange(of: phone) { _, newValue in
                                phone = String(newValue.filter(\.isNumber).prefix(10))
                            }
                    }
                    Text("We'll send you a 6-digit verification code.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.balanceNegative)
                }

                Button {
                    Task { await sendCode() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Send code")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(phone.count < 10 || isSubmitting)

                // Divider
                HStack {
                    Rectangle().fill(Color(.separator)).frame(height: 0.5)
                    Text("or").font(.caption).foregroundStyle(.secondary)
                    Rectangle().fill(Color(.separator)).frame(height: 0.5)
                }

                Button {
                    Task { await startGuest() }
                } label: {
                    Text("Try as guest")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 32)
            .onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            .navigationDestination(isPresented: $showingVerify) {
                OTPVerifyScreen(phoneNumber: "+1\(phone)")
            }
            .onAppear { phoneFocused = true }
        }
    }

    private func sendCode() async {
        error = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await authManager.sendOtp(phoneNumber: "+1\(phone)")
            showingVerify = true
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = "Something went wrong"
        }
    }

    private func startGuest() async {
        error = nil
        do {
            try await authManager.startGuestSession()
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = "Something went wrong"
        }
    }
}

#Preview {
    PhoneEntryScreen()
        .environment(AuthManager())
}
