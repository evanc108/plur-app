import SwiftUI

struct ScheduleView: View {
    let party: RaveGroup
    @Bindable var viewModel: PartyViewModel

    private var stages: [(stage: String, artists: [Artist])] {
        viewModel.artistsByStage(for: party.id)
    }

    var body: some View {
        ScrollView {
            if stages.isEmpty {
                VStack(spacing: Spacing.lg) {
                    Spacer().frame(height: 60)
                    Image(systemName: "music.mic")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.plurFaint)
                    Text("No Lineup Yet")
                        .font(.plurH2())
                        .foregroundStyle(Color.plurGhost)
                    Text("The schedule will appear here once it's available.")
                        .font(.plurBody())
                        .foregroundStyle(Color.plurMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Spacing.xl)
            } else {
                LazyVStack(spacing: Spacing.xl, pinnedViews: .sectionHeaders) {
                    ForEach(stages, id: \.stage) { group in
                        Section {
                            VStack(spacing: Spacing.xs) {
                                ForEach(group.artists) { artist in
                                    ArtistRow(
                                        artist: artist,
                                        isSaved: viewModel.isArtistSaved(artist.id),
                                        friendName: viewModel.friendArtistMap[artist.id],
                                        onToggle: { viewModel.toggleArtist(artist, in: party.id) }
                                    )
                                }
                            }
                        } header: {
                            stageHeader(group.stage)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.lg)
            }
        }
        .background(Color.plurVoid)
    }

    private func stageHeader(_ name: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: stageIcon(name))
                .foregroundStyle(Color.plurViolet)
            Text(name.uppercased())
                .font(.plurMicro())
                .foregroundStyle(Color.plurMuted)
                .tracking(1.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.xxs)
        .background(Color.plurVoid)
    }

    private func stageIcon(_ name: String) -> String {
        switch name {
        case "Kinetic Field": "bolt.fill"
        case "Circuit Grounds": "waveform.path"
        case "Cosmic Meadow": "sparkles"
        default: "music.mic"
        }
    }
}

// MARK: - Artist Row

private struct ArtistRow: View {
    let artist: Artist
    let isSaved: Bool
    let friendName: String?
    let onToggle: () -> Void

    var body: some View {
        GlassCard(tint: Color.plurViolet, padding: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    if let start = artist.startTime, let end = artist.endTime {
                        Text(timeRange(start, end))
                            .font(.plurMicro())
                            .foregroundStyle(Color.plurViolet)
                    }

                    Text(artist.name)
                        .font(.plurBodyBold(14))
                        .foregroundStyle(Color.plurGhost)

                    if let stage = artist.stage {
                        Text(stage)
                            .font(.plurCaption(11))
                            .foregroundStyle(Color.plurMuted)
                    }

                    if let friend = friendName {
                        HStack(spacing: Spacing.xxs) {
                            Circle()
                                .fill(Color.plurTeal)
                                .frame(width: 16, height: 16)
                                .overlay {
                                    Text(String(friend.prefix(1)))
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            Text("\(friend) is going")
                                .font(.plurTiny())
                                .foregroundStyle(Color.plurTeal)
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()

                Button(action: onToggle) {
                    Image(systemName: isSaved ? "star.fill" : "star")
                        .font(.system(size: 20))
                        .foregroundStyle(isSaved ? Color.plurAmber : Color.plurFaint)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
            }
        }
    }

    private func timeRange(_ start: Date, _ end: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
    }
}
