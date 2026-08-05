import Foundation

enum SupabaseError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case http(Int, String)
    case decoding
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Supabase is not configured."
        case .notAuthenticated: return "Sign in to sync and share with a partner."
        case .http(let code, let body): return "Server error (\(code)): \(body)"
        case .decoding: return "Could not read server response."
        case .message(let text): return text
        }
    }
}

struct SupabaseSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userId: String
    var email: String?

    var isExpired: Bool {
        Date().addingTimeInterval(60) >= expiresAt
    }
}

/// Thin URLSession client for Auth + PostgREST. Offline-friendly: callers keep local state on failure.
actor SupabaseClient {
    static let shared = SupabaseClient()

    private let session = URLSession(configuration: .ephemeral)
    private let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var baseURL: URL {
        get throws {
            guard SupabaseConfig.isConfigured, let url = URL(string: SupabaseConfig.urlString) else {
                throw SupabaseError.notConfigured
            }
            return url
        }
    }

    private var anonKey: String {
        get throws {
            let key = SupabaseConfig.anonKey
            guard !key.isEmpty else { throw SupabaseError.notConfigured }
            return key
        }
    }

    func dayString(_ date: Date) -> String {
        Self.formatDay(date)
    }

    private static func formatDay(_ date: Date) -> String {
        // Format in the user's calendar day, not UTC, so timezones don't shift dates.
        let local = DateFormatter()
        local.calendar = Calendar.current
        local.locale = Locale(identifier: "en_US_POSIX")
        local.timeZone = Calendar.current.timeZone
        local.dateFormat = "yyyy-MM-dd"
        return local.string(from: Calendar.current.startOfDay(for: date))
    }

    private static func parseDay(_ string: String) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var comps = DateComponents()
        comps.year = parts[0]
        comps.month = parts[1]
        comps.day = parts[2]
        return Calendar.current.date(from: comps).map { Calendar.current.startOfDay(for: $0) }
    }

    // MARK: - Auth

    func signInWithApple(idToken: String, nonce: String?) async throws -> SupabaseSession {
        var body: [String: Any] = [
            "provider": "apple",
            "id_token": idToken
        ]
        if let nonce, !nonce.isEmpty {
            body["nonce"] = nonce
        }
        let data = try await postJSON(
            path: "/auth/v1/token?grant_type=id_token",
            body: body,
            accessToken: nil
        )
        return try decodeSession(from: data)
    }

    func refreshSession(_ session: SupabaseSession) async throws -> SupabaseSession {
        if !session.isExpired { return session }
        let data = try await postJSON(
            path: "/auth/v1/token?grant_type=refresh_token",
            body: ["refresh_token": session.refreshToken],
            accessToken: nil
        )
        return try decodeSession(from: data)
    }

    func signOut(accessToken: String) async {
        _ = try? await request(
            method: "POST",
            path: "/auth/v1/logout",
            body: Data(),
            accessToken: accessToken,
            extraHeaders: ["Content-Type": "application/json"]
        )
    }

    // MARK: - Sync

    func upsertProfile(
        session: SupabaseSession,
        profile: UserProfile
    ) async throws {
        let valid = try await refreshSession(session)
        var row: [String: Any] = [
            "user_id": valid.userId,
            "display_handle": profile.displayName.isEmpty ? NSNull() : profile.displayName,
            "teen_mode": profile.teenMode,
            "life_stage_mode": profile.goal.rawValue,
            "ai_context_consent": profile.aiContextConsent,
            "typical_cycle_length": profile.typicalCycleLength,
            "typical_period_length": profile.typicalPeriodLength,
            "updated_at": iso.string(from: Date())
        ]
        if let last = profile.lastPeriodStart {
            row["last_period_start"] = dayString(last)
        }
        _ = try await restUpsert(
            table: "profiles",
            rows: [row],
            onConflict: "user_id",
            accessToken: valid.accessToken
        )
    }

    func upsertDayLogs(session: SupabaseSession, logs: [DayLog]) async throws {
        guard !logs.isEmpty else { return }
        let valid = try await refreshSession(session)
        // Omit primary key `id` — conflict target is (user_id, log_date).
        // Sending a local UUID here 409s when that date already exists with a different id.
        let rows: [[String: Any]] = logs.map { log in
            let payload: [String: Any] = [
                "symptomIDs": log.symptomIDs,
                "moodIDs": log.moodIDs,
                "notes": log.notes
            ]
            return [
                "user_id": valid.userId,
                "log_date": dayString(log.date),
                "flow": log.flow.rawValue,
                "payload": payload,
                "client_id": log.clientId.uuidString.lowercased(),
                "updated_at": iso.string(from: log.updatedAt)
            ]
        }
        _ = try await restUpsert(
            table: "day_logs",
            rows: rows,
            onConflict: "user_id,log_date",
            accessToken: valid.accessToken
        )
    }

    func fetchDayLogs(session: SupabaseSession) async throws -> [DayLog] {
        let valid = try await refreshSession(session)
        let data = try await request(
            method: "GET",
            path: "/rest/v1/day_logs?select=*&order=log_date.asc",
            body: nil,
            accessToken: valid.accessToken,
            extraHeaders: ["Accept": "application/json"]
        )
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw SupabaseError.decoding
        }
        return rows.compactMap { row in
            guard
                let idString = row["id"] as? String,
                let id = UUID(uuidString: idString),
                let dateString = row["log_date"] as? String,
                let date = Self.parseDay(dateString),
                let flowRaw = row["flow"] as? String,
                let flow = FlowLevel(rawValue: flowRaw),
                let clientString = row["client_id"] as? String,
                let clientId = UUID(uuidString: clientString)
            else { return nil }

            let payload = row["payload"] as? [String: Any] ?? [:]
            let symptoms = payload["symptomIDs"] as? [String] ?? []
            let moods = payload["moodIDs"] as? [String] ?? []
            let notes = payload["notes"] as? String ?? ""
            let updated: Date = {
                if let s = row["updated_at"] as? String {
                    return isoFractional.date(from: s) ?? iso.date(from: s) ?? Date()
                }
                return Date()
            }()
            return DayLog(
                id: id,
                date: date,
                flow: flow,
                symptomIDs: symptoms,
                moodIDs: moods,
                notes: notes,
                updatedAt: updated,
                clientId: clientId
            )
        }
    }

    func upsertShareSnapshot(
        session: SupabaseSession,
        prediction: CyclePrediction,
        profile: UserProfile,
        logs: [DayLog]
    ) async throws {
        let valid = try await refreshSession(session)
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -120, to: Date()) ?? Date.distantPast
        let loggedPeriodDates = logs
            .filter { $0.flow.isPeriod && $0.date >= cutoff }
            .map { dayString($0.date) }
            .sorted()

        var row: [String: Any] = [
            "user_id": valid.userId,
            "cycle_day": prediction.cycleDay,
            "phase": prediction.phase.rawValue,
            "period_length": prediction.periodLength,
            "display_handle": profile.displayName.isEmpty ? NSNull() : profile.displayName,
            "logged_period_dates": loggedPeriodDates,
            "updated_at": iso.string(from: Date())
        ]
        if let periodStart = profile.lastPeriodStart {
            row["period_start"] = dayString(periodStart)
            if let end = cal.date(byAdding: .day, value: max(prediction.periodLength - 1, 0), to: periodStart) {
                row["period_end"] = dayString(end)
            }
        }
        if let fertile = prediction.fertileWindow {
            row["fertile_window_start"] = dayString(fertile.lowerBound)
            row["fertile_window_end"] = dayString(fertile.upperBound)
        }
        if let ovulation = prediction.ovulationDay {
            row["ovulation_day"] = dayString(ovulation)
        }
        if let next = prediction.nextPeriodStart {
            row["next_period_start"] = dayString(next)
        }
        _ = try await restUpsert(
            table: "cycle_share_snapshots",
            rows: [row],
            onConflict: "user_id",
            accessToken: valid.accessToken
        )
    }

    // MARK: - Partners

    func createPartnerInvite(session: SupabaseSession) async throws -> String {
        let valid = try await refreshSession(session)
        let data = try await postJSON(
            path: "/rest/v1/rpc/create_partner_invite",
            body: [:],
            accessToken: valid.accessToken
        )
        if let code = try? JSONDecoder().decode(String.self, from: data) {
            return code
        }
        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) {
            return text
        }
        throw SupabaseError.decoding
    }

    func acceptPartnerInvite(session: SupabaseSession, code: String) async throws {
        let valid = try await refreshSession(session)
        _ = try await postJSON(
            path: "/rest/v1/rpc/accept_partner_invite",
            body: ["invite_code": code],
            accessToken: valid.accessToken
        )
    }

    func listPartnerLinks(session: SupabaseSession) async throws -> [PartnerLinkDTO] {
        let valid = try await refreshSession(session)
        let data = try await request(
            method: "GET",
            path: "/rest/v1/partner_links?select=*&order=created_at.desc",
            body: nil,
            accessToken: valid.accessToken,
            extraHeaders: ["Accept": "application/json"]
        )
        return try JSONDecoder.supabase.decode([PartnerLinkDTO].self, from: data)
    }

    func revokePartnerLink(session: SupabaseSession, linkId: UUID) async throws {
        let valid = try await refreshSession(session)
        let path = "/rest/v1/partner_links?id=eq.\(linkId.uuidString.lowercased())"
        _ = try await request(
            method: "PATCH",
            path: path,
            body: try JSONSerialization.data(withJSONObject: ["status": "revoked"]),
            accessToken: valid.accessToken,
            extraHeaders: [
                "Content-Type": "application/json",
                "Prefer": "return=minimal"
            ]
        )
    }

    func fetchSharedSnapshots(session: SupabaseSession) async throws -> [CycleShareSnapshotDTO] {
        let valid = try await refreshSession(session)
        let data = try await request(
            method: "GET",
            path: "/rest/v1/cycle_share_snapshots?select=*",
            body: nil,
            accessToken: valid.accessToken,
            extraHeaders: ["Accept": "application/json"]
        )
        return try JSONDecoder.supabase.decode([CycleShareSnapshotDTO].self, from: data)
    }

    // MARK: - Internals

    private func decodeSession(from data: Data) throws -> SupabaseSession {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let access = json["access_token"] as? String,
            let refresh = json["refresh_token"] as? String,
            let user = json["user"] as? [String: Any],
            let userId = user["id"] as? String
        else { throw SupabaseError.decoding }

        let expiresIn = json["expires_in"] as? Int ?? 3600
        let email = user["email"] as? String
        return SupabaseSession(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn)),
            userId: userId,
            email: email
        )
    }

    private func restUpsert(
        table: String,
        rows: [[String: Any]],
        onConflict: String,
        accessToken: String
    ) async throws -> Data {
        let body = try JSONSerialization.data(withJSONObject: rows)
        return try await request(
            method: "POST",
            path: "/rest/v1/\(table)?on_conflict=\(onConflict)",
            body: body,
            accessToken: accessToken,
            extraHeaders: [
                "Content-Type": "application/json",
                "Prefer": "resolution=merge-duplicates,return=minimal"
            ]
        )
    }

    private func postJSON(path: String, body: [String: Any], accessToken: String?) async throws -> Data {
        let data = try JSONSerialization.data(withJSONObject: body)
        return try await request(
            method: "POST",
            path: path,
            body: data,
            accessToken: accessToken,
            extraHeaders: ["Content-Type": "application/json"]
        )
    }

    @discardableResult
    private func request(
        method: String,
        path: String,
        body: Data?,
        accessToken: String?,
        extraHeaders: [String: String]
    ) async throws -> Data {
        let root = try baseURL
        let key = try anonKey
        guard let url = URL(string: path, relativeTo: root)?.absoluteURL else {
            throw SupabaseError.message("Bad URL path")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken ?? key)", forHTTPHeaderField: "Authorization")
        for (k, v) in extraHeaders {
            req.setValue(v, forHTTPHeaderField: k)
        }

        let (data, response) = try await session.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            if text.contains("provider_disabled") {
                throw SupabaseError.message(
                    "Apple Sign In isn’t enabled in Supabase yet. Enable the Apple provider and add Client ID app.dawt.cycle."
                )
            }
            throw SupabaseError.http(code, text)
        }
        return data
    }
}

struct PartnerLinkDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let ownerUserId: UUID
    let partnerUserId: UUID
    let status: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserId = "owner_user_id"
        case partnerUserId = "partner_user_id"
        case status
        case createdAt = "created_at"
    }
}

struct CycleShareSnapshotDTO: Codable, Identifiable, Equatable {
    var id: UUID { userId }
    let userId: UUID
    let periodStart: String?
    let periodEnd: String?
    let fertileWindowStart: String?
    let fertileWindowEnd: String?
    let ovulationDay: String?
    let nextPeriodStart: String?
    let cycleDay: Int?
    let phase: String?
    let periodLength: Int?
    let displayHandle: String?
    let loggedPeriodDates: [String]?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case fertileWindowStart = "fertile_window_start"
        case fertileWindowEnd = "fertile_window_end"
        case ovulationDay = "ovulation_day"
        case nextPeriodStart = "next_period_start"
        case cycleDay = "cycle_day"
        case phase
        case periodLength = "period_length"
        case displayHandle = "display_handle"
        case loggedPeriodDates = "logged_period_dates"
        case updatedAt = "updated_at"
    }

    var ownerLabel: String {
        if let handle = displayHandle, !handle.isEmpty { return handle }
        return "Their"
    }
}

extension JSONDecoder {
    static let supabase: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: string) { return date }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date \(string)")
        }
        return decoder
    }()
}
