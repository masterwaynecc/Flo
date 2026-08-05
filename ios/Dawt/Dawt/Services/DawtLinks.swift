import Foundation

enum DawtLinks {
    /// Public TestFlight join URL from App Store Connect → TestFlight → group → Enable Public Link.
    /// Injected via `DAWT_TESTFLIGHT_URL` in Config/Secrets xcconfig.
    static var testFlightJoinURL: URL? {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "DAWTTestFlightURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty, let url = URL(string: raw), url.scheme == "https" else { return nil }
        return url
    }

    static func partnerInviteMessage(code: String) -> String {
        var lines = [
            "Join me on Dawt!",
            "Invite code: \(code)",
        ]
        if let url = testFlightJoinURL {
            lines.append("Install via TestFlight: \(url.absoluteString)")
            lines.append("Then open Dawt → Profile → Partners and enter the invite code.")
        } else {
            lines.append("Install Dawt from TestFlight, then enter the invite code in Profile → Partners.")
        }
        return lines.joined(separator: "\n")
    }
}
