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
    let label: String
    @Binding var amount: String
    var currencySymbol: String
    var clearAction: (() -> Void)? = nil
    
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
                
                TextField("0.00", text: $amount)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .onChange(of: amount) { 
                        amount = formatCurrencyInput(amount)
                    }
                
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
    
    /// Format the input to ensure it's a valid currency value
    private func formatCurrencyInput(_ input: String) -> String {
        // Remove any non-numeric characters except for a single decimal point
        var formattedInput = input.replacingOccurrences(of: ",", with: ".")
        
        // Allow only one decimal point
        let components = formattedInput.components(separatedBy: ".")
        if components.count > 2 {
            formattedInput = components[0] + "." + components[1]
        }
        
        // Limit to two decimal places
        if let decimalIndex = formattedInput.firstIndex(of: ".") {
            let decimalPosition = formattedInput.distance(from: formattedInput.startIndex, to: decimalIndex)
            let maxLength = decimalPosition + 3 // Allow up to 2 decimal places
            
            if formattedInput.count > maxLength {
                let endIndex = formattedInput.index(formattedInput.startIndex, offsetBy: maxLength)
                formattedInput = String(formattedInput[..<endIndex])
            }
        }
        
        return formattedInput
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
