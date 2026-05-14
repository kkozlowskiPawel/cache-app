import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showSignup = false
    @State private var showForgot = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "creditcard.circle.fill")
                        .resizable()
                        .frame(width: 72, height: 72)
                        .foregroundStyle(.tint)
                    Text("Cache")
                        .font(.largeTitle.bold())
                    Text("Twoje finanse pod kontrolą")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    SecureField("Hasło", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                if let msg = auth.errorMessage {
                    Text(msg).font(.footnote).foregroundStyle(.red)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }

                Button {
                    Task { await auth.signIn(email: email, password: password) }
                } label: {
                    if auth.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Zaloguj się").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .disabled(auth.isLoading || email.isEmpty || password.isEmpty)

                Button("Zapomniałeś hasła?") { showForgot = true }
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Nie masz konta? Zarejestruj się") { showSignup = true }
                    .font(.footnote)

                Spacer()
            }
            .sheet(isPresented: $showSignup) {
                SignupView()
            }
            .sheet(isPresented: $showForgot) {
                ForgotPasswordView(prefilledEmail: email)
            }
        }
    }
}
