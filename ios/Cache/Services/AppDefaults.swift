import Foundation

enum AppDefaults {
    private static let lastAccountKey = "cache.lastAccountId"

    static var lastAccountId: UUID? {
        get {
            guard let s = UserDefaults.standard.string(forKey: lastAccountKey) else { return nil }
            return UUID(uuidString: s)
        }
        set {
            if let v = newValue { UserDefaults.standard.set(v.uuidString, forKey: lastAccountKey) }
            else { UserDefaults.standard.removeObject(forKey: lastAccountKey) }
        }
    }
}
