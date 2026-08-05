import SwiftUI

struct AccountSectionView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Section("Account") {
            if appState.authService.isSignedIn {
                LabeledContent("Signed in") {
                    Text(shortUserLabel)
                        .foregroundStyle(DawtColor.inkMuted)
                        .lineLimit(1)
                }
                Button("Sync now") {
                    Task { await appState.syncFromCloud() }
                }
                .disabled(appState.syncService.isSyncing)
                Text(appState.syncService.statusMessage)
                    .font(DawtType.body(12))
                    .foregroundStyle(DawtColor.inkMuted)
                Text("Pending: \(appState.syncService.pendingCount)")
                    .font(DawtType.body(12))
                    .foregroundStyle(DawtColor.inkMuted)
                Button("Sign out", role: .destructive) {
                    Task { await appState.signOut() }
                }
            } else {
                Text("Sign in to sync across devices and share cycle predictions with a partner. Symptom diary stays private.")
                    .font(DawtType.body(12))
                    .foregroundStyle(DawtColor.inkMuted)
                Button {
                    Task { await appState.signInWithApple() }
                } label: {
                    Label(
                        appState.authService.isBusy ? "Signing in…" : "Sign in with Apple",
                        systemImage: "apple.logo"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DawtColor.ink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.white)
                    .font(DawtType.body(16, weight: .semibold))
                }
                .disabled(appState.authService.isBusy)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                if let error = appState.authService.lastError {
                    Text(error)
                        .font(DawtType.body(12))
                        .foregroundStyle(DawtColor.roseDeep)
                }
            }
        }
    }

    private var shortUserLabel: String {
        if !appState.profile.displayName.isEmpty {
            return appState.profile.displayName
        }
        if let email = appState.authService.session?.email, !email.isEmpty {
            return email
        }
        let id = appState.authService.userId ?? ""
        return id.prefix(8) + "…"
    }
}

struct PartnerSharingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var acceptCode = ""

    var body: some View {
        List {
            Section {
                Text("Partners see period timing, fertile window, and phase — not your full symptom diary.")
                    .font(DawtType.body(13))
                    .foregroundStyle(DawtColor.inkMuted)
            }

            if !appState.authService.isSignedIn {
                Section {
                    Text("Sign in from Profile to invite or accept a partner.")
                        .foregroundStyle(DawtColor.inkMuted)
                }
            } else {
                Section("Invite partner") {
                    Button("Create invite code") {
                        Task {
                            await appState.partnerService.createInvite(session: appState.authService.session)
                        }
                    }
                    .disabled(appState.partnerService.isBusy)

                    if let code = appState.partnerService.latestInviteCode {
                        LabeledContent("Code", value: code)
                        ShareLink(item: "Join me on dawt with invite code \(code)") {
                            Label("Share code", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                Section("Accept invite") {
                    TextField("Partner code", text: $acceptCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Button("Accept") {
                        Task {
                            await appState.partnerService.acceptInvite(
                                session: appState.authService.session,
                                code: acceptCode
                            )
                            acceptCode = ""
                        }
                    }
                    .disabled(appState.partnerService.isBusy || acceptCode.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section("People I share with") {
                    if appState.partnerService.ownedLinks.isEmpty {
                        Text("No active partners yet.")
                            .foregroundStyle(DawtColor.inkMuted)
                    } else {
                        ForEach(appState.partnerService.ownedLinks) { link in
                            HStack {
                                Text(shortId(link.partnerUserId))
                                Spacer()
                                Button("Revoke", role: .destructive) {
                                    Task {
                                        await appState.partnerService.revoke(
                                            session: appState.authService.session,
                                            link: link
                                        )
                                    }
                                }
                                .font(DawtType.body(14))
                            }
                        }
                    }
                }

                Section("Shared with me") {
                    if appState.partnerService.sharedWithMe.isEmpty {
                        Text("Nobody has shared with you yet.")
                            .foregroundStyle(DawtColor.inkMuted)
                    } else {
                        ForEach(appState.partnerService.sharedWithMe) { link in
                            if let snap = appState.partnerService.snapshot(forOwner: link.ownerUserId) {
                                PartnerSnapshotCard(snapshot: snap)
                            } else {
                                Text("Waiting for \(shortId(link.ownerUserId)) to sync a snapshot…")
                                    .foregroundStyle(DawtColor.inkMuted)
                            }
                        }
                    }
                }
            }

            if !appState.partnerService.statusMessage.isEmpty {
                Section {
                    Text(appState.partnerService.statusMessage)
                        .font(DawtType.body(12))
                        .foregroundStyle(DawtColor.inkMuted)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DawtBackground())
        .navigationTitle("Partner sharing")
        .task {
            await appState.partnerService.refresh(session: appState.authService.session)
        }
        .refreshable {
            await appState.partnerService.refresh(session: appState.authService.session)
        }
    }

    private func shortId(_ id: UUID) -> String {
        String(id.uuidString.prefix(8)).uppercased()
    }
}

struct PartnerSnapshotCard: View {
    let snapshot: CycleShareSnapshotDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(phaseTitle)
                .font(DawtType.body(16, weight: .semibold))
            if let day = snapshot.cycleDay {
                Text("Cycle day \(day)")
                    .font(DawtType.body(14))
                    .foregroundStyle(DawtColor.inkMuted)
            }
            if let next = snapshot.nextPeriodStart {
                Text("Next period ~ \(next)")
                    .font(DawtType.body(14))
            }
            if let start = snapshot.fertileWindowStart, let end = snapshot.fertileWindowEnd {
                Text("Fertile window \(start) → \(end)")
                    .font(DawtType.body(13))
                    .foregroundStyle(DawtColor.fertile)
            }
            Text("Predictions only — not medical advice or contraception.")
                .font(DawtType.body(11))
                .foregroundStyle(DawtColor.inkMuted)
        }
        .padding(.vertical, 4)
    }

    private var phaseTitle: String {
        guard let raw = snapshot.phase, let phase = CyclePhase(rawValue: raw) else {
            return "Shared cycle"
        }
        return phase.title
    }
}
