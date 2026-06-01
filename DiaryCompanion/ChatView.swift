import DiaryCompanionCore
import SwiftData
import SwiftUI

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MessageRecord.createdAt)
    private var messages: [MessageRecord]
    @Query(sort: \ReminderRecord.fireDate)
    private var reminders: [ReminderRecord]
    @State private var draft = ""
    @State private var isSending = false
    @State private var statusText: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollViewReader { proxy in
            Group {
                if visibleMessages.isEmpty {
                    ContentUnavailableView(
                        "开始对话",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("连接 AI Provider 后，通过自然语言记录生活。")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(visibleMessages) { message in
                                VStack(alignment: .leading, spacing: 9) {
                                    if !message.content.isEmpty {
                                        ChatBubble(message: message)
                                    }
                                    ForEach(reminders(for: message.id)) { reminder in
                                        ReminderProposalCard(reminder: reminder) { action in
                                            handle(action, for: reminder)
                                        }
                                    }
                                }
                                    .id(message.id)
                            }
                            if let statusText {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text(statusText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        scrollToLatest(using: proxy)
                    }
                }
            }
        }
        .navigationTitle("对话")
        .safeAreaInset(edge: .bottom) {
            composer
        }
        .alert(
            "发送失败",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("输入自然语言要求", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
                .disabled(isSending)

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(trimmedDraft.isEmpty || isSending)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var visibleMessages: [MessageRecord] {
        messages.filter { !$0.content.isEmpty }
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send() {
        let text = trimmedDraft
        guard !text.isEmpty, !isSending else {
            return
        }
        draft = ""
        Task {
            await streamReply(to: text)
        }
    }

    @MainActor
    private func streamReply(to text: String) async {
        isSending = true
        statusText = "正在连接 AI Provider"
        defer {
            isSending = false
            statusText = nil
        }

        do {
            let profileRepository = ProviderProfileRepository(context: modelContext)
            guard let profile = try profileRepository.fetchProfiles()
                .first(where: { $0.isEnabled && $0.supportsOpenAICompatibleStreaming })
            else {
                throw ChatViewError.noSupportedProvider
            }
            guard let apiKey = try profileRepository.loadAPIKey(profileID: profile.id),
                  !apiKey.isEmpty
            else {
                throw ChatViewError.missingAPIKey
            }

            let conversationRepository = ConversationRepository(context: modelContext)
            let conversation = try conversationRepository.defaultConversation()
            try conversationRepository.createMessage(
                conversationID: conversation.id,
                role: .user,
                content: text
            )
            let requestMessages = try chatMessages(
                from: conversationRepository.fetchMessages(conversationID: conversation.id)
            )
            let stream = try await ProviderStreamingClient().events(
                profile: profile,
                apiKey: apiKey,
                messages: requestMessages
            )
            var assistantMessageID: UUID?
            var reminderBuffer = ReminderProposalStreamBuffer()

            statusText = "正在生成回复"
            streamLoop:
            for try await event in stream {
                switch event {
                case let .textDelta(delta):
                    if assistantMessageID == nil {
                        assistantMessageID = try conversationRepository.createMessage(
                            conversationID: conversation.id,
                            role: .assistant,
                            content: ""
                        ).id
                    }
                    reminderBuffer.append(delta)
                    try conversationRepository.replaceContent(
                        reminderBuffer.visibleText,
                        of: assistantMessageID!
                    )
                case .reasoningDelta:
                    statusText = "正在思考"
                case .done:
                    break streamLoop
                }
            }
            reminderBuffer.finish()
            if let assistantMessageID {
                let parseResult = try ReminderProposalEnvelopeParser().parse(
                    reminderBuffer.rawText
                )
                try conversationRepository.replaceContent(
                    parseResult.visibleText,
                    of: assistantMessageID
                )
                if let proposal = parseResult.proposal {
                    let diaryRepository = DiaryRepository(context: modelContext)
                    if try diaryRepository.fetchReminders(
                        sourceMessageID: assistantMessageID
                    ).isEmpty {
                        try diaryRepository.createReminderProposal(
                            proposal,
                            sourceMessageID: assistantMessageID
                        )
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func chatMessages(from records: [MessageRecord]) throws -> [ChatMessage] {
        var result = [
            ChatMessage(
                role: .system,
                content: """
                你是一个简洁可靠的个人日记助手。请使用中文回答。
                \(ReminderAssistantPrompt.systemInstruction)
                """
            ),
        ]
        for record in records where !record.content.isEmpty {
            guard let role = ChatRole(rawValue: record.role) else {
                throw ChatViewError.invalidStoredRole(record.role)
            }
            result.append(ChatMessage(role: role, content: record.content))
        }
        return result
    }

    private func scrollToLatest(using proxy: ScrollViewProxy) {
        guard let id = visibleMessages.last?.id else {
            return
        }
        withAnimation {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }

    private func reminders(for messageID: UUID) -> [ReminderRecord] {
        reminders.filter { $0.sourceMessageID == messageID }
    }

    private func handle(_ action: ReminderCardAction, for reminder: ReminderRecord) {
        Task { @MainActor in
            do {
                let coordinator = ReminderSchedulingCoordinator(
                    repository: DiaryRepository(context: modelContext),
                    notificationClient: UserNotificationCenterClient(),
                    calendarClient: EventKitCalendarClient()
                )
                switch action {
                case .confirm:
                    try await coordinator.confirm(reminderID: reminder.id)
                case .cancel:
                    try coordinator.cancel(reminderID: reminder.id)
                case .recover:
                    try coordinator.recoverInterruptedExecution(reminderID: reminder.id)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct ChatBubble: View {
    let message: MessageRecord

    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 48)
            }
            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            if !isUser {
                Spacer(minLength: 48)
            }
        }
    }

    private var isUser: Bool {
        message.role == ChatRole.user.rawValue
    }
}

private enum ChatViewError: LocalizedError {
    case noSupportedProvider
    case missingAPIKey
    case invalidStoredRole(String)

    var errorDescription: String? {
        switch self {
        case .noSupportedProvider:
            "请先在设置中添加并启用 DeepSeek、硅基流动或 Custom Provider。"
        case .missingAPIKey:
            "当前 Provider 没有可用的 API Key，请在设置中重新保存。"
        case let .invalidStoredRole(role):
            "本地消息角色无效：\(role)"
        }
    }
}

private extension ProviderProfile {
    var supportsOpenAICompatibleStreaming: Bool {
        protocolKind == .openAI || protocolKind == .openAICompatible
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
    .modelContainer(for: DiarySchema.models, inMemory: true)
}
