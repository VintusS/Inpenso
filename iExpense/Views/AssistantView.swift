//
//  AssistantView.swift
//  iExpense
//
//  On-device finance assistant powered by Apple Intelligence (FoundationModels).
//  The model runs entirely on the chip - no data ever leaves the device.
//

import SwiftUI
import FoundationModels

// MARK: - Chat message model

struct AssistantMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let text: String

    enum Role: Equatable {
        case user
        case assistant
    }
}

// MARK: - Assistant view

@available(iOS 26.0, *)
struct AssistantView: View {
    @ObservedObject var viewModel: ExpenseViewModel

    @State private var messages: [AssistantMessage] = []
    @State private var inputText = ""
    @State private var isResponding = false
    @State private var streamedText = ""
    @State private var respondTask: Task<Void, Never>?
    @State private var session: LanguageModelSession?
    @State private var sessionData: [Expense]?

    private let model = SystemLanguageModel.default

    private let suggestionPrompts = [
        String(localized: "How much did I spend this month?"),
        String(localized: "What's my biggest expense category?"),
        String(localized: "Am I on track with my budget?"),
        String(localized: "Give me 3 tips to save money")
    ]

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isModelAvailable {
                    chatList
                    if messages.isEmpty && !isResponding {
                        suggestionsSection
                    }
                    inputBar
                } else {
                    unavailableView
                }
            }
            .navigationTitle("Assistant")
            .toolbar {
                if isModelAvailable && !messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            startNewChat()
                        } label: {
                            Label("New Chat", systemImage: "square.and.pencil")
                        }
                    }
                }
            }
        }
        .onAppear {
            if session == nil {
                _ = currentSession()
            }
        }
    }

    // MARK: - Model availability

    private var isModelAvailable: Bool {
        if case .available = model.availability {
            return true
        }
        return false
    }

    private var unavailableMessage: String {
        guard case .unavailable(let reason) = model.availability else {
            return String(localized: "Apple Intelligence is not available right now.")
        }
        switch reason {
        case .deviceNotEligible:
            return String(localized: "This device doesn't support Apple Intelligence.")
        case .appleIntelligenceNotEnabled:
            return String(localized: "Turn on Apple Intelligence in Settings → Apple Intelligence & Siri, then come back.")
        case .modelNotReady:
            return String(localized: "The on-device model is still preparing. Try again in a few minutes.")
        default:
            return String(localized: "Apple Intelligence is not available right now.")
        }
    }

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 52))
                .foregroundColor(.secondary)
            Text("Apple Intelligence Required")
                .font(.title3.bold())
            Text(unavailableMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Chat list

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        messageBubble(role: message.role, text: message.text)
                    }

                    if !streamedText.isEmpty {
                        messageBubble(role: .assistant, text: streamedText)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("chatBottom")
                }
                .padding()
            }
            .onChange(of: messages.count) {
                proxy.scrollTo("chatBottom", anchor: .bottom)
            }
            .onChange(of: streamedText) {
                proxy.scrollTo("chatBottom", anchor: .bottom)
            }
        }
    }

    private func messageBubble(role: AssistantMessage.Role, text: String) -> some View {
        HStack {
            if role == .user {
                Spacer(minLength: 48)
            }

            VStack(alignment: role == .user ? .trailing : .leading, spacing: 4) {
                Text(text)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        role == .user
                            ? Color.accentColor.opacity(0.85)
                            : Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .foregroundColor(role == .user ? .white : .primary)
            }

            if role == .assistant {
                Spacer(minLength: 48)
            }
        }
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                Text("Ask about your money")
                    .font(.headline)
            }

            Text("Powered by Apple Intelligence — the model runs 100% on your iPhone and your financial data never leaves the device.")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160), spacing: 10)],
                spacing: 10
            ) {
                ForEach(suggestionPrompts, id: \.self) { prompt in
                    Button {
                        inputText = prompt
                        send()
                    } label: {
                        Text(prompt)
                            .font(.footnote)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(
                                Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask about your finances…", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)

            if isResponding {
                Button {
                    respondTask?.cancel()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            } else {
                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(
                            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? .secondary
                                : .accentColor
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private func send() {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isResponding else { return }

        messages.append(AssistantMessage(role: .user, text: prompt))
        inputText = ""
        isResponding = true
        streamedText = ""

        let session = currentSession()

        respondTask = Task { @MainActor in
            do {
                for try await partial in session.streamResponse(to: prompt) {
                    streamedText = partial.content
                }
                if !streamedText.isEmpty {
                    messages.append(AssistantMessage(role: .assistant, text: streamedText))
                }
            } catch is CancellationError {
                if !streamedText.isEmpty {
                    messages.append(AssistantMessage(role: .assistant, text: streamedText))
                }
            } catch {
                messages.append(
                    AssistantMessage(
                        role: .assistant,
                        text: "⚠️ Something went wrong: \(error.localizedDescription)"
                    )
                )
            }
            streamedText = ""
            isResponding = false
        }
    }

    private func startNewChat() {
        respondTask?.cancel()
        session = nil
        sessionData = nil
        messages = []
        streamedText = ""
        isResponding = false
    }

    /// Returns the existing session, recreating it when the underlying
    /// financial data has changed so the model always sees fresh numbers.
    private func currentSession() -> LanguageModelSession {
        let currentData = viewModel.expenses
        if let session, sessionData == currentData {
            return session
        }
        let newSession = LanguageModelSession(instructions: systemInstructions())
        session = newSession
        sessionData = currentData
        return newSession
    }

    // MARK: - Financial context

    private func systemInstructions() -> String {
        """
        You are Inpenso's personal finance assistant. You help the user understand \
        and manage their money based strictly on the transaction data provided below.

        Rules:
        - Answer ONLY using the financial data below. Never invent numbers, \
        transactions, or categories that are not in the data.
        - Be concise and friendly: 2 to 5 sentences by default, bullet points for lists.
        - When you state amounts, make the currency clear.
        - If the data doesn't contain the answer (for example a question about a \
        period with no transactions), say clearly that there is no data for it.
        - Always respond in the same language the user writes in.
        - You may give general financial advice when asked, but keep it practical \
        and tie it back to the user's own numbers whenever possible.

        FINANCIAL DATA
        ----------------
        \(financialContext())
        """
    }

    private func financialContext() -> String {
        let calendar = Calendar.current
        let now = Date()
        let expenses = viewModel.expenses
        let currency = SettingsViewModel.getAppCurrency()

        let nowMonth = calendar.component(.month, from: now)
        let nowYear = calendar.component(.year, from: now)

        let monthTransactions = expenses.filter {
            calendar.component(.month, from: $0.date) == nowMonth
                && calendar.component(.year, from: $0.date) == nowYear
        }
        let monthExpenses = monthTransactions.filter { $0.type == .expense }
        let monthIncome = monthTransactions.filter { $0.type == .income }

        let totalSpent = monthExpenses.reduce(0) { $0 + $1.price }
        let totalIncome = monthIncome.reduce(0) { $0 + $1.price }

        let budgetKey = String(format: "%02d-%d", nowMonth, nowYear)
        let budget = StorageService.loadBudgets()[budgetKey] ?? 0

        let byCategory = Dictionary(grouping: monthExpenses, by: { $0.categoryID })
        let categoryTotals = byCategory
            .map { (name: categoryName($0.key), total: $0.value.reduce(0) { $0 + $1.price }) }
            .sorted { $0.total > $1.total }

        let recent = expenses.sorted { $0.date > $1.date }.prefix(15)

        func money(_ value: Double) -> String {
            value.formatted(.currency(code: currency))
        }

        var lines: [String] = []
        lines.append("Current date: \(now.formatted(.dateTime.year().month().day()))")
        lines.append("Currency: \(currency)")
        lines.append("Month: \(now.formatted(.dateTime.month(.wide).year()))")
        lines.append("Total spent this month: \(money(totalSpent))")
        lines.append("Total income this month: \(money(totalIncome))")
        lines.append("Net cashflow this month: \(money(totalIncome - totalSpent))")

        if budget > 0 {
            lines.append(
                "Monthly budget: \(money(budget)) — spent \(money(totalSpent)), remaining \(money(budget - totalSpent))"
            )
        } else {
            lines.append("Monthly budget: not set")
        }

        lines.append("Transactions this month: \(monthTransactions.count)")

        if !categoryTotals.isEmpty {
            lines.append("Spending by category this month:")
            for category in categoryTotals.prefix(8) {
                lines.append("- \(category.name): \(money(category.total))")
            }
        }

        if !recent.isEmpty {
            lines.append("Most recent transactions (newest first):")
            for expense in recent {
                let kind = expense.type == .income ? "Income" : "Expense"
                lines.append(
                    "- \(expense.date.formatted(.dateTime.month().day())) | \(kind) | \(expense.title) | \(money(expense.price)) | category: \(categoryName(expense.categoryID))"
                )
            }
        }

        if expenses.isEmpty {
            lines.append("(The user has no transactions recorded yet.)")
        }

        return lines.joined(separator: "\n")
    }

    private func categoryName(_ id: String) -> String {
        Category.category(from: id)?.displayName ?? id
    }
}

// MARK: - Preview

#Preview {
    if #available(iOS 26.0, *) {
        AssistantView(viewModel: ExpenseViewModel())
    }
}
