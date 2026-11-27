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
            .font(.system(size: size * 0.5))
            .foregroundColor(.white)
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
        Picker(title, selection: $selection) {
            ForEach(wallets.filter { !$0.isArchived || $0.id == including }) { wallet in
                Label(wallet.name, systemImage: wallet.iconName).tag(Optional(wallet.id))
            }
        }
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
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Balance")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(walletsViewModel.totalBalance, format: .currency(code: currency))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(walletsViewModel.totalBalance < 0 ? .red : .primary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
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
                    ForEach(walletsViewModel.activeWallets) { wallet in
                        walletLink(wallet)
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

    private func walletLink(_ wallet: Wallet) -> some View {
        NavigationLink {
            WalletDetailView(walletID: wallet.id, walletsViewModel: walletsViewModel, expenseViewModel: expenseViewModel)
        } label: {
            HStack(spacing: 12) {
                WalletIcon(wallet: wallet, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
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
                Spacer()
                let balance = walletsViewModel.balance(of: wallet)
                Text(balance, format: .currency(code: currency))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(balance < 0 ? .red : .primary)
            }
        }
    }
}

struct WalletDetailView: View {
    let walletID: UUID
    @ObservedObject var walletsViewModel: WalletsViewModel
    @ObservedObject var expenseViewModel: ExpenseViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @State private var editingWallet: Wallet?
    @State private var editingTransfer: Transfer?
    @State private var showingTransfer = false
    @State private var errorMessage: String?

    private var currency: String { settingsViewModel.selectedCurrency }

    var body: some View {
        Group {
            if let wallet = walletsViewModel.wallet(for: walletID) {
                content(wallet)
            } else {
                Text("This wallet no longer exists.")
                    .foregroundColor(.secondary)
            }
        }
        .alert("Wallet", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func content(_ wallet: Wallet) -> some View {
        let activity = walletsViewModel.activity(for: wallet, expenses: expenseViewModel.expenses)
        let balance = walletsViewModel.balance(of: wallet)
        return List {
            Section {
                HStack(spacing: 14) {
                    WalletIcon(wallet: wallet, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Balance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(balance, format: .currency(code: currency))
                            .font(.title2.bold())
                            .foregroundColor(balance < 0 ? .red : .primary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 4)
                if balance < 0 {
                    Label("This wallet is below zero. Check for a missing income or transfer.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                if !wallet.isArchived {
                    Button {
                        showingTransfer = true
                    } label: {
                        Label("Transfer", systemImage: "arrow.left.arrow.right")
                    }
                    .disabled(walletsViewModel.activeWallets.count < 2)
                }
            }

            Section("History") {
                if activity.isEmpty && wallet.openingBalance == 0 {
                    Text("No activity yet")
                        .foregroundColor(.secondary)
                }
                ForEach(activity) { item in
                    activityRow(item)
                }
                if wallet.openingBalance != 0 {
                    HStack {
                        Label("Opening balance", systemImage: "flag")
                            .font(.subheadline)
                        Spacer()
                        Text(wallet.openingBalance, format: .currency(code: currency))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section {
                if wallet.id != walletsViewModel.defaultWalletID && !wallet.isArchived {
                    Button("Make Default Wallet") {
                        run { try walletsViewModel.makeDefault(wallet) }
                    }
                }
                if wallet.isArchived {
                    Button("Unarchive") {
                        run { try walletsViewModel.unarchive(wallet) }
                    }
                } else {
                    Button("Archive Wallet", role: .destructive) {
                        run { try walletsViewModel.archive(wallet) }
                    }
                }
            } footer: {
                Text(wallet.isArchived
                     ? "Archived wallets keep their history and balance but can't be picked for new entries."
                     : "Archiving hides the wallet from pickers. Its history and balance stay.")
            }
        }
        .navigationTitle(wallet.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { editingWallet = wallet }
            }
        }
        .sheet(item: $editingWallet) { wallet in
            WalletEditor(wallet: wallet, isNew: false, onSave: { try walletsViewModel.save($0) })
        }
        .sheet(isPresented: $showingTransfer) {
            TransferSheet(walletsViewModel: walletsViewModel, transfer: nil, fromWalletID: wallet.id)
        }
        .sheet(item: $editingTransfer) { transfer in
            TransferSheet(walletsViewModel: walletsViewModel, transfer: transfer)
        }
    }

    @ViewBuilder
    private func activityRow(_ item: WalletActivity) -> some View {
        switch item.kind {
        case .transaction(let expense):
            let category = categoryStore.category(for: expense)
            row(
                icon: Image(systemName: category.iconName), color: category.color,
                title: expense.title,
                subtitle: walletsViewModel.isFee(expense) ? "Transfer fee" : category.displayName,
                date: item.date, amount: item.signedAmount
            )
        case .transferOut(let transfer, let to):
            Button { editingTransfer = transfer } label: {
                row(icon: Image(systemName: "arrow.up.right"), color: .gray,
                    title: "To \(to?.name ?? "deleted wallet")", subtitle: transfer.note ?? "Transfer",
                    date: item.date, amount: item.signedAmount)
            }
        case .transferIn(let transfer, let from):
            Button { editingTransfer = transfer } label: {
                row(icon: Image(systemName: "arrow.down.left"), color: .gray,
                    title: "From \(from?.name ?? "deleted wallet")", subtitle: transfer.note ?? "Transfer",
                    date: item.date, amount: item.signedAmount)
            }
        }
    }

    private func row(icon: Image, color: Color, title: String, subtitle: String, date: Date, amount: Double) -> some View {
        HStack(spacing: 12) {
            icon
                .font(.system(size: 13))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(color)
                .cornerRadius(6)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                HStack(spacing: 4) {
                    Text(date, style: .date)
                    Text("·")
                    Text(subtitle)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
            Spacer()
            Text((amount > 0 ? "+" : "") + amount.formatted(.currency(code: currency)))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(amount > 0 ? .green : .primary)
        }
    }

    private func run(_ action: () throws -> Void) {
        do { try action() } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
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
        NavigationView {
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
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(Self.palette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .gray)
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(Color.primary, lineWidth: wallet.colorHex == hex ? 2 : 0).padding(-3))
                                .onTapGesture { wallet.colorHex = hex }
                                .accessibilityLabel("Color \(hex)")
                                .accessibilityAddTraits(wallet.colorHex == hex ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    HStack {
                        Text("Starting balance")
                        AmountTextField(placeholder: input.placeholder, raw: $openingText, input: input)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity)
                    }
                    if let openingDate = wallet.openingDate {
                        DatePicker("As of", selection: Binding(get: { openingDate }, set: { wallet.openingDate = $0 }), displayedComponents: .date)
                    }
                } footer: {
                    Text(wallet.openingDate == nil
                         ? "The amount in this wallet before your first recorded transaction."
                         : "What this wallet held at the start of that day. Entries from then on change the balance.")
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
                    openingText = input.bindingText(for: wallet.openingBalance)
                }
            }
        }
    }

    private func save() {
        var saved = wallet
        saved.name = saved.name.trimmingCharacters(in: .whitespaces)
        saved.openingBalance = input.value(of: openingText) ?? 0
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
