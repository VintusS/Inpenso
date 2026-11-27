//
//  TransactionFiltersView.swift
//  iExpense
//

import SwiftUI

struct TransactionAmountBounds {
    var minimum: Double?
    var maximum: Double?

    var isActive: Bool { minimum != nil || maximum != nil }

    func contains(_ amount: Double) -> Bool {
        amount >= (minimum ?? -.infinity) && amount <= (maximum ?? .infinity)
    }
}

struct TransactionFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @Binding var selectedCategoryIDs: Set<String>
    @Binding var amountBounds: TransactionAmountBounds
    let categories: [FinanceCategory]
    let currencyCode: String

    @State private var tempSelectedCategoryIDs: Set<String>
    @State private var minimum = ""
    @State private var maximum = ""

    init(
        selectedCategoryIDs: Binding<Set<String>>,
        amountBounds: Binding<TransactionAmountBounds>,
        categories: [FinanceCategory],
        currencyCode: String
    ) {
        self._selectedCategoryIDs = selectedCategoryIDs
        self._amountBounds = amountBounds
        self.categories = categories
        self.currencyCode = currencyCode
        self._tempSelectedCategoryIDs = State(initialValue: selectedCategoryIDs.wrappedValue)
    }

    private var amountInput: AmountInput {
        AmountInput(fractionDigits: currencyFractionDigits(for: currencyCode), locale: locale)
    }

    private var parsedBounds: TransactionAmountBounds {
        TransactionAmountBounds(minimum: amountInput.value(of: minimum), maximum: amountInput.value(of: maximum))
    }

    private var amountError: String? {
        let bounds = parsedBounds
        if (!minimum.isEmpty && bounds.minimum == nil) || (!maximum.isEmpty && bounds.maximum == nil) {
            return "Enter a valid amount."
        }
        if let low = bounds.minimum, let high = bounds.maximum, low > high {
            return "The maximum must be at least the minimum."
        }
        return nil
    }

    private func amountField(_ label: String, text: Binding<String>) -> some View {
        LabeledContent(label) {
            AmountTextField(placeholder: "Any", raw: text, input: amountInput)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(label)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    amountField("Minimum", text: $minimum)
                    amountField("Maximum", text: $maximum)
                } header: {
                    Text("Amount (\(currencyCode))")
                } footer: {
                    if let amountError {
                        Text(amountError).foregroundStyle(.red)
                    } else {
                        Text("Leave either amount blank for no limit.")
                    }
                }

                Section {
                    ForEach(categories) { category in
                        Button {
                            if tempSelectedCategoryIDs.contains(category.id) {
                                if tempSelectedCategoryIDs.count > 1 {
                                    tempSelectedCategoryIDs.remove(category.id)
                                }
                            } else {
                                tempSelectedCategoryIDs.insert(category.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: category.iconName)
                                    .foregroundStyle(category.color.badgeForeground)
                                    .font(.caption)
                                    .frame(width: 28, height: 28)
                                    .background(category.color)
                                    .clipShape(Circle())
                                    .accessibilityHidden(true)

                                Text(category.displayName)
                                    .font(.body)

                                Spacer()

                                if tempSelectedCategoryIDs.contains(category.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(tempSelectedCategoryIDs.contains(category.id) ? .isSelected : [])
                    }
                } header: {
                    Text("Categories")
                } footer: {
                    Text("Select which categories to display")
                }
            }
            .onAppear {
                minimum = amountBounds.minimum.map(amountInput.bindingText) ?? ""
                maximum = amountBounds.maximum.map(amountInput.bindingText) ?? ""
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        selectedCategoryIDs = tempSelectedCategoryIDs
                        amountBounds = parsedBounds
                        dismiss()
                    }
                    .disabled(amountError != nil)
                }
            }
        }
    }
}
