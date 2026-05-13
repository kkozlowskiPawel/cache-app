import SwiftUI

struct SignupView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var needsConfirmation = false

    var body: some View {
        NavigationStack {
            if needsConfirmation {
                confirmInbox
            } else {
                form
            }
        }
    }

    private var confirmInbox: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge.fill")
                .resizable().scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(.tint)
                .padding(.top, 60)
            Text("Sprawdź skrzynkę").font(.title2.bold())
            Text("Wysłaliśmy link aktywacyjny na \(email). Kliknij go, aby potwierdzić adres i zalogować się do Cache.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
            Button("Zamknij") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
        }
        .navigationTitle("Rejestracja")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var form: some View {
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
                        let result = await auth.signUp(email: email, password: password)
                        switch result {
                        case .signedIn:        dismiss()
                        case .needsConfirmation: needsConfirmation = true
                        case .failure:         break
                        }
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
