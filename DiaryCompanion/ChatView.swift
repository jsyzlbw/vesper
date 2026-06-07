import DiaryCompanionCore
import SwiftData
import SwiftUI
import UIKit

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.vesperLocalization) private var localization
    @Query(sort: \MessageRecord.createdAt)
    private var messages: [MessageRecord]
    @Query(sort: \ConversationRecord.createdAt, order: .reverse)
    private var conversations: [ConversationRecord]
    @Query(sort: \ReminderRecord.fireDate)
    private var reminders: [ReminderRecord]
    @State private var draft = ""
    @State private var selectedConversationID: UUID?
    @State private var isSending = false
    @State private var statusText: String?
    @State private var errorMessage: String?
    @State private var editorPresentation: ReminderEditorPresentation?
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            Group {
                if selectedConversationMessages.isEmpty {
                    ContentUnavailableView(
                        localization.strings.startConversation,
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text(emptyConversationDescription)
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(selectedConversationMessages) { message in
                                VStack(alignment: .leading, spacing: 9) {
                                    if !message.content.isEmpty {
                                        ChatBubble(message: message)
                                    }
                                    ForEach(reminders(for: message.id)) { reminder in
                                        ReminderProposalCard(
                                            reminder: reminder,
                                            proposal: reminderProposal(for: reminder)
                                        ) { action in
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
                    .scrollDismissesKeyboard(.interactively)
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            isComposerFocused = false
                        }
                    )
                    .onChange(of: selectedConversationMessages.count) {
                        scrollToLatest(using: proxy)
                    }
                }
            }
        }
        .navigationTitle(selectedConversationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                conversationMenu
            }
        }
        .task {
            ensureCurrentDailyConversation()
        }
        .safeAreaInset(edge: .bottom) {
            composer
        }
        .alert(
            localization.strings.sendFailed,
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(localization.strings.ok, role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(item: $editorPresentation) { presentation in
            ReminderProposalEditorView(
                originalProposal: presentation.proposal
            ) { proposal in
                try await saveEditedProposal(
                    proposal,
                    reminderID: presentation.reminderID
                )
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(localization.strings.naturalLanguagePlaceholder, text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .focused($isComposerFocused)
                .disabled(isSending)
                .padding(.vertical, 9)

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(trimmedDraft.isEmpty || isSending ? Color.secondary : Color.accentColor)
                    .clipShape(Circle())
            }
            .disabled(trimmedDraft.isEmpty || isSending)
            .padding(.bottom, 1)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.07), radius: 12, y: 5)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.bar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(localization.strings.dismissKeyboard) {
                    isComposerFocused = false
                }
            }
        }
    }

    private var selectedConversationMessages: [MessageRecord] {
        guard let selectedConversationID else {
            return []
        }
        return messages.filter {
            $0.conversationID == selectedConversationID && !$0.content.isEmpty
        }
    }

    private var selectedConversation: ConversationRecord? {
        guard let selectedConversationID else {
            return nil
        }
        return conversations.first { $0.id == selectedConversationID }
    }

    private var selectedConversationTitle: String {
        selectedConversation.map(conversationTitle) ?? localization.strings.chat
    }

    private var emptyConversationDescription: String {
        if let selectedConversation {
            localization.strings.emptyConversationDescription(
                conversationTitle(selectedConversation)
            )
        } else {
            localization.strings.startConversationDescription
        }
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var conversationMenu: some View {
        Menu {
            Button {
                ensureCurrentDailyConversation(forceSelect: true)
            } label: {
                Label(localization.strings.todayConversation, systemImage: "sun.max")
            }

            if !conversations.isEmpty {
                Divider()
            }

            ForEach(conversations) { conversation in
                Button {
                    selectedConversationID = conversation.id
                } label: {
                    if selectedConversationID == conversation.id {
                        Label(conversationTitle(conversation), systemImage: "checkmark")
                    } else {
                        Text(conversationTitle(conversation))
                    }
                }
            }
        } label: {
            Label(localization.strings.conversationHistory, systemImage: "calendar")
        }
        .disabled(isSending)
    }

    private func send() {
        let text = trimmedDraft
        guard !text.isEmpty, !isSending else {
            return
        }
        draft = ""
        isComposerFocused = false
        Task {
            await streamReply(to: text)
        }
    }

    @MainActor
    private func streamReply(to text: String) async {
        isSending = true
        statusText = localization.strings.connectingProvider
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
            let conversation = try activeConversation(repository: conversationRepository)
            try conversationRepository.createMessage(
                conversationID: conversation.id,
                role: .user,
                content: text
            )
            let requestMessages = try chatMessages(
                from: conversationRepository.fetchMessages(conversationID: conversation.id)
            )
            let assistantMessageID = try conversationRepository.createMessage(
                conversationID: conversation.id,
                role: .assistant,
                content: ""
            ).id
            let initialReply = try await streamedReply(
                profile: profile,
                apiKey: apiKey,
                messages: requestMessages,
                assistantMessageID: assistantMessageID,
                repository: conversationRepository
            )
            let parseResult = try await resolvedReminderReply(
                initialReply: initialReply,
                latestUserText: text,
                requestMessages: requestMessages,
                profile: profile,
                apiKey: apiKey,
                assistantMessageID: assistantMessageID,
                repository: conversationRepository
            )
            try conversationRepository.replaceContent(
                parseResult.visibleText,
                of: assistantMessageID
            )
            if !parseResult.proposals.isEmpty {
                let diaryRepository = DiaryRepository(context: modelContext)
                if try diaryRepository.fetchReminders(
                    sourceMessageID: assistantMessageID
                ).isEmpty {
                    let calendarClient = EventKitCalendarClient()
                    let autoSchedulingService = ReminderAutoSchedulingService(
                        calendarClient: calendarClient
                    )
                    for proposal in parseResult.proposals {
                        let reminder = try diaryRepository.createReminderProposal(
                            proposal,
                            sourceMessageID: assistantMessageID
                        )
                        let resolvedProposal = try await autoSchedulingService.resolve(proposal)
                        if resolvedProposal != proposal {
                            try diaryRepository.updateReminderProposal(
                                id: reminder.id,
                                proposal: resolvedProposal
                            )
                        }
                    }
                }
            }
        } catch {
            errorMessage = localizedMessage(for: error)
        }
    }

    @MainActor
    private func streamedReply(
        profile: ProviderProfile,
        apiKey: String,
        messages: [ChatMessage],
        assistantMessageID: UUID,
        repository: ConversationRepository
    ) async throws -> String {
        try repository.replaceContent("", of: assistantMessageID)
        let stream = try await ProviderStreamingClient().events(
            profile: profile,
            apiKey: apiKey,
            messages: messages
        )
        var reminderBuffer = ReminderProposalStreamBuffer()

        statusText = localization.strings.generatingReply
        streamLoop:
        for try await event in stream {
            switch event {
            case let .textDelta(delta):
                reminderBuffer.append(delta)
                try repository.replaceContent(
                    reminderBuffer.visibleText,
                    of: assistantMessageID
                )
            case .reasoningDelta:
                statusText = localization.strings.thinking
            case .done:
                break streamLoop
            }
        }
        reminderBuffer.finish()
        return reminderBuffer.rawText
    }

    @MainActor
    private func resolvedReminderReply(
        initialReply: String,
        latestUserText: String,
        requestMessages: [ChatMessage],
        profile: ProviderProfile,
        apiKey: String,
        assistantMessageID: UUID,
        repository: ConversationRepository
    ) async throws -> ReminderProposalParseResult {
        let policy = ReminderResponseRepairPolicy()
        let initialResult: ReminderProposalParseResult?
        let repairError: Error?

        do {
            initialResult = try parseValidatedReminderReply(initialReply)
            repairError = nil
        } catch {
            initialResult = nil
            repairError = error
        }

        let shouldRepair = repairError != nil || policy.shouldRequestStructuredProposal(
            latestUserText: latestUserText,
            assistantText: initialResult?.visibleText ?? initialReply,
            hasProposal: !(initialResult?.proposals.isEmpty ?? true)
        )
        guard shouldRepair else {
            return initialResult!
        }

        let repairedReply = try await streamedReply(
            profile: profile,
            apiKey: apiKey,
            messages: requestMessages + [
                ChatMessage(role: .assistant, content: initialReply),
                ChatMessage(
                    role: .user,
                    content: policy.correctionPrompt(previousError: repairError)
                ),
            ],
            assistantMessageID: assistantMessageID,
            repository: repository
        )
        guard let repairedResult = try? parseValidatedReminderReply(repairedReply) else {
            return ReminderProposalParseResult(
                visibleText: policy.safeFallback(language: localization.language),
                proposal: nil
            )
        }
        guard !policy.shouldRequestStructuredProposal(
            latestUserText: latestUserText,
            assistantText: repairedResult.visibleText,
            hasProposal: !repairedResult.proposals.isEmpty
        ) else {
            return ReminderProposalParseResult(
                visibleText: policy.safeFallback(language: localization.language),
                proposal: nil
            )
        }
        return repairedResult
    }

    private func parseValidatedReminderReply(
        _ rawText: String
    ) throws -> ReminderProposalParseResult {
        let result = try ReminderProposalEnvelopeParser().parse(rawText)
        for proposal in result.proposals {
            try proposal.validateForCreation(referenceDate: Date())
        }
        return result
    }

    private func chatMessages(from records: [MessageRecord]) throws -> [ChatMessage] {
        let diaryRepository = DiaryRepository(context: modelContext)
        let routineNotes = (try? diaryRepository
            .journalSettings().personalRoutineNotes) ?? ""
        var result = [
            ChatMessage(
                role: .system,
                content: """
                You are Vesper, a concise and reliable private assistant.
                \(VesperAIReplyLanguage.instruction(
                    appLanguage: localization.language,
                    latestUserText: records.last(
                        where: { $0.role == ChatRole.user.rawValue }
                    )?.content ?? ""
                ))
                \(ReminderAssistantPrompt.systemInstruction(
                    now: Date(),
                    timeZone: .current
                ))
                \(ReminderAssistantPrompt.personalRoutineInstruction(routineNotes))
                \(localContextInstruction(repository: diaryRepository))
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

    private func localContextInstruction(repository: DiaryRepository) -> String {
        let calendarSnapshots = ((try? repository.fetchCalendarEventSnapshots()) ?? [])
            .map {
                VesperCalendarEventSnapshot(
                    title: $0.title,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    calendarTitle: $0.calendarTitle,
                    isAllDay: $0.isAllDay
                )
            }
        let healthSnapshots = ((try? repository.fetchHealthDailySummaries()) ?? [])
            .map {
                VesperHealthSummarySnapshot(
                    date: $0.date,
                    stepCount: $0.stepCount,
                    activeEnergyKilocalories: $0.activeEnergyKilocalories,
                    exerciseMinutes: $0.exerciseMinutes,
                    sleepMinutes: $0.sleepMinutes,
                    sleepInBedMinutes: $0.sleepInBedMinutes,
                    sourceDescription: $0.sourceDescription
                )
            }
        return VesperLocalContextPrompt.instruction(
            calendarSnapshots: calendarSnapshots,
            healthSnapshots: healthSnapshots,
            now: Date(),
            timeZone: .current,
            localeIdentifier: localization.locale.identifier
        )
    }

    private func scrollToLatest(using proxy: ScrollViewProxy) {
        guard let id = selectedConversationMessages.last?.id else {
            return
        }
        withAnimation {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }

    private func reminders(for messageID: UUID) -> [ReminderRecord] {
        reminders
            .filter { $0.sourceMessageID == messageID }
            .sorted { reminderDate($0) < reminderDate($1) }
    }

    private func reminderDate(_ reminder: ReminderRecord) -> Date {
        reminder.fireDate
    }

    private func ensureCurrentDailyConversation(forceSelect: Bool = false) {
        do {
            let conversation = try ConversationRepository(context: modelContext)
                .dailyConversation()
            if forceSelect || selectedConversationID == nil {
                selectedConversationID = conversation.id
            }
        } catch {
            errorMessage = localizedMessage(for: error)
        }
    }

    private func activeConversation(
        repository: ConversationRepository
    ) throws -> ConversationRecord {
        if let selectedConversationID,
           let selectedConversation = conversations.first(where: { $0.id == selectedConversationID }) {
            return selectedConversation
        }
        let conversation = try repository.dailyConversation()
        selectedConversationID = conversation.id
        return conversation
    }

    private func conversationTitle(_ conversation: ConversationRecord) -> String {
        if let logicalDay = conversation.logicalDay {
            return logicalDay.formatted(
                Date.FormatStyle(date: .abbreviated, time: .omitted)
                    .locale(localization.locale)
            )
        }
        return conversation.title
    }

    private func reminderProposal(for reminder: ReminderRecord) -> ReminderProposal? {
        try? DiaryRepository(context: modelContext).reminderProposal(from: reminder)
    }

    private func handle(_ action: ReminderCardAction, for reminder: ReminderRecord) {
        Task { @MainActor in
            do {
                let coordinator = ReminderSchedulingCoordinator(
                    repository: DiaryRepository(context: modelContext),
                    notificationClient: UserNotificationCenterClient(),
                    alarmClient: makeAlarmClient(),
                    calendarClient: EventKitCalendarClient()
                )
                switch action {
                case .edit:
                    editorPresentation = ReminderEditorPresentation(
                        reminderID: reminder.id,
                        proposal: try DiaryRepository(context: modelContext)
                            .reminderProposal(from: reminder)
                    )
                case .confirm:
                    try await coordinator.confirm(reminderID: reminder.id)
                    try await ReminderNotificationReplenisher(
                        repository: DiaryRepository(context: modelContext),
                        notificationClient: UserNotificationCenterClient()
                    ).replenish()
                    try await ReminderAlarmReplenisher(
                        repository: DiaryRepository(context: modelContext),
                        alarmClient: makeAlarmClient()
                    ).replenish()
                case .cancel:
                    try coordinator.cancel(reminderID: reminder.id)
                case .recover:
                    if reminder.status == ReminderProposalStatus.cancelled.rawValue {
                        try DiaryRepository(context: modelContext)
                            .restoreCancelledReminderProposal(id: reminder.id)
                    } else {
                        try coordinator.recoverInterruptedExecution(reminderID: reminder.id)
                    }
                }
            } catch {
                errorMessage = localizedMessage(for: error)
            }
        }
    }

    @MainActor
    private func saveEditedProposal(
        _ proposal: ReminderProposal,
        reminderID: UUID
    ) async throws {
        let calendarClient = EventKitCalendarClient()
        let resolvedProposal = try await ReminderAutoSchedulingService(
            calendarClient: calendarClient
        ).resolve(proposal)
        try ReminderSchedulingCoordinator(
            repository: DiaryRepository(context: modelContext),
            notificationClient: UserNotificationCenterClient(),
            alarmClient: makeAlarmClient(),
            calendarClient: calendarClient
        ).edit(reminderID: reminderID, proposal: resolvedProposal)
    }

    private func localizedMessage(for error: Error) -> String {
        if let error = error as? ReminderProposalValidationError {
            return error.localizedDescription(language: localization.language)
        }
        if let error = error as? ReminderAutoSchedulingError {
            return error.localizedDescription(language: localization.language)
        }
        if let error = error as? ProviderStreamError {
            return error.localizedDescription(language: localization.language)
        }
        if let error = error as? AlarmClientError {
            return error.localizedDescription(language: localization.language)
        }
        guard let error = error as? ChatViewError else {
            return error.localizedDescription
        }
        return switch error {
        case .noSupportedProvider:
            localization.strings.noSupportedProvider
        case .missingAPIKey:
            localization.strings.missingAPIKey
        case let .invalidStoredRole(role):
            localization.strings.invalidStoredRole(role)
        }
    }
}

private struct ReminderEditorPresentation: Identifiable {
    let reminderID: UUID
    let proposal: ReminderProposal

    var id: UUID {
        reminderID
    }
}

private struct ChatBubble: View {
    @Environment(\.vesperLocalization) private var localization
    let message: MessageRecord

    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 48)
            }
            Text(message.content)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .contextMenu {
                    Button(localization.strings.copy) {
                        UIPasteboard.general.string = message.content
                    }
                }
            if !isUser {
                Spacer(minLength: 48)
            }
        }
    }

    private var isUser: Bool {
        message.role == ChatRole.user.rawValue
    }
}

private enum ChatViewError: Error {
    case noSupportedProvider
    case missingAPIKey
    case invalidStoredRole(String)
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
