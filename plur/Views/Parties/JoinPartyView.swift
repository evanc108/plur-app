import SwiftUI

enum JoinMethod: String, CaseIterable {
    case link = "Link / Code"
    case scan = "Scan QR"
    case search = "Find People"

    var icon: String {
        switch self {
        case .link: "link"
        case .scan: "qrcode.viewfinder"
        case .search: "magnifyingglass"
        }
    }
}

struct JoinPartyView: View {
    @Bindable var viewModel: PartyViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMethod: JoinMethod = .link

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                methodPicker
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xs)

                switch selectedMethod {
                case .link:
                    JoinByCodeSection(viewModel: viewModel, onDismiss: { dismiss() })
                case .scan:
                    ScanQRSection(viewModel: viewModel, onDismiss: { dismiss() })
                case .search:
                    SearchUsersSection(viewModel: viewModel)
                }
            }
            .background(Color.plurVoid)
            .navigationTitle("Join a Party")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.plurGhost)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var methodPicker: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(JoinMethod.allCases, id: \.self) { method in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedMethod = method
                    }
                } label: {
                    VStack(spacing: Spacing.xxs) {
                        Image(systemName: method.icon)
                            .font(.system(size: 16))
                        Text(method.rawValue)
                            .font(.plurMicro())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        selectedMethod == method
                            ? Color.plurViolet.opacity(0.25)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: Radius.activeTab)
                    )
                    .foregroundStyle(selectedMethod == method ? Color.plurGhost : Color.plurMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: Radius.tab)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.tab)
                        .fill(Color.plurGlass)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.tab)
                        .stroke(Color.plurBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Join by Code / Link

private struct JoinByCodeSection: View {
    @Bindable var viewModel: PartyViewModel
    var onDismiss: () -> Void
    @State private var input = ""
    @State private var showError = false
    @State private var showSuccess = false
    @State private var isJoining = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            Image(systemName: "ticket")
                .font(.system(size: 44))
                .foregroundStyle(Color.plurViolet)

            Text("Paste a PLUR invite link or enter the party code from your crew.")
                .font(.plurBody())
                .foregroundStyle(Color.plurMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)

            TextField("Code or link", text: $input)
                .font(.plurBody().monospaced())
                .foregroundStyle(Color.plurGhost)
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.plurSurface2, in: RoundedRectangle(cornerRadius: Radius.thumbnail))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.thumbnail)
                        .stroke(Color.plurBorder, lineWidth: 1)
                )
                .padding(.horizontal, Spacing.xxl)

            Button {
                isJoining = true
                Task {
                    let success = await viewModel.joinPartyByLink(input)
                    isJoining = false
                    if success { showSuccess = true } else { showError = true }
                }
            } label: {
                Group {
                    if isJoining {
                        ProgressView().tint(.white)
                    } else {
                        Text("Join Party")
                    }
                }
                .font(.plurBodyBold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .foregroundStyle(.white)
                .background(Color.plurViolet, in: RoundedRectangle(cornerRadius: Radius.pill))
            }
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isJoining)
            .opacity(input.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            .padding(.horizontal, Spacing.xxl)

            Spacer()
            Spacer()
        }
        .alert("Not Found", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text("No party found. Check the code or link and try again.")
        }
        .alert("Joined!", isPresented: $showSuccess) {
            Button("OK") { onDismiss() }
        } message: {
            Text("You've joined the party. Head to the Board to see the details.")
        }
    }
}

// MARK: - Scan QR

private struct ScanQRSection: View {
    @Bindable var viewModel: PartyViewModel
    var onDismiss: () -> Void
    @State private var showResult = false
    @State private var joinSucceeded = false
    @State private var scannedValue = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            QRScannerView { value in
                scannedValue = value
                Task {
                    joinSucceeded = await viewModel.joinPartyByLink(value)
                    showResult = true
                }
            }
            .ignoresSafeArea()

            Text("Point your camera at a PLUR QR code")
                .font(.plurBodyBold(13))
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.xs)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 40)
        }
        .alert(joinSucceeded ? "Joined!" : "Not Found", isPresented: $showResult) {
            Button("OK") {
                if joinSucceeded { onDismiss() }
            }
        } message: {
            Text(joinSucceeded
                 ? "You've joined the party!"
                 : "The scanned code didn't match any party.")
        }
    }
}

// MARK: - Search Users

private struct SearchUsersSection: View {
    @Bindable var viewModel: PartyViewModel
    @State private var query = ""
    @State private var results: [AppUser] = []
    @State private var selectedPartyID: UUID?
    @State private var showInviteSent = false
    @State private var invitedUserName = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.plurFaint)
                TextField("Search by username or name", text: $query)
                    .font(.plurBody())
                    .foregroundStyle(Color.plurGhost)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.plurSurface2, in: RoundedRectangle(cornerRadius: Radius.thumbnail))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.thumbnail)
                    .stroke(Color.plurBorder, lineWidth: 1)
            )
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)

            if !viewModel.parties.isEmpty {
                HStack {
                    Text("Invite to:")
                        .font(.plurCaption())
                        .foregroundStyle(Color.plurMuted)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.xs) {
                            ForEach(viewModel.parties.filter { !$0.isPast }) { party in
                                Button {
                                    selectedPartyID = party.id
                                } label: {
                                    Text(party.name)
                                        .font(.plurMicro())
                                        .padding(.horizontal, Spacing.sm)
                                        .padding(.vertical, Spacing.xxs + 2)
                                        .background(
                                            selectedPartyID == party.id
                                                ? Color.plurViolet
                                                : Color.plurSurface2,
                                            in: Capsule()
                                        )
                                        .overlay(
                                            Capsule().stroke(
                                                selectedPartyID == party.id
                                                    ? Color.plurViolet
                                                    : Color.plurBorder,
                                                lineWidth: 1
                                            )
                                        )
                                        .foregroundStyle(
                                            selectedPartyID == party.id ? .white : Color.plurGhost
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
            }

            if query.isEmpty {
                VStack(spacing: Spacing.lg) {
                    Spacer().frame(height: 40)
                    Image(systemName: "person.crop.circle.badge.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.plurFaint)
                    Text("Find friends by username or name and invite them to your party.")
                        .font(.plurBody())
                        .foregroundStyle(Color.plurMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xxl)
                }
            } else if results.isEmpty {
                VStack(spacing: Spacing.md) {
                    Spacer().frame(height: 40)
                    Image(systemName: "person.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.plurFaint)
                    Text("No users matching \"\(query)\".")
                        .font(.plurBody())
                        .foregroundStyle(Color.plurMuted)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.xs) {
                        ForEach(results) { user in
                            HStack(spacing: Spacing.sm) {
                                Circle()
                                    .fill(Color.plurViolet.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Text(String(user.displayName.prefix(1)))
                                            .font(.plurBodyBold())
                                            .foregroundStyle(Color.plurViolet)
                                    }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.displayName)
                                        .font(.plurBodyBold(14))
                                        .foregroundStyle(Color.plurGhost)
                                    Text("@\(user.username)")
                                        .font(.plurCaption())
                                        .foregroundStyle(Color.plurMuted)
                                }
                                Spacer()
                                Button {
                                    guard let pid = selectedPartyID else { return }
                                    Task {
                                        await viewModel.inviteUser(user, to: pid)
                                        invitedUserName = user.displayName
                                        showInviteSent = true
                                    }
                                } label: {
                                    Text("Invite")
                                        .font(.plurMicro())
                                        .padding(.horizontal, Spacing.sm)
                                        .padding(.vertical, Spacing.xxs + 2)
                                        .foregroundStyle(.white)
                                        .background(Color.plurViolet, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .disabled(selectedPartyID == nil)
                                .opacity(selectedPartyID == nil ? 0.4 : 1)
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.xs)
                        }
                    }
                    .padding(.top, Spacing.sm)
                }
            }

            Spacer()
        }
        .task(id: query) {
            guard !query.isEmpty else {
                results = []
                return
            }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            results = await viewModel.searchUsers(query: query)
        }
        .onAppear {
            selectedPartyID = viewModel.parties.first(where: { !$0.isPast })?.id
            isSearchFocused = true
        }
        .alert("Invite Sent", isPresented: $showInviteSent) {
            Button("OK") {}
        } message: {
            Text("\(invitedUserName) has been invited to the party!")
        }
    }
}
