import SwiftUI

struct AssistantView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var input = ""
    @State private var messages: [AIMessage] = [
        AIMessage(role: .assistant, content: "Hi — I'm dawt's Health Assistant. I can share general educational info about cycles. I'm not a doctor and not contraception. What would you like to know?")
    ]
    @State private var isStreaming = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ZStack {
                DawtBackground()
                VStack(spacing: 0) {
                    disclaimerBanner
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(messages) { message in
                                    bubble(message)
                                        .id(message.id)
                                }
                            }
                            .padding(16)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let last = messages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }

                    if let errorText {
                        Text(errorText)
                            .font(DawtType.body(12))
                            .foregroundStyle(DawtColor.roseDeep)
                            .padding(.horizontal)
                    }

                    composer
                }
            }
            .navigationTitle("Health Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text(appState.profile.aiProviderPreference.title)
                        .font(DawtType.body(11))
                        .foregroundStyle(DawtColor.inkMuted)
                }
            }
        }
    }

    private var disclaimerBanner: some View {
        Text("Educational only · Not medical advice · Not contraception")
            .font(DawtType.body(11, weight: .medium))
            .foregroundStyle(DawtColor.inkMuted)
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(Color.white.opacity(0.55))
    }

    private func bubble(_ message: AIMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.content)
                .font(DawtType.body(15))
                .foregroundStyle(message.role == .user ? Color.white : DawtColor.ink)
                .padding(12)
                .background(
                    message.role == .user ? DawtColor.rose : Color.white.opacity(0.85),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            if message.role != .user { Spacer(minLength: 40) }
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Ask about your cycle…", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .padding(12)
                .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? DawtColor.rose : DawtColor.inkMuted.opacity(0.4))
            }
            .disabled(!canSend)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    @MainActor
    private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !empty(text) else { return }
        input = ""
        errorText = nil

        let userMessage = AIMessage(role: .user, content: text)
        messages.append(userMessage)

        let assistantID = UUID()
        messages.append(AIMessage(id: assistantID, role: .assistant, content: ""))
        isStreaming = true

        let history = messages.filter { $0.id != assistantID }
        let stream = appState.aiRouter.stream(
            messages: history,
            profile: appState.profile,
            prediction: appState.prediction,
            logs: appState.dayLogs
        )

        do {
            for try await chunk in stream {
                if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                    messages[idx].content += chunk.text
                }
            }
        } catch {
            errorText = error.localizedDescription
            if let idx = messages.firstIndex(where: { $0.id == assistantID }), messages[idx].content.isEmpty {
                messages[idx].content = "I couldn't reach that provider. Try the built-in demo provider in Settings."
            }
        }
        isStreaming = false
    }

    private func empty(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
