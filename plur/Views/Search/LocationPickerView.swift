import SwiftUI

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let locationStore: LocationStore
    var onChanged: () -> Void

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.plurVoid.ignoresSafeArea()

                if locationStore.isLoading && locationStore.allLocations.isEmpty {
                    ProgressView("Loading cities...")
                        .tint(Color.plurViolet)
                        .foregroundStyle(Color.plurMuted)
                } else if filteredLocations.isEmpty {
                    VStack(spacing: Spacing.lg) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.plurFaint)
                        Text("No cities found")
                            .font(.plurBody())
                            .foregroundStyle(Color.plurMuted)
                    }
                } else {
                    locationList
                }
            }
            .navigationTitle("Select City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.plurMuted)
                }
                if locationStore.selectedLocation != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Clear") {
                            locationStore.clearLocation()
                            onChanged()
                            dismiss()
                        }
                        .foregroundStyle(Color.plurRose)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search cities...")
            .task {
                await locationStore.loadLocations()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var locationList: some View {
        List {
            ForEach(groupedLocations, id: \.state) { group in
                Section {
                    ForEach(group.locations) { location in
                        Button {
                            locationStore.setLocation(location)
                            onChanged()
                            dismiss()
                        } label: {
                            HStack {
                                Text(location.city)
                                    .font(.plurBody())
                                    .foregroundStyle(Color.plurGhost)
                                Spacer()
                                if locationStore.selectedLocation?.id == location.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.plurViolet)
                                }
                            }
                        }
                        .listRowBackground(Color.plurSurface)
                    }
                } header: {
                    Text(group.state)
                        .font(.plurMicro())
                        .foregroundStyle(Color.plurMuted)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var filteredLocations: [EDMTrainLocation] {
        if searchText.isEmpty {
            return locationStore.allLocations
        }
        let q = searchText.lowercased()
        return locationStore.allLocations.filter {
            $0.city.lowercased().contains(q) || $0.state.lowercased().contains(q) || $0.stateCode.lowercased().contains(q)
        }
    }

    private var groupedLocations: [LocationGroup] {
        Dictionary(grouping: filteredLocations, by: \.state)
            .map { LocationGroup(state: $0.key, locations: $0.value.sorted { $0.city < $1.city }) }
            .sorted { $0.state < $1.state }
    }
}

private struct LocationGroup {
    let state: String
    let locations: [EDMTrainLocation]
}
