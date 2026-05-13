import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var data: DataStore

    var body: some View {
        Group {
            if auth.isAuthenticated {
                MainTabView()
                    .task(id: auth.userId) {
                        await data.loadAll()
                        await data.subscribeRealtime()
                    }
            } else {
                LoginView()
                    .task {
                        await data.unsubscribeRealtime()
                        data.clearLocal()
                    }
            }
        }
        .animation(.default, value: auth.isAuthenticated)
    }
}
