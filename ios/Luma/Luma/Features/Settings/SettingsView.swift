import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var exportURL: URL?
    @State private var showDeleteConfirm = false
    @State private var supabaseURL = ""
    @State private var syncMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LumaBackground()
                List {
                    Section("Profile") {
                        Picker("Life stage", selection: $appState.profile.goal) {
                            ForEach(LifeStageGoal.allCases) { goal in
                                Text(goal.title).tag(goal)
                            }
                        }
                        Toggle("Teen-friendly mode", isOn: $appState.profile.teenMode)
                        Stepper("Cycle length: \(appState.profile.typicalCycleLength)d", value: $appState.profile.typicalCycleLength, in: 21...45)
                        Stepper("Period length: \(appState.profile.typicalPeriodLength)d", value: $appState.profile.typicalPeriodLength, in: 2...10)
                    }

                    Section("AI provider") {
                        Picker("Provider", selection: $appState.profile.aiProviderPreference) {
                            ForEach(AIProviderKind.allCases) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        Toggle("Share cycle context with AI", isOn: $appState.profile.aiContextConsent)
                        Text("Org gateway keys stay on the server. BYOK providers need configuration before use; Mock works offline.")
                            .font(LumaType.body(12))
                            .foregroundStyle(LumaColor.inkMuted)
                    }

                    Section("Reminders & sync") {
                        Toggle("Reminders", isOn: $appState.profile.remindersEnabled)
                            .onChange(of: appState.profile.remindersEnabled) { _, _ in
                                NotificationScheduler.reschedule(profile: appState.profile, prediction: appState.prediction)
                            }
                        TextField("Supabase URL (optional)", text: $supabaseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Toggle("Cloud sync configured", isOn: $appState.profile.supabaseConfigured)
                        Button("Sync now") {
                            Task {
                                await appState.syncService.syncNow(profile: appState.profile)
                                syncMessage = appState.syncService.statusMessage
                            }
                        }
                        if !syncMessage.isEmpty {
                            Text(syncMessage).font(LumaType.body(12)).foregroundStyle(LumaColor.inkMuted)
                        }
                        Text("Pending local changes: \(appState.syncService.pendingCount)")
                            .font(LumaType.body(12))
                            .foregroundStyle(LumaColor.inkMuted)
                    }

                    Section("Data") {
                        Button("Export JSON") { exportData() }
                        if let exportURL {
                            ShareLink(item: exportURL) {
                                Label("Share export", systemImage: "square.and.arrow.up")
                            }
                        }
                        Button("Delete all local data", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }

                    Section("About") {
                        LabeledContent("Catalog items", value: "\(SymptomCatalog.allCount)")
                        LabeledContent("Algorithm", value: CyclePredictionEngine.algorithmVersion)
                        Text("Luma is free and open source. Not affiliated with Flo Health. Educational only — not medical advice or contraception.")
                            .font(LumaType.body(12))
                            .foregroundStyle(LumaColor.inkMuted)
                        Link("Product requirements", destination: URL(string: "https://github.com/masterwaynecc/Flo/blob/main/docs/PRD.md")!)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Profile")
            .onChange(of: appState.profile) { _, _ in
                appState.persist()
            }
            .confirmationDialog("Delete all local data?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    appState.deleteAllLocalData()
                }
            }
        }
    }

    private func exportData() {
        guard let data = appState.exportJSON() else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("luma-export.json")
        try? data.write(to: url)
        exportURL = url
    }
}
