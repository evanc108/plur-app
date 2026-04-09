import SwiftUI

struct CreatePartyView: View {
    @Bindable var viewModel: PartyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var eventName = ""
    @State private var selectedEDMEvent: EDMTrainEvent?
    @State private var edmEvents: [EDMTrainEvent] = []
    @State private var isLoadingEvents = false
    @State private var venue = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
    @State private var playlistLink = ""
    @State private var isCreating = false
    @State private var showCreateError = false
    @State private var createErrorMessage = ""
    @State private var showEventPicker = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedEDMEvent != nil &&
        !eventName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @ViewBuilder
    private var createPartyFormContent: some View {
        VStack(spacing: Spacing.lg) {
            partyDetailsSection
            datesSection
            optionalSection
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.xxxl)
    }

    @ViewBuilder
    private var partyDetailsSection: some View {
        formSection(title: "PARTY") {
            fieldRow("Party name", text: $name)
            ravePickerButton
            fieldRow("Event / Festival", text: $eventName)
            fieldRow("Venue", text: $venue)
        }
    }

    private var ravePickerButton: some View {
        Button { showEventPicker = true } label: {
            HStack(spacing: Spacing.xs) {
                Text("Rave")
                    .font(.plurBody())
                    .foregroundStyle(Color.plurGhost)
                Spacer()
                if isLoadingEvents && edmEvents.isEmpty {
                    ProgressView().tint(Color.plurViolet)
                } else if let selectedEDMEvent {
                    Text(Self.eventLabel(selectedEDMEvent))
                        .font(.plurCaption())
                        .foregroundStyle(Color.plurMuted)
                        .lineLimit(1)
                } else {
                    Text("Select…")
                        .font(.plurCaption())
                        .foregroundStyle(Color.plurFaint)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.plurFaint)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .background(Color.plurSurface2, in: RoundedRectangle(cornerRadius: Radius.thumbnail))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.thumbnail)
                    .stroke(Color.plurBorder, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var datesSection: some View {
        formSection(title: "DATES") {
            DatePicker("Start", selection: $startDate, displayedComponents: .date)
                .font(.plurBody())
                .foregroundStyle(Color.plurGhost)
                .tint(Color.plurViolet)
            DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                .font(.plurBody())
                .foregroundStyle(Color.plurGhost)
                .tint(Color.plurViolet)
        }
    }

    @ViewBuilder
    private var optionalSection: some View {
        formSection(title: "OPTIONAL") {
            fieldRow("Playlist link", text: $playlistLink, keyboard: .URL)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.plurVoid.ignoresSafeArea()

                ScrollView {
                    createPartyFormContent
                }
            }
            .navigationTitle("Create Party")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.plurGhost)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        isCreating = true
                        Task {
                            guard let selectedEDMEvent else {
                                isCreating = false
                                createErrorMessage = "Please select a rave."
                                showCreateError = true
                                return
                            }
                            let success = await viewModel.createParty(
                                name: name,
                                eventName: eventName,
                                raveId: selectedEDMEvent.id,
                                venue: venue.isEmpty ? "TBD" : venue,
                                startDate: startDate,
                                endDate: endDate,
                                playlistLink: playlistLink.isEmpty ? nil : playlistLink
                            )
                            isCreating = false
                            if success {
                                dismiss()
                            } else {
                                createErrorMessage = viewModel.generalError ?? "Please try again."
                                showCreateError = true
                            }
                        }
                    }
                    .font(.plurBodyBold())
                    .foregroundStyle(isValid ? Color.plurViolet : Color.plurFaint)
                    .disabled(!isValid || isCreating)
                }
            }
            .task {
                await loadEDMEventsIfNeeded()
            }
            .onChange(of: selectedEDMEvent?.id) { _, _ in
                applyDefaultsFromSelectedEvent()
            }
            .overlay {
                if isCreating {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        ProgressView("Creating…")
                            .tint(Color.plurViolet)
                            .foregroundStyle(Color.plurGhost)
                            .padding(Spacing.xl)
                            .background(Color.plurSurface, in: RoundedRectangle(cornerRadius: Radius.card))
                    }
                    .transition(.opacity)
                }
            }
            .animation(.default, value: isCreating)
            .alert("Couldn't create party", isPresented: $showCreateError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(createErrorMessage)
            }
            .sheet(isPresented: $showEventPicker) {
                NavigationStack {
                    EDMEventSearchView(events: edmEvents, selection: $selectedEDMEvent)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showEventPicker = false }
                                    .foregroundStyle(Color.plurGhost)
                            }
                        }
                }
                .preferredColorScheme(.dark)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Form Helpers

    private func formSection<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.plurMicro())
                .foregroundStyle(Color.plurMuted)
                .tracking(1.5)

            GlassCard {
                VStack(spacing: Spacing.sm) {
                    content()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func fieldRow(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .font(.plurBody())
            .foregroundStyle(Color.plurGhost)
            .keyboardType(keyboard)
            .autocorrectionDisabled(keyboard == .URL)
            .textInputAutocapitalization(keyboard == .URL ? .never : .words)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Color.plurSurface2, in: RoundedRectangle(cornerRadius: Radius.thumbnail))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.thumbnail)
                    .stroke(Color.plurBorder, lineWidth: 1)
            )
    }

    private static func eventLabel(_ event: EDMTrainEvent) -> String {
        if let venue = event.venue, let location = venue.location, !location.isEmpty {
            return "\(event.displayName) — \(location)"
        }
        return event.displayName
    }

    @MainActor
    private func loadEDMEventsIfNeeded() async {
        guard edmEvents.isEmpty, !isLoadingEvents else { return }
        isLoadingEvents = true
        defer { isLoadingEvents = false }

        do {
            let fetched = try await EDMTrainClient().fetchEvents(EventRequest())
            edmEvents = fetched
        } catch {
            createErrorMessage = error.localizedDescription
            showCreateError = true
        }
    }

    @MainActor
    private func applyDefaultsFromSelectedEvent() {
        guard let event = selectedEDMEvent else { return }
        eventName = event.displayName
        venue = event.venue?.name ?? ""
        if let parsed = event.parsedDate {
            startDate = parsed
            endDate = Calendar.current.date(byAdding: .day, value: 2, to: parsed) ?? parsed
        }
    }
}
