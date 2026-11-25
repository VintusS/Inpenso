//
//  AccountsView.swift
//  iExpense
//
//  List of bank accounts / cards with available balance,
//  cut dates and payment dates.
//

import SwiftUI

struct AccountsView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @ObservedObject var expenseViewModel: ExpenseViewModel

    @State private var accounts: [Account] = []
    @State private var showingNewAccount = false
    @State private var editingAccount: Account?

    private var currencyCode: String {
        settingsViewModel.selectedCurrency
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if accounts.isEmpty {
                        emptyState
                            .padding(.top, 40)
                    } else {
                        ForEach(accounts) { account in
                            accountCard(account)
                                .onTapGesture {
                                    editingAccount = account
                                }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewAccount = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("New")
                                .font(.callout)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                }
            }
            .sheet(isPresented: $showingNewAccount) {
                AccountFormView(account: nil) {
                    reloadAccounts()
                }
            }
            .sheet(item: $editingAccount) { account in
                AccountFormView(account: account) {
                    reloadAccounts()
                }
            }
            .onAppear {
                reloadAccounts()
            }
        }
    }

    private func reloadAccounts() {
        accounts = AccountStorage.load()
    }

    // MARK: - Account card

    private func accountCard(_ account: Account) -> some View {
        let expenses = expenseViewModel.expenses
        let consumed = account.consumed(expenses: expenses)
        let available = account.availableBalance(expenses: expenses)
        let balance = account.currentBalance(expenses: expenses)
        let days = account.daysUntilPayment()

        return VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(account.type.tint.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: account.type.iconName)
                        .font(.title3)
                        .foregroundColor(account.type.tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.headline)
                    Text(account.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(account.type.displayName)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(account.type.tint.opacity(0.15), in: Capsule())
                    .foregroundColor(account.type.tint)
            }

            // Balance
            VStack(alignment: .leading, spacing: 4) {
                if account.type == .credit {
                    Text("Available Balance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(available, format: .currency(code: currencyCode))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(available < 0 ? .red : .primary)
                } else {
                    Text("Current Balance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(balance, format: .currency(code: currencyCode))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                }
            }

            // Consumption progress (credit only)
            if account.type == .credit {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(
                        value: min(consumed, max(account.creditLimit, 1)),
                        total: max(account.creditLimit, 1)
                    )
                    .tint(consumed > account.creditLimit ? .red : account.type.tint)

                    HStack {
                        HStack(spacing: 4) {
                            Text("Consumed")
                            Text(consumed, format: .currency(code: currencyCode))
                                .fontWeight(.semibold)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Text("Limit")
                            Text(account.creditLimit, format: .currency(code: currencyCode))
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            Divider()

            // Dates (credit only)
            if account.type == .credit {
                HStack(alignment: .top) {
                    dateColumn(title: "Cut Day", value: "\(account.cutDay)")
                    Spacer()
                    dateColumn(
                        title: "Next Cut",
                        value: account.nextCut().formatted(.dateTime.month().day())
                    )
                    Spacer()
                    dateColumn(
                        title: "Payment Date",
                        value: account.nextPaymentDate().formatted(.dateTime.month().day())
                    )
                }

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    if days > 0 {
                        Text("Due in \(days) days")
                    } else {
                        Text("Payment due today")
                    }
                    Spacer()
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(days <= 1 ? .orange : .secondary)
            }
        }
        .padding()
        .background(
            Color(.systemBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private func dateColumn(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.callout.bold())
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 52))
                .foregroundColor(.secondary)

            Text("No accounts yet")
                .font(.headline)

            Text("Add your first account to track balances, cut dates, and payments.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showingNewAccount = true
            } label: {
                Text("New Account")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    AccountsView(expenseViewModel: ExpenseViewModel())
        .environmentObject(SettingsViewModel())
}
