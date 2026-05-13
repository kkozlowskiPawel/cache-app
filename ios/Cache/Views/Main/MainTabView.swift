import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Dashboard", systemImage: "house.fill") }

            TransactionsView()
                .tabItem { Label("Wydatki", systemImage: "list.bullet.rectangle") }

            SubscriptionsView()
                .tabItem { Label("Subskrypcje", systemImage: "repeat") }

            BudgetView()
                .tabItem { Label("Budżet", systemImage: "chart.pie.fill") }

            SettingsView()
                .tabItem { Label("Ustawienia", systemImage: "gear") }
        }
    }
}
