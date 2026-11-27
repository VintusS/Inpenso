//
//  FormFields.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

/// Standard text input field with consistent styling
struct TextFormField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var leadingIcon: String? = nil
    var trailingIcon: String? = nil
    var trailingAction: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Field label
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Input field
            HStack(alignment: .center) {
                if let iconName = leadingIcon {
                    Image(systemName: iconName)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                }
                
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                
                if let iconName = trailingIcon {
                    Button(action: {
                        trailingAction?()
                    }) {
                        Image(systemName: iconName)
                            .foregroundColor(.secondary)
                    }
                    .disabled(trailingAction == nil)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(10)
        }
    }
}

/// Currency input field with formatting
struct CurrencyFormField: View {
    @Environment(\.locale) private var locale
    let label: String
    @Binding var amount: String
    var currencySymbol: String
    var fractionDigits: Int = 2
    var clearAction: (() -> Void)? = nil

    private var input: AmountInput {
        AmountInput(fractionDigits: fractionDigits, locale: locale)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Field label
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Currency input field
            HStack(alignment: .center) {
                Text(currencySymbol)
                    .foregroundColor(.secondary)
                    .font(.title3)
                    .fontWeight(.medium)
                
                AmountTextField(placeholder: input.placeholder, raw: $amount, input: input)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.leading)

                Spacer()
                
                // Clear button
                if !amount.isEmpty {
                    Button(action: {
                        if let clearAction = clearAction {
                            clearAction()
                        } else {
                            amount = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(10)
        }
    }
}

/// Text field for money amounts. `raw` holds ungrouped text with "." as the decimal mark;
/// the field shows it grouped for the locale (e.g. "125.000") and regroups as the user types.
///
/// SwiftUI does not push a computed binding's reformatted value back into a field that is
/// being edited, so the shown text lives in local state and is rewritten after each change.
struct AmountTextField: View {
    let placeholder: String
    @Binding var raw: String
    let input: AmountInput
    @State private var shown = ""

    var body: some View {
        TextField(placeholder, text: $shown)
            .keyboardType(input.fractionDigits == 0 ? .numberPad : .decimalPad)
            .onAppear { shown = input.display(raw) }
            .onChange(of: shown) { oldValue, newValue in
                let updated = input.updating(raw, with: newValue)
                if updated != raw { raw = updated }
                let formatted = input.display(updated)
                if formatted != newValue { shown = formatted }
            }
            .onChange(of: raw) { _, newValue in
                // External changes, e.g. the clear button or a reset.
                let formatted = input.display(newValue)
                if formatted != shown { shown = formatted }
            }
    }
}

#Preview {
    VStack(spacing: 24) {
        TextFormField(
            label: "Title",
            text: .constant("Groceries"),
            placeholder: "Enter title",
            leadingIcon: "pencil"
        )
        
        TextFormField(
            label: "Notes",
            text: .constant("Weekly shopping"),
            placeholder: "Add notes",
            trailingIcon: "xmark.circle.fill",
            trailingAction: {}
        )
        
        CurrencyFormField(
            label: "Amount",
            amount: .constant("123.45"),
            currencySymbol: "$"
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
} 
