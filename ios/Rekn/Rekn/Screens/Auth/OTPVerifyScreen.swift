import SwiftUI

struct OTPVerifyScreen: View {
    let phoneNumber: String
    @State private var code = ""
    @State private var resendTimer = 60
    @State private var showingSetup = false

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
                .multilineTextAlignment(.center)
                .font(.system(size: 32, weight: .semibold, design: .monospaced))
                .tracking(12)
                .padding()
                .background(Color(.systemGray6), in: .rect(cornerRadius: 12))
                .onChange(of: code) { _, newValue in
                    code = String(newValue.filter(\.isNumber).prefix(6))
                }

            Button {
                showingSetup = true
            } label: {
                Text("Verify")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(code.count != 6)

            if resendTimer > 0 {
                Text("Resend code in \(resendTimer)s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("Resend code") {
                    resendTimer = 60
                }
                .font(.caption)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .navigationDestination(isPresented: $showingSetup) {
            NameSetupScreen()
        }
        .task {
            while resendTimer > 0 {
                try? await Task.sleep(for: .seconds(1))
                resendTimer -= 1
            }
        }
    }
}

#Preview {
    NavigationStack {
        OTPVerifyScreen(phoneNumber: "+12125551234")
    }
}
