import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var data: DataStore
    @State private var showAddAccount = false
    @State private var showChangePassword = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Konto") {
                    LabeledContent("Email", value: auth.email ?? "—")
                }

                Section("Konta finansowe") {
                    ForEach(data.accounts) { acc in
                        HStack {
                            Image(systemName: acc.icon)
                            VStack(alignment: .leading) {
                                Text(acc.name)
                                Text(acc.type.label).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(acc.balance, format: .currency(code: acc.currency))
                        }
                    }
                    .onDelete { idx in
                        let toDel = idx.map { data.accounts[$0] }
                        Task { for a in toDel { await data.deleteAccount(a) } }
                    }
                    Button {
                        showAddAccount = true
                    } label: {
                        Label("Dodaj konto", systemImage: "plus.circle")
                    }
                }

                Section("Kategorie") {
                    NavigationLink {
                        CategoriesListView()
                    } label: {
                        LabeledContent("Liczba kategorii", value: "\(data.categories.count)")
                    }
                }

                Section("Rachunki") {
                    NavigationLink("Zarządzaj rachunkami") { BillsView() }
                }

                Section("Bezpieczeństwo") {
                    Button {
                        showChangePassword = true
                    } label: {
                        Label("Zmień hasło", systemImage: "lock.rotation")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Usuń konto", systemImage: "trash")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task { await auth.signOut() }
                    } label: { Text("Wyloguj się") }
                }

                Section {
                    LabeledContent("Wersja", value: "0.4.0")
                }
            }
            .navigationTitle("Ustawienia")
            .sheet(isPresented: $showAddAccount) { AddAccountSheet() }
            .sheet(isPresented: $showChangePassword) { ChangePasswordSheet() }
            .alert("Usunąć konto?", isPresented: $showDeleteConfirm) {
                Button("Anuluj", role: .cancel) {}
                Button("Usuń", role: .destructive) {
                    Task { _ = await auth.deleteAccount() }
                }
            } message: {
                Text("Konto i wszystkie powiązane dane (transakcje, subskrypcje, budżety, cele, rachunki) zostaną trwale usunięte. Tej operacji nie można cofnąć.")
            }
        }
    }
}

struct ChangePasswordSheet: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var success = false

    var passwordsMatch: Bool { !newPassword.isEmpty && newPassword == confirmPassword }
    var valid: Bool { passwordsMatch && newPassword.count >= 6 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Nowe hasło (min. 6 znaków)", text: $newPassword)
                    SecureField("Powtórz hasło", text: $confirmPassword)
                } footer: {
                    if !confirmPassword.isEmpty && !passwordsMatch {
                        Text("Hasła nie są identyczne").foregroundStyle(.red)
                    }
                }
                if let msg = auth.errorMessage {
                    Section { Text(msg).foregroundStyle(.red) }
                }
                if success {
                    Section { Label("Hasło zmienione", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                }
            }
            .navigationTitle("Zmiana hasła")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        Task {
                            let ok = await auth.updatePassword(newPassword: newPassword)
                            if ok {
                                success = true
                                try? await Task.sleep(nanoseconds: 800_000_000)
                                dismiss()
                            }
                        }
                    }
                    .disabled(!valid || auth.isLoading)
                }
            }
        }
    }
}

struct CategoriesListView: View {
    @EnvironmentObject var data: DataStore
    var body: some View {
        List {
            Section("Wydatki") {
                ForEach(data.categories.filter { $0.type == .expense }) { c in
                    HStack {
                        Image(systemName: c.icon).foregroundStyle(Color(hex: c.color))
                        Text(c.name)
                    }
                }
            }
            Section("Przychody") {
                ForEach(data.categories.filter { $0.type == .income }) { c in
                    HStack {
                        Image(systemName: c.icon).foregroundStyle(Color(hex: c.color))
                        Text(c.name)
                    }
                }
            }
        }
        .navigationTitle("Kategorie")
    }
}

struct AddAccountSheet: View {
    @EnvironmentObject var data: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: AccountType = .checking
    @State private var balance: Double?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nazwa", text: $name)
                Picker("Typ", selection: $type) {
                    ForEach(AccountType.allCases) { Text($0.label).tag($0) }
                }
                TextField("Saldo początkowe", value: $balance, format: .number)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Nowe konto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        Task { await data.addAccount(name: name, type: type, balance: balance ?? 0); dismiss() }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
