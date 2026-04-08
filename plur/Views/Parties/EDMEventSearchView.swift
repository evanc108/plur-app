import SwiftUI

struct EDMEventSearchView: View {
    let events: [EDMTrainEvent]
    @Binding var selection: EDMTrainEvent?
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    var body: some View {
        ZStack {
            Color.plurVoid.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: Spacing.xs) {
                    ForEach(filteredEvents) { event in
                        Button {
                            selection = event
                            dismiss()
                        } label: {
                            HStack(spacing: Spacing.sm) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: Radius.thumbnail)
                                        .fill(Color.plurViolet.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "music.mic")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color.plurViolet)
                                }

                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(event.displayName)
                                        .font(.plurBodyBold(14))
                                        .foregroundStyle(Color.plurGhost)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    if let venue = event.venue {
                                        Text([venue.name, venue.location].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · "))
                                            .font(.plurCaption(11))
                                            .foregroundStyle(Color.plurMuted)
                                            .lineLimit(2)
                                    }
                                }

                                Spacer()

                                if selection?.id == event.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Color.plurViolet)
                                }
                            }
                            .padding(Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.innerCard)
                                    .fill(Color.plurSurface2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Radius.innerCard)
                                            .stroke(
                                                selection?.id == event.id
                                                    ? Color.plurViolet.opacity(0.3)
                                                    : Color.plurBorder,
                                                lineWidth: 1
                                            )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        .navigationTitle("Select Rave")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
    }

    private var filteredEvents: [EDMTrainEvent] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return events }
        let q = trimmed.lowercased()
        return events.filter { event in
            if event.displayName.lowercased().contains(q) { return true }
            if let venue = event.venue {
                if venue.name.lowercased().contains(q) { return true }
                if (venue.location ?? "").lowercased().contains(q) { return true }
            }
            return false
        }
    }
}
