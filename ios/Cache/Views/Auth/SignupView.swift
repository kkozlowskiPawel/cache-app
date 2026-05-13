import SwiftUI

struct SignupView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Konto") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Hasło (min. 6 znaków)", text: $password)
                }

                if let msg = auth.errorMessage {
                    Section { Text(msg).foregroundStyle(.red) }
                }

                Section {
                    Button {
                        Task {
                            await auth.signUp(email: email, password: password)
                            if auth.isAuthenticated { dismiss() }
                        }
                    } label: {
                        if auth.isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Utwórz konto").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(auth.isLoading || email.isEmpty || password.count < 6)
                }
            }
            .navigationTitle("Rejestracja")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
            }
        }
    }
}
