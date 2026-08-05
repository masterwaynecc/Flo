import Foundation

enum SupabaseConfig {
    /// Injected at build time via Info.plist or xcconfig; overridable in Settings for debugging.
    static var urlString: String {
        if let override = UserDefaults.standard.string(forKey: "dawt.supabase.url"), !override.isEmpty {
            return override
        }
        return Bundle.main.object(forInfoDictionaryKey: "DAWTSupabaseURL") as? String ?? ""
    }

    static var anonKey: String {
        if let override = UserDefaults.standard.string(forKey: "dawt.supabase.anon"), !override.isEmpty {
            return override
        }
        return Bundle.main.object(forInfoDictionaryKey: "DAWTSupabaseAnonKey") as? String ?? ""
    }

    static var isConfigured: Bool {
        !urlString.isEmpty && !anonKey.isEmpty && URL(string: urlString) != nil
    }

    static func persist(url: String, anonKey: String) {
        UserDefaults.standard.set(url, forKey: "dawt.supabase.url")
        UserDefaults.standard.set(anonKey, forKey: "dawt.supabase.anon")
    }
}
