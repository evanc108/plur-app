import SwiftUI

struct EventResultCard: View {
    let event: EDMTrainEvent

    var body: some View {
        GlassCard(tint: event.isFestival ? Color.plurViolet : nil) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Title + Festival badge
                HStack(alignment: .top) {
                    Text(event.displayName)
                        .font(.plurH3())
                        .foregroundStyle(Color.plurGhost)
                        .lineLimit(2)

                    Spacer()

                    if event.isFestival {
                        Text("Festival")
                            .font(.plurMicro())
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, Spacing.xxs)
                            .background(Color.plurViolet.opacity(0.2))
                            .foregroundStyle(Color.plurViolet)
                            .clipShape(Capsule())
                    }
                }

                // Date
                if let parsed = event.parsedDate {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "calendar")
                            .font(.plurCaption())
                            .foregroundStyle(Color.plurTeal)
                        Text(parsed, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                            .font(.plurCaption())
                            .foregroundStyle(Color.plurMuted)
                    }
                }

                // Artists with overflow
                if event.name != nil, let artists = event.artistList, !artists.isEmpty {
                    artistText(artists)
                }

                // Venue + City, State (always show state for disambiguation)
                if let venue = event.venue {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(Color.plurRose)
                            .font(.plurCaption())
                        Text(venue.name)
                            .font(.plurCaption())
                            .foregroundStyle(Color.plurGhost)
                        Text(venueLocationText(venue))
                            .font(.plurCaption())
                            .foregroundStyle(Color.plurMuted)
                    }
                }

                // Bottom row: ages + ticket link
                HStack(spacing: Spacing.md) {
                    if let ages = event.ages, !ages.isEmpty {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "person.fill")
                                .font(.plurMicro())
                            Text(ages)
                                .font(.plurMicro())
                        }
                        .foregroundStyle(Color.plurFaint)
                    }

                    if event.link != nil {
                        Spacer()
                        HStack(spacing: Spacing.xxs) {
                            Text("Tickets")
                                .font(.plurMicro())
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(Color.plurTeal)
                    }
                }
            }
        }
    }

    private func artistText(_ artists: [EDMTrainArtist]) -> some View {
        let maxVisible = 3
        let names = artists.prefix(maxVisible).map { artist in
            if artist.b2bInd == true {
                return "B2B \(artist.name)"
            }
            return artist.name
        }
        let text = names.joined(separator: " \u{00B7} ")
        let overflow = artists.count > maxVisible ? " \u{00B7} +\(artists.count - maxVisible) more" : ""

        return Text(text + overflow)
            .font(.plurCaption())
            .foregroundStyle(Color.plurMuted)
            .lineLimit(1)
    }

    private func venueLocationText(_ venue: EDMTrainVenue) -> String {
        var parts: [String] = []
        if let location = venue.location {
            parts.append(location)
        }
        if let state = venue.state {
            // If location already contains state, skip
            if let location = venue.location, !location.contains(state) {
                parts.append(state)
            } else if venue.location == nil {
                parts.append(state)
            }
        }
        return parts.isEmpty ? "" : "\u{00B7} " + parts.joined(separator: ", ")
    }
}
