import SwiftUI

struct NameSetupScreen: View {
    let phoneNumber: String
    @Environment(AuthManager.self) private var authManager
    @State private var name = ""
    @State private var isSubmitting = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 32) {
            StepProgressBar(totalSteps: 3, currentStep: 2)

            Spacer()

            VStack(spacing: 8) {
                Text("Welcome to Rekn")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("What should we call you?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ReknTextField(
                label: "Your name",
                placeholder: "Alex",
                text: $name,
                textContentType: .name,
                submitLabel: .done,
                onSubmit: {
                    guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    Task { await completeSetup() }
                }
            )
            .autocorrectionDisabled()

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.balanceNegative)
            }

            Button {
                Task { await completeSetup() }
            } label: {
                if isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Get started")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)

            Spacer()
        }
        .padding(.horizontal, 32)
        .onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
        .navigationBarBackButtonHidden()
    }

    private func completeSetup() async {
        error = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await authManager.completeSetup(name: name.trimmingCharacters(in: .whitespaces), phoneNumber: phoneNumber)
            // AuthManager sets isAuthenticated = true, which swaps the root view
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = "Something went wrong"
        }
    }
}

#Preview {
    NavigationStack {
        NameSetupScreen(phoneNumber: "+12125551234")
            .environment(AuthManager())
    }
}
