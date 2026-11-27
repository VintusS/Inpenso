//
//  InstalmentFields.swift
//  iExpense
//

import SwiftUI

/// What the user chose for an instalment purchase on a credit wallet.
struct InstalmentChoice: Equatable {
    var isOn = false
    var months = 12
    var monthlyFeeText = ""
    var payFromWalletID: UUID?
}

/// Add Expense block shown under the wallet field when the wallet is a credit card or paylater account.
struct InstalmentFields: View {
    static let presets = [3, 6, 12]

    @Binding var choice: InstalmentChoice
    let principal: Double?
    let input: AmountInput
    let currency: String
    let payFromWallets: [Wallet]

    @State private var usesCustomMonths = false

    private var monthlyFee: Double { input.value(of: choice.monthlyFeeText) ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $choice.isOn.animation(.snappy)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pay in instalments")
                        .font(.subheadline.weight(.medium))
                    Text("The full amount counts as spending today.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if choice.isOn {
                monthsControl
                feeField
                payFromField
                summary
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(10)
        .onAppear {
            usesCustomMonths = !Self.presets.contains(choice.months)
        }
    }

    private var monthsControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Months", selection: Binding(
                get: { usesCustomMonths ? 0 : choice.months },
                set: { value in
                    if value == 0 {
                        usesCustomMonths = true
                    } else {
                        usesCustomMonths = false
                        choice.months = value
                    }
                }
            )) {
                ForEach(Self.presets, id: \.self) { Text("\($0) mo").tag($0) }
                Text("Other").tag(0)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Number of months")

            if usesCustomMonths {
                Stepper(value: $choice.months, in: 1...60) {
                    Text("\(choice.months) months")
                        .font(.subheadline)
                        .monospacedDigit()
                }
            }
        }
    }

    private var feeField: some View {
        HStack {
            Text("Monthly fee or interest")
                .font(.subheadline)
            AmountTextField(placeholder: "None", raw: $choice.monthlyFeeText, input: input)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity)
        }
        .frame(minHeight: 44)
    }

    private var payFromField: some View {
        HStack {
            Text("Pay from")
                .font(.subheadline)
            Spacer()
            Picker("Pay from", selection: $choice.payFromWalletID) {
                Text("Decide each month").tag(UUID?.none)
                ForEach(payFromWallets) { wallet in
                    Label(wallet.name, systemImage: wallet.iconName).tag(Optional(wallet.id))
                }
            }
            .labelsHidden()
        }
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private var summary: some View {
        if let principal, principal > 0, choice.months > 0 {
            let monthly = principal / Double(choice.months)
            let perMonth = (monthly + monthlyFee).formatted(.currency(code: currency))
            let line = monthlyFee > 0
                ? "\(perMonth) a month for \(choice.months) months, including a \(monthlyFee.formatted(.currency(code: currency))) fee."
                : "\(perMonth) a month for \(choice.months) months."
            Text(line)
                .font(.footnote.weight(.medium))
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("Enter the amount to see the monthly payment.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}
