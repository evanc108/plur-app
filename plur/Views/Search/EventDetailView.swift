import SwiftUI
import MapKit

struct EventDetailView: View {
    let event: EDMTrainEvent

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                dateSection
                venueSection
                lineupSection
                infoSection
                actionsSection
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxl)
        }
        .plurBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(event.displayName.uppercased())
                .font(.plurHeading(28))
                .foregroundStyle(Color.plurGhost)

            if event.isFestival {
                Text("Festival")
                    .font(.plurMicro())
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.plurViolet.opacity(0.2))
                    .foregroundStyle(Color.plurViolet)
                    .clipShape(Capsule())
            }
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Date & Time

    private var dateSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                sectionLabel("DATE")

                HStack(spacing: Spacing.sm) {
                    Image(systemName: "calendar")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.plurTeal)

                    VStack(alignment: .leading, spacing: 2) {
                        if let parsed = event.parsedDate {
                            Text(parsed, format: .dateTime.weekday(.wide).month(.wide).day().year())
                                .font(.plurBody())
                                .foregroundStyle(Color.plurGhost)
                        } else {
                            Text(event.date)
                                .font(.plurBody())
                                .foregroundStyle(Color.plurGhost)
                        }

                        if let startTime = event.startTime {
                            Text("Starts at \(startTime)")
                                .font(.plurCaption())
                                .foregroundStyle(Color.plurMuted)
                        }

                        if let endTime = event.endTime {
                            Text("Ends at \(endTime)")
                                .font(.plurCaption())
                                .foregroundStyle(Color.plurMuted)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Venue

    @ViewBuilder
    private var venueSection: some View {
        if let venue = event.venue {
            GlassCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    sectionLabel("VENUE")

                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.plurRose)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(venue.name)
                                .font(.plurBodyBold())
                                .foregroundStyle(Color.plurGhost)

                            if let address = venue.address, !address.isEmpty {
                                Text(address)
                                    .font(.plurCaption())
                                    .foregroundStyle(Color.plurMuted)
                            }

                            Text(venueFullLocation(venue))
                                .font(.plurCaption())
                                .foregroundStyle(Color.plurMuted)
                        }
                    }

                    // Map preview
                    if let lat = venue.latitude, let lon = venue.longitude {
                        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: coordinate,
                            latitudinalMeters: 2000,
                            longitudinalMeters: 2000
                        ))) {
                            Marker(venue.name, coordinate: coordinate)
                                .tint(Color.plurRose)
                        }
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.innerCard))
                        .allowsHitTesting(false)

                        Button {
                            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                            mapItem.name = venue.name
                            mapItem.openInMaps()
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "map.fill")
                                Text("Open in Maps")
                            }
                            .font(.plurCaption())
                            .foregroundStyle(Color.plurTeal)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Lineup

    @ViewBuilder
    private var lineupSection: some View {
        if let artists = event.artistList, !artists.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    sectionLabel("LINEUP")

                    VStack(spacing: 0) {
                        ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
                            artistRow(artist, isLast: index == artists.count - 1)
                        }
                    }
                }
            }
        }
    }

    private func artistRow(_ artist: EDMTrainArtist, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        if artist.b2bInd == true {
                            Text("B2B")
                                .font(.plurMicro())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.plurAmber.opacity(0.2))
                                .foregroundStyle(Color.plurAmber)
                                .clipShape(Capsule())
                        }
                        Text(artist.name)
                            .font(.plurBody())
                            .foregroundStyle(Color.plurGhost)
                    }
                }

                Spacer()

                if let link = artist.link, let url = URL(string: link) {
                    Button {
                        openURL(url)
                    } label: {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.plurFaint)
                    }
                }
            }
            .padding(.vertical, Spacing.sm)

            if !isLast {
                Divider()
                    .background(Color.plurBorder)
            }
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                sectionLabel("INFO")

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if let ages = event.ages, !ages.isEmpty {
                        infoRow(icon: "person.fill", label: "Ages", value: ages)
                    }

                    if event.electronicGenreInd == true {
                        infoRow(icon: "waveform", label: "Genre", value: "Electronic")
                    } else if event.otherGenreInd == true {
                        infoRow(icon: "waveform", label: "Genre", value: "Other")
                    }

                    if event.livestreamInd == true {
                        infoRow(icon: "video.fill", label: "Format", value: "Livestream")
                    }
                }
            }
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.plurCaption())
                .foregroundStyle(Color.plurFaint)
                .frame(width: 20)
            Text(label)
                .font(.plurCaption())
                .foregroundStyle(Color.plurMuted)
            Spacer()
            Text(value)
                .font(.plurBodyBold(14))
                .foregroundStyle(Color.plurGhost)
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: Spacing.sm) {
            if let link = event.link, let url = URL(string: link) {
                Button {
                    openURL(url)
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text("View on EDM Train")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .buttonStyle(PLURButtonStyle())
            }
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.plurMicro())
            .foregroundStyle(Color.plurFaint)
            .tracking(1.5)
    }

    private func venueFullLocation(_ venue: EDMTrainVenue) -> String {
        var parts: [String] = []
        if let location = venue.location { parts.append(location) }
        if let state = venue.state { parts.append(state) }
        if let country = venue.country, country != "United States" { parts.append(country) }
        return parts.joined(separator: ", ")
    }
}
