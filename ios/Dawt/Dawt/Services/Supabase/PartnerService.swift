import Foundation

@MainActor
final class PartnerService: ObservableObject {
    @Published private(set) var ownedLinks: [PartnerLinkDTO] = []
    @Published private(set) var sharedWithMe: [PartnerLinkDTO] = []
    @Published private(set) var snapshots: [CycleShareSnapshotDTO] = []
    @Published private(set) var latestInviteCode: String?
    @Published var statusMessage: String = ""
    @Published var isBusy = false

    func refresh(session: SupabaseSession?) async {
        guard let session else {
            ownedLinks = []
            sharedWithMe = []
            snapshots = []
            return
        }
        do {
            let links = try await SupabaseClient.shared.listPartnerLinks(session: session)
            let me = session.userId.lowercased()
            ownedLinks = links.filter {
                $0.ownerUserId.uuidString.lowercased() == me && $0.status == "active"
            }
            sharedWithMe = links.filter {
                $0.partnerUserId.uuidString.lowercased() == me && $0.status == "active"
            }
            snapshots = try await SupabaseClient.shared.fetchSharedSnapshots(session: session)
            statusMessage = ""
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func createInvite(session: SupabaseSession?) async {
        guard let session else {
            statusMessage = "Sign in to invite a partner."
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            latestInviteCode = try await SupabaseClient.shared.createPartnerInvite(session: session)
            statusMessage = "Invite code ready — share it with your partner."
            await refresh(session: session)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func acceptInvite(session: SupabaseSession?, code: String) async {
        guard let session else {
            statusMessage = "Sign in to accept an invite."
            return
        }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = "Enter an invite code."
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            try await SupabaseClient.shared.acceptPartnerInvite(session: session, code: trimmed)
            statusMessage = "Partner link connected."
            latestInviteCode = nil
            await refresh(session: session)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func revoke(session: SupabaseSession?, link: PartnerLinkDTO) async {
        guard let session else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await SupabaseClient.shared.revokePartnerLink(session: session, linkId: link.id)
            statusMessage = "Sharing revoked."
            await refresh(session: session)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func snapshot(forOwner ownerId: UUID) -> CycleShareSnapshotDTO? {
        snapshots.first { $0.userId == ownerId }
    }
}
