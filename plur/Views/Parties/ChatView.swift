import SwiftUI

struct ChatView: View {
    let party: RaveGroup
    let partyVM: PartyViewModel
    @Bindable var chatVM: ChatViewModel
    @State private var draft = ""
    @State private var isSending = false
    @State private var showSendError = false
    @State private var sendErrorMessage = ""
    @FocusState private var isInputFocused: Bool

    private var allMessages: [Message] {
        chatVM.messages[party.id] ?? []
    }

    private var pinnedMessages: [Message] {
        allMessages.filter(\.isPinned)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !pinnedMessages.isEmpty {
                pinnedBanner
            }

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(allMessages) { message in
                        MessageBubble(
                            message: message,
                            currentUserId: partyVM.currentUserId
                        ) {
                            Task {
                                await chatVM.togglePin(messageID: message.id, in: party.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.xxs)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)

            inputBar
        }
        .background(Color.plurVoid)
        .task {
            await chatVM.loadMessages(for: party.id)
            await chatVM.observeMessages(for: party.id)
        }
        .onChange(of: chatVM.chatError) { _, newValue in
            guard let newValue, !newValue.isEmpty else { return }
            sendErrorMessage = newValue
            showSendError = true
        }
        .alert("Couldn't send message", isPresented: $showSendError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sendErrorMessage)
        }
    }

    // MARK: - Pinned Banner

    private var pinnedBanner: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            ForEach(pinnedMessages) { msg in
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.plurAmber)
                    Text("\(msg.senderName): \(msg.content)")
                        .font(.plurCaption(15))
                        .foregroundStyle(Color.plurGhost)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
        .background(Color.plurAmber.opacity(0.08))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.plurBorder)
                .frame(height: 1)
        }
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Message…", text: $draft)
                .font(.plurBody(18))
                .foregroundStyle(Color.plurGhost)
                .textFieldStyle(.plain)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(Color.plurSurface2)
                        .overlay(
                            Capsule().stroke(Color.plurBorder, lineWidth: 1)
                        )
                )
                .focused($isInputFocused)

            Button {
                let content = draft
                isSending = true
                Task {
                    let ok = await chatVM.sendMessage(
                        content: content,
                        in: party.id,
                        userId: partyVM.currentUserId ?? UUID(),
                        displayName: partyVM.currentUserDisplayName
                    )
                    if ok { draft = "" }
                    isSending = false
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.plurViolet)
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
            .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
        .background(
            Rectangle()
                .fill(Color.plurSurface)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.plurBorder)
                        .frame(height: 1)
                }
        )
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: Message
    let currentUserId: UUID?
    let onTogglePin: () -> Void

    private var isOwnMessage: Bool {
        guard let currentUserId else { return false }
        return message.userId == currentUserId
    }

    var body: some View {
        HStack {
            if isOwnMessage { Spacer(minLength: 48) }

            VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 3) {
                if !isOwnMessage {
                    Text(message.senderName)
                        .font(.plurCaption())
                        .foregroundStyle(Color.plurMuted)
                }

                Text(message.content)
                    .font(.plurBody(18))
                    .foregroundStyle(Color.plurGhost)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        isOwnMessage
                            ? Color.plurViolet.opacity(0.2)
                            : Color.plurSurface2,
                        in: RoundedRectangle(cornerRadius: Radius.innerCard)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.innerCard)
                            .stroke(
                                isOwnMessage
                                    ? Color.plurViolet.opacity(0.15)
                                    : Color.plurBorder,
                                lineWidth: 1
                            )
                    )
                    .contextMenu {
                        Button {
                            onTogglePin()
                        } label: {
                            Label(
                                message.isPinned ? "Unpin" : "Pin to Board",
                                systemImage: message.isPinned ? "pin.slash" : "pin"
                            )
                        }
                    }

                HStack(spacing: Spacing.xxs) {
                    if message.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.plurAmber)
                    }
                    Text(message.timeText)
                        .font(.plurMicro())
                        .foregroundStyle(Color.plurFaint)
                }
            }

            if !isOwnMessage { Spacer(minLength: 48) }
        }
        .padding(.vertical, 3)
    }
}
