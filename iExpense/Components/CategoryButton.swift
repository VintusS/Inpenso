//
//  CategoryButton.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

struct CategoryButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let category: FinanceCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Icon with circle background
                ZStack {
                    // Base shape
                    Circle()
                        .fill(category.color)
                        .frame(width: 56, height: 56)
                    
                    // Icon
                    Image(systemName: category.iconName)
                        .font(.title2)
                        .foregroundStyle(category.color.badgeForeground)
                    
                    // Selection indicator
                    if isSelected {
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 3)
                            .frame(width: 56, height: 56)
                    }
                }
                .accessibilityHidden(true)
                .shadow(color: isSelected ? category.color.opacity(0.6) : Color.clear, radius: isSelected ? 5 : 0)
                
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 32)
            }
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 80)
            .scaleEffect(isSelected && !reduceMotion ? 1.05 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    HStack(spacing: 20) {
        CategoryButton(
            category: FinanceCategory.builtIn(for: .food),
            isSelected: true,
            action: {}
        )
        CategoryButton(
            category: FinanceCategory.builtIn(for: .transportation),
            isSelected: false,
            action: {}
        )
    }
    .padding()
} 
