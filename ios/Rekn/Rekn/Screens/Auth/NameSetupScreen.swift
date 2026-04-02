import SwiftUI

struct NameSetupScreen: View {
    @State private var name = ""

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("Welcome to Rekn")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("What should we call you?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Your name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("Alex", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
                    .autocorrectionDisabled()
            }

            Button {
                // Complete setup
            } label: {
                Text("Get started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer()
        }
        .padding(.horizontal, 32)
        .navigationBarBackButtonHidden()
    }
}

#Preview {
    NavigationStack {
        NameSetupScreen()
    }
}
