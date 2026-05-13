import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // best-effort
        }
    }

    func scheduleBillReminder(name: String, amount: Double, dueDate: Date, daysBefore: Int) async {
        let center = UNUserNotificationCenter.current()

        let triggerDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: dueDate) ?? dueDate
        guard triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Nadchodzący rachunek"
        content.body = String(format: "%@ — %.2f PLN, termin: %@", name, amount, DateFormatter.localizedString(from: dueDate, dateStyle: .medium, timeStyle: .none))
        content.sound = .default

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: triggerDate)
        comps.hour = 9

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        try? await center.add(request)
    }
}
