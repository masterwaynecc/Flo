import SwiftUI

struct DayLogView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let date: Date
    @State private var flow: FlowLevel = .none
    @State private var selectedSymptoms: Set<String> = []
    @State private var selectedMoods: Set<String> = []
    @State private var notes: String = ""
    @State private var category: LogCategory = .flow

    enum LogCategory: String, CaseIterable, Identifiable {
        case flow, symptoms, mood, notes
        var id: String { rawValue }
        var title: String {
            switch self {
            case .flow: return "Flow"
            case .symptoms: return "Symptoms"
            case .mood: return "Mood"
            case .notes: return "Notes"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LumaBackground()
                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LogCategory.allCases) { item in
                                Button(item.title) { category = item }
                                    .font(LumaType.body(14, weight: .semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(category == item ? LumaColor.rose : Color.white.opacity(0.7), in: Capsule())
                                    .foregroundStyle(category == item ? Color.white : LumaColor.ink)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    ScrollView {
                        Group {
                            switch category {
                            case .flow: flowSection
                            case .symptoms: chipGrid(items: SymptomCatalog.symptoms, selection: $selectedSymptoms)
                            case .mood: chipGrid(items: SymptomCatalog.moods, selection: $selectedMoods)
                            case .notes:
                                TextField("Anything else to remember?", text: $notes, axis: .vertical)
                                    .lineLimit(4...8)
                                    .padding()
                                    .lumaCard()
                                    .padding()
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: load)
        }
    }

    private var flowSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(FlowLevel.allCases) { level in
                Button {
                    flow = level
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: level == .none ? "circle" : "drop.fill")
                            .font(.title2)
                            .foregroundStyle(level == .none ? LumaColor.inkMuted : LumaColor.period)
                        Text(level.title)
                            .font(LumaType.body(15, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(flow == level ? LumaColor.rose.opacity(0.18) : Color.white.opacity(0.75))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(flow == level ? LumaColor.rose : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }

    private func chipGrid(items: [CatalogItem], selection: Binding<Set<String>>) -> some View {
        let grouped = Dictionary(grouping: items, by: \.category)
        return VStack(alignment: .leading, spacing: 16) {
            ForEach(grouped.keys.sorted(), id: \.self) { key in
                VStack(alignment: .leading, spacing: 8) {
                    Text(key)
                        .font(LumaType.body(13, weight: .semibold))
                        .foregroundStyle(LumaColor.inkMuted)
                    FlowLayout(spacing: 8) {
                        ForEach(grouped[key] ?? []) { item in
                            let on = selection.wrappedValue.contains(item.id)
                            Button {
                                if on { selection.wrappedValue.remove(item.id) }
                                else { selection.wrappedValue.insert(item.id) }
                            } label: {
                                Text(item.title)
                                    .font(LumaType.body(14, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(on ? LumaColor.rose : Color.white.opacity(0.75), in: Capsule())
                                    .foregroundStyle(on ? Color.white : LumaColor.ink)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(16)
    }

    private func load() {
        if let existing = appState.logFor(date: date) {
            flow = existing.flow
            selectedSymptoms = Set(existing.symptomIDs)
            selectedMoods = Set(existing.moodIDs)
            notes = existing.notes
        }
    }

    private func save() {
        var log = appState.logFor(date: date) ?? DayLog(date: date)
        log.flow = flow
        log.symptomIDs = Array(selectedSymptoms).sorted()
        log.moodIDs = Array(selectedMoods).sorted()
        log.notes = notes
        log.updatedAt = Date()
        appState.upsertDayLog(log)
        dismiss()
    }
}

/// Simple wrapping layout for chips without external dependencies.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}
