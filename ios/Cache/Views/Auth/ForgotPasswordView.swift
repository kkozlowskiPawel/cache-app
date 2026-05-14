import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    let prefilledEmail: String

    @State private var email: String = ""
    @State private var sent = false

    init(prefilledEmail: String = "") {
        self.prefilledEmail = prefilledEmail
    }

    var body: some View {
        NavigationStack {
            if sent {
                confirmation
            } else {
                form
            }
        }
        .onAppear { if email.isEmpty { email = prefilledEmail } }
    }

    private var form: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("Wyślemy link do zresetowania hasła. Otworzysz go w przeglądarce, ustawisz nowe hasło, a potem zalogujesz się tu w aplikacji.")
            }

            if let msg = auth.errorMessage {
                Section { Text(msg).foregroundStyle(.red) }
            }

            Section {
                Button {
                    Task {
                        if await auth.sendPasswordReset(email: email) {
                            sent = true
                        }
                    }
                } label: {
                    if auth.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Wyślij link").frame(maxWidth: .infinity)
                    }
                }
                .disabled(auth.isLoading || email.isEmpty)
            }
        }
        .navigationTitle("Reset hasła")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Anuluj") { dismiss() }
            }
        }
    }

    private var confirmation: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge.fill")
                .resizable().scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(.tint)
                .padding(.top, 60)
            Text("Sprawdź skrzynkę").font(.title2.bold())
            Text("Jeśli istnieje konto powiązane z \(email), wysłaliśmy link do zresetowania hasła.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
            Button("Zamknij") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
        }
        .navigationTitle("Reset hasła")
        .navigationBarTitleDisplayMode(.inline)
    }
}
