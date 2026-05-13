import SwiftUI

@main
struct CacheApp: App {
    @StateObject private var auth = AuthService()
    @StateObject private var data = DataStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(data)
                .task {
                    await auth.restoreSession()
                    await NotificationService.shared.requestPermission()
                }
        }
    }
}
