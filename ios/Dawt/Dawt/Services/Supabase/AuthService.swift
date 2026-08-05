import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published private(set) var session: SupabaseSession?
    @Published private(set) var isBusy = false
    @Published var lastError: String?

    private var currentNonce: String?
    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    private let sessionKey = "dawt.supabase.session"

    override init() {
        super.init()
        session = Self.loadSession(key: sessionKey)
    }

    var isSignedIn: Bool { session != nil }

    var userId: String? { session?.userId }

    func restoreSession() async {
        guard var current = session else { return }
        do {
            current = try await SupabaseClient.shared.refreshSession(current)
            session = current
            Self.saveSession(current, key: sessionKey)
            lastError = nil
        } catch {
            // Keep offline session if refresh fails (slow/offline networks).
            lastError = nil
        }
    }

    func signInWithApple() async {
        guard SupabaseConfig.isConfigured else {
            lastError = "Cloud backend is not configured."
            return
        }
        isBusy = true
        lastError = nil
        defer { isBusy = false }

        do {
            let nonce = Self.randomNonce()
            currentNonce = nonce
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256(nonce)

            let authorization = try await performAppleRequest(request)
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                throw SupabaseError.message("Apple did not return an identity token.")
            }

            let newSession = try await SupabaseClient.shared.signInWithApple(
                idToken: idToken,
                nonce: currentNonce
            )
            session = newSession
            Self.saveSession(newSession, key: sessionKey)

            if let given = credential.fullName?.givenName, !given.isEmpty {
                // Display name is applied by AppState after sign-in.
                UserDefaults.standard.set(given, forKey: "dawt.pending.displayName")
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func signOut() async {
        if let token = session?.accessToken {
            await SupabaseClient.shared.signOut(accessToken: token)
        }
        session = nil
        Self.clearSession(key: sessionKey)
    }

    // MARK: - Apple coordinator

    private func performAppleRequest(_ request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess { continue }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private static func saveSession(_ session: SupabaseSession, key: String) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        KeychainStore.set(data, account: key)
    }

    private static func loadSession(key: String) -> SupabaseSession? {
        guard let data = KeychainStore.get(account: key) else { return nil }
        return try? JSONDecoder().decode(SupabaseSession.self, from: data)
    }

    private static func clearSession(key: String) {
        KeychainStore.delete(account: key)
    }
}

extension AuthService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            continuation?.resume(returning: authorization)
            continuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let resolve = {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow }
                ?? UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows)
                    .first
                ?? ASPresentationAnchor()
        }
        if Thread.isMainThread {
            return resolve()
        }
        return DispatchQueue.main.sync(execute: resolve)
    }
}

enum KeychainStore {
    static func set(_ data: Data, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: "app.dawt.cycle",
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: "app.dawt.cycle",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: "app.dawt.cycle",
        ]
        SecItemDelete(query as CFDictionary)
    }
}
