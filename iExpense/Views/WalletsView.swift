//
//  WalletsView.swift
//  iExpense
//

import SwiftUI

struct WalletIcon: View {
    let wallet: Wallet
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: wallet.iconName)
            .font(.subheadline)
            .foregroundStyle(wallet.color.badgeForeground)
            .frame(width: size, height: size)
            .background(wallet.color)
            .cornerRadius(size * 0.22)
            .opacity(wallet.isArchived ? 0.5 : 1)
    }
}

/// Menu picker over active wallets (plus `including`, so an archived wallet on an old entry still shows).
struct WalletPicker: View {
    let title: String
    @Binding var selection: UUID?
    let wallets: [Wallet]
    var including: UUID?

    var body: some View {
        let visible = wallets.filter { !$0.isArchived || $0.id == including }
        let credit = visible.filter(\.kind.isCredit)
        Picker(title, selection: $selection) {
            ForEach(visible.filter { !$0.kind.isCredit }) { wallet in
                Label(wallet.name, systemImage: wallet.iconName).tag(Optional(wallet.id))
            }
            if !credit.isEmpty {
                Section("Credit") {
                    ForEach(credit) { wallet in
                        Label(wallet.name, systemImage: wallet.iconName).tag(Optional(wallet.id))
                    }
                }
            }
        }
    }
}

/// A caption over an amount, used for Assets / Owed and the credit detail figures.
struct FigureLabel: View {
    let title: String
    let amount: Double
    let currency: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(amount, format: .currency(code: currency))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(tint)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct WalletsView: View {
    @ObservedObject var walletsViewModel: WalletsViewModel
    @ObservedObject var expenseViewModel: ExpenseViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @State private var editingWallet: Wallet?
    @State private var showingTransfer = false
    @State private var showArchived = false

    private var currency: String { settingsViewModel.selectedCurrency }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    totalsHeader
                        .padding(.vertical, 6)

                    Button {
                        showingTransfer = true
                    } label: {
                        Label("Transfer Between Wallets", systemImage: "arrow.left.arrow.right")
                    }
                    .disabled(walletsViewModel.activeWallets.count < 2)
                } footer: {
                    if walletsViewModel.activeWallets.count < 2 {
                        Text("Add a second wallet to move money between them.")
                    }
                }

                Section("Wallets") {
                    ForEach(walletsViewModel.activeWallets.filter { !$0.kind.isCredit }) { wallet in
                        walletLink(wallet)
                    }
                }

                let creditWallets = walletsViewModel.activeWallets.filter(\.kind.isCredit)
                if !creditWallets.isEmpty {
                    Section {
                        ForEach(creditWallets) { wallet in
                            walletLink(wallet)
                        }
                    } header: {
                        Text("Credit")
                    } footer: {
                        Text("Cards and paylater. Purchases count as spending; paying the bill is a transfer.")
                    }
                }

                if !walletsViewModel.archivedWallets.isEmpty {
                    Section {
                        DisclosureGroup("Archived (\(walletsViewModel.archivedWallets.count))", isExpanded: $showArchived) {
                            ForEach(walletsViewModel.archivedWallets) { wallet in
                                walletLink(wallet)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Wallets")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editingWallet = Wallet(
                            name: "",
                            kind: .bank,
                            iconName: WalletKind.bank.defaultIconName,
                            colorHex: WalletEditor.palette[walletsViewModel.wallets.count % WalletEditor.palette.count],
                            openingDate: Calendar.current.startOfDay(for: Date()),
                            sortOrder: (walletsViewModel.wallets.map(\.sortOrder).max() ?? 0) + 1
                        )
                    } label: {
                        Label("Add Wallet", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editingWallet) { wallet in
                WalletEditor(
                    wallet: wallet,
                    isNew: !walletsViewModel.wallets.contains { $0.id == wallet.id },
                    onSave: { try walletsViewModel.save($0) }
                )
            }
            .sheet(isPresented: $showingTransfer) {
                TransferSheet(walletsViewModel: walletsViewModel, transfer: nil)
            }
        }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var hasCreditWallets: Bool { walletsViewModel.wallets.contains { $0.kind.isCredit } }

    /// Without credit wallets the header stays a single total; with them it splits into Net, Assets and Owed.
    @ViewBuilder
    private var totalsHeader: some View {
        if hasCreditWallets {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(walletsViewModel.netTotal, format: .currency(code: currency))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundColor(walletsViewModel.netTotal < 0 ? .red : .primary)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(spacing: 16))
                layout {
                    FigureLabel(title: "Assets", amount: walletsViewModel.assetsTotal, currency: currency)
                    FigureLabel(title: "Owed", amount: walletsViewModel.owedTotal, currency: currency,
                                tint: walletsViewModel.owedTotal > 0 ? .red : .primary)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Balance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(walletsViewModel.totalBalance, format: .currency(code: currency))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundColor(walletsViewModel.totalBalance < 0 ? .red : .primary)
            }
        }
    }

    @ViewBuilder
    private func trailingAmount(_ wallet: Wallet) -> some View {
        if wallet.kind.isCredit {
            let owed = walletsViewModel.owed(for: wallet)
            let overLimit = walletsViewModel.isOverLimit(wallet)
            VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                Text(owed, format: .currency(code: currency))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(overLimit ? .red : .primary)
                    .monospacedDigit()
                Group {
                    if overLimit {
                        Text("Over limit")
                    } else if let available = walletsViewModel.available(for: wallet) {
                        Text("\(available.formatted(.currency(code: currency))) available")
                    } else {
                        Text("Owed")
                    }
                }
                .font(.caption)
                .foregroundColor(overLimit ? .red : .secondary)
            }
        } else {
            let balance = walletsViewModel.balance(of: wallet)
            Text(balance, format: .currency(code: currency))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(balance < 0 ? .red : .primary)
        }
    }

    private func walletLink(_ wallet: Wallet) -> some View {
        NavigationLink {
            WalletDetailView(walletID: wallet.id, walletsViewModel: walletsViewModel, expenseViewModel: expenseViewModel)
        } label: {
            let rowLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 12))
            let nameLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 6))
            rowLayout {
                WalletIcon(wallet: wallet, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    nameLayout {
                        Text(wallet.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if wallet.id == walletsViewModel.defaultWalletID {
                            Text("Default")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        }
                    }
                    Text(wallet.kind.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                trailingAmount(wallet)
            }
        }
    }
}

struct WalletEditor: View {
    static let palette = ["#0A84FF", "#30B0C7", "#34C759", "#FF9F0A", "#FF375F", "#AF52DE", "#8E8E93", "#5856D6"]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @State private var wallet: Wallet
    @State private var openingText: String = ""
    @State private var limitText: String = ""
    @State private var errorMessage: String?
    let isNew: Bool
    let onSave: (Wallet) throws -> Void

    init(wallet: Wallet, isNew: Bool, onSave: @escaping (Wallet) throws -> Void) {
        _wallet = State(initialValue: wallet)
        self.isNew = isNew
        self.onSave = onSave
    }

    private var input: AmountInput {
        AmountInput(fractionDigits: currencyFractionDigits(for: settingsViewModel.selectedCurrency), locale: locale)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        WalletIcon(wallet: wallet, size: 40)
                        TextField("Name, e.g. Savings or Travel Card", text: $wallet.name)
                    }
                    Picker("Type", selection: $wallet.kind) {
                        ForEach(WalletKind.allCases) { kind in
                            Label(kind.displayName, systemImage: kind.defaultIconName).tag(kind)
                        }
                    }
                    .onChange(of: wallet.kind) { oldKind, newKind in
                        if wallet.iconName == oldKind.defaultIconName {
                            wallet.iconName = newKind.defaultIconName
                        }
                    }
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                        ForEach(Self.palette, id: \.self) { hex in
                            Button {
                                wallet.colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex) ?? .gray)
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().strokeBorder(Color.primary, lineWidth: wallet.colorHex == hex ? 2 : 0))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color \(hex)")
                            .accessibilityAddTraits(wallet.colorHex == hex ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                if wallet.kind.isCredit {
                    Section {
                        HStack {
                            Text("Credit limit")
                            AmountTextField(placeholder: "None", raw: $limitText, input: input)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity)
                        }
                        dayPicker("Statement day", selection: $wallet.statementDay)
                        dayPicker("Due day", selection: $wallet.dueDay)
                    } header: {
                        Text("Credit")
                    } footer: {
                        Text("All optional. The limit shows what's still available; the due day puts the bill on Home a week ahead.")
                    }
                }

                Section {
                    HStack {
                        Text(wallet.kind.isCredit ? "Owed at start" : "Starting balance")
                        AmountTextField(placeholder: input.placeholder, raw: $openingText, input: input)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity)
                    }
                    if let openingDate = wallet.openingDate {
                        DatePicker("As of", selection: Binding(get: { openingDate }, set: { wallet.openingDate = $0 }), displayedComponents: .date)
                    }
                } footer: {
                    if wallet.kind.isCredit {
                        Text("What you owed on this card or paylater account at the start of that day, as a positive amount.")
                    } else {
                        Text(wallet.openingDate == nil
                             ? "The amount in this wallet before your first recorded transaction."
                             : "What this wallet held at the start of that day. Entries from then on change the balance.")
                    }
                }
            }
            .navigationTitle(isNew ? "New Wallet" : "Edit Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(wallet.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Wallet", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                if openingText.isEmpty && wallet.openingBalance != 0 {
                    // Credit wallets store debt as a negative balance but ask for it as a positive amount.
                    openingText = input.bindingText(for: wallet.kind.isCredit ? -wallet.openingBalance : wallet.openingBalance)
                }
                if limitText.isEmpty, let limit = wallet.creditLimit {
                    limitText = input.bindingText(for: limit)
                }
            }
        }
    }

    private func dayPicker(_ title: String, selection: Binding<Int?>) -> some View {
        Picker(title, selection: selection) {
            Text("None").tag(Int?.none)
            ForEach(1...31, id: \.self) { day in
                Text("\(day)").tag(Optional(day))
            }
        }
    }

    private func save() {
        var saved = wallet
        saved.name = saved.name.trimmingCharacters(in: .whitespaces)
        let opening = input.value(of: openingText) ?? 0
        if saved.kind.isCredit {
            saved.openingBalance = -abs(opening)
            saved.creditLimit = input.value(of: limitText).flatMap { $0 > 0 ? $0 : nil }
        } else {
            saved.openingBalance = opening
            saved.creditLimit = nil
            saved.statementDay = nil
            saved.dueDay = nil
        }
        do {
            try onSave(saved)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't save the wallet."
        }
    }
}

/// Wallet selector styled like the other form fields in Add/Edit.
struct WalletFormField: View {
    @Binding var selection: UUID?
    let wallets: [Wallet]
    var including: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wallet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack {
                WalletPicker(title: "Wallet", selection: $selection, wallets: wallets, including: including)
                    .labelsHidden()
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(10)
        }
    }
}
