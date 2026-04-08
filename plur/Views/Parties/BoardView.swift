import SwiftUI

struct BoardView: View {
    let party: RaveGroup
    @Bindable var viewModel: PartyViewModel
    @State private var showQRFullScreen = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                eventCard
                crewSection
                inviteCrewSection
                pinnedItemsSection
                pinnedMessagesSection
                playlistSection
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
        }
        .background(Color.plurVoid)
        .sheet(isPresented: $showQRFullScreen) {
            QRFullScreenView(party: party, viewModel: viewModel)
        }
    }

    // MARK: - Event Info

    private var eventCard: some View {
        GlassCard(tint: Color.plurViolet) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(party.eventName)
                    .font(.plurH2())
                    .foregroundStyle(Color.plurGhost)
                HStack(spacing: Spacing.md) {
                    Label(party.dateRangeText, systemImage: "calendar")
                    Label(party.venue, systemImage: "mappin.and.ellipse")
                }
                .font(.plurCaption())
                .foregroundStyle(Color.plurMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Crew

    private var crewSection: some View {
        GlassCard(tint: Color.plurViolet) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Crew")
                    .font(.plurH3())
                    .foregroundStyle(Color.plurGhost)

                let members = viewModel.members[party.id] ?? []
                ForEach(members) { member in
                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .fill(avatarColor(for: member.displayName))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Text(String(member.displayName.prefix(1)))
                                    .font(.plurBodyBold(14))
                                    .foregroundStyle(.white)
                            }

                        Text(member.displayName)
                            .font(.plurBody())
                            .foregroundStyle(Color.plurGhost)

                        Spacer()

                        Label(member.rsvpStatus.label, systemImage: member.rsvpStatus.icon)
                            .font(.plurMicro())
                            .foregroundStyle(rsvpColor(member.rsvpStatus))
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, Spacing.xxs)
                            .background(
                                rsvpColor(member.rsvpStatus).opacity(0.15),
                                in: Capsule()
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Pinned Items

    private var pinnedItemsSection: some View {
        let items = viewModel.pinnedItems[party.id] ?? []
        return Group {
            if !items.isEmpty {
                GlassCard(tint: Color.plurAmber) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Pinned")
                            .font(.plurH3())
                            .foregroundStyle(Color.plurGhost)

                        ForEach(items) { item in
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: item.icon)
                                    .font(.plurBody())
                                    .foregroundStyle(Color.plurAmber)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.label)
                                        .font(.plurCaption())
                                        .foregroundStyle(Color.plurMuted)
                                    Text(item.value)
                                        .font(.plurBody())
                                        .foregroundStyle(Color.plurGhost)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Pinned Messages

    private var pinnedMessagesSection: some View {
        let pinned = viewModel.pinnedMessages(for: party.id)
        return Group {
            if !pinned.isEmpty {
                GlassCard(tint: Color.plurAmber) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(Color.plurAmber)
                            Text("Pinned Messages")
                                .font(.plurH3())
                                .foregroundStyle(Color.plurGhost)
                        }

                        ForEach(pinned) { msg in
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(msg.senderName)
                                    .font(.plurMicro())
                                    .foregroundStyle(Color.plurMuted)
                                Text(msg.content)
                                    .font(.plurBody())
                                    .foregroundStyle(Color.plurGhost)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.sm)
                            .background(
                                Color.plurAmber.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: Radius.thumbnail)
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Playlist

    private var playlistSection: some View {
        Group {
            if let link = party.playlistLink, !link.isEmpty {
                GlassCard(tint: Color.plurTeal) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.plurTeal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Squad Playlist")
                                .font(.plurBodyBold())
                                .foregroundStyle(Color.plurGhost)
                            Text(link)
                                .font(.plurCaption())
                                .foregroundStyle(Color.plurMuted)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.plurFaint)
                    }
                }
            }
        }
    }

    // MARK: - Invite Crew

    private var inviteCrewSection: some View {
        GlassCard(tint: Color.plurViolet) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Invite Crew")
                    .font(.plurH3())
                    .foregroundStyle(Color.plurGhost)

                HStack(spacing: Spacing.md) {
                    Image(uiImage: QRCodeGenerator.image(for: viewModel.inviteLink(for: party), size: 80))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture { showQRFullScreen = true }

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(spacing: Spacing.xxs) {
                            Text("Code:")
                                .font(.plurCaption())
                                .foregroundStyle(Color.plurMuted)
                            Text(party.inviteCode)
                                .font(.plurBodyBold().monospaced())
                                .foregroundStyle(Color.plurGhost)
                        }

                        ShareLink(
                            item: viewModel.inviteLink(for: party),
                            subject: Text("Join \(party.name)"),
                            message: Text("Join my crew for \(party.eventName) on PLUR!")
                        ) {
                            Label("Share Invite", systemImage: "square.and.arrow.up")
                                .font(.plurBodyBold(13))
                                .foregroundStyle(.white)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.xs)
                                .background(Color.plurViolet, in: Capsule())
                        }
                    }
                }

                Text("Tap QR to enlarge. Share via iMessage, socials, or show in person.")
                    .font(.plurTiny())
                    .foregroundStyle(Color.plurFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [.plurViolet, .plurRose, .plurTeal, .plurAmber]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }

    private func rsvpColor(_ status: RSVPStatus) -> Color {
        switch status {
        case .going: Color.plurTeal
        case .maybe: Color.plurAmber
        case .invited: Color.plurViolet
        }
    }
}

// MARK: - QR Full Screen

private struct QRFullScreenView: View {
    let party: RaveGroup
    let viewModel: PartyViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.plurVoid.ignoresSafeArea()

                VStack(spacing: Spacing.xl) {
                    Spacer()

                    Text(party.name)
                        .font(.plurH2())
                        .foregroundStyle(Color.plurGhost)

                    Image(uiImage: QRCodeGenerator.image(for: viewModel.inviteLink(for: party), size: 280))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 260, height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.thumbnail))

                    VStack(spacing: Spacing.xxs) {
                        Text("Party Code")
                            .font(.plurCaption())
                            .foregroundStyle(Color.plurMuted)
                        Text(party.inviteCode)
                            .font(.plurHeading(28).monospaced())
                            .foregroundStyle(Color.plurGhost)
                    }

                    ShareLink(
                        item: viewModel.inviteLink(for: party),
                        subject: Text("Join \(party.name)"),
                        message: Text("Join my crew for \(party.eventName) on PLUR!")
                    ) {
                        Text("Share Link")
                            .font(.plurBodyBold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .foregroundStyle(.white)
                            .background(Color.plurViolet, in: RoundedRectangle(cornerRadius: Radius.pill))
                    }
                    .padding(.horizontal, Spacing.xxxl)

                    Spacer()
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.plurGhost)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
