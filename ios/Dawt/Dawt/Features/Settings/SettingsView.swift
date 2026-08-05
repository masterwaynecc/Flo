import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var exportURL: URL?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                DawtBackground()
                List {
                    AccountSectionView()

                    Section {
                        NavigationLink {
                            PartnerSharingView()
                                .environmentObject(appState)
                        } label: {
                            Label("Partner sharing", systemImage: "person.2.fill")
                        }
                    }

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

                    Section("AI provider (open-weight only)") {
                        Picker("Provider", selection: $appState.profile.aiProviderPreference) {
                            ForEach(AIProviderKind.allCases) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        Toggle("Share cycle context with AI", isOn: $appState.profile.aiContextConsent)
                        Text("dawt uses open-weight models only (Ollama, vLLM, self-hosted, on-device). Closed-source APIs like OpenAI/Anthropic are not supported. Mock works offline without a model server.")
                            .font(DawtType.body(12))
                            .foregroundStyle(DawtColor.inkMuted)
                    }

                    Section("Reminders") {
                        Toggle("Reminders", isOn: $appState.profile.remindersEnabled)
                            .onChange(of: appState.profile.remindersEnabled) { _, _ in
                                NotificationScheduler.reschedule(profile: appState.profile, prediction: appState.prediction)
                            }
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
                        LabeledContent("Cloud", value: SupabaseConfig.isConfigured ? "Configured" : "Missing keys")
                        Text("dawt is free and open source. Not affiliated with Flo Health. Educational only — not medical advice or contraception.")
                            .font(DawtType.body(12))
                            .foregroundStyle(DawtColor.inkMuted)
                        Link("Source on GitHub", destination: URL(string: "https://github.com/masterwaynecc/dawt")!)
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
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dawt-export.json")
        try? data.write(to: url)
        exportURL = url
    }
}
