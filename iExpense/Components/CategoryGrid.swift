//
//  CategoryGrid.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

struct CategoryGrid: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedCategoryID: String
    let categories: [FinanceCategory]
    var onCategorySelected: (() -> Void)?
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 2 : 3)
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 15) {
            ForEach(categories) { category in
                CategoryButton(
                    category: category,
                    isSelected: selectedCategoryID == category.id,
                    action: {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategoryID = category.id
                        }
                        HapticFeedback.impact()
                        onCategorySelected?()
                    }
                )
            }
        }
        .padding(.vertical, 10)
    }
}

// An alternative version with a manual callback for cases where binding isn't appropriate
struct CategoryGridWithCallback: View {
    let selectedCategoryID: String
    let categories: [FinanceCategory]
    let onCategorySelected: (FinanceCategory) -> Void
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 2 : 3)
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 15) {
            ForEach(categories) { category in
                CategoryButton(
                    category: category,
                    isSelected: selectedCategoryID == category.id,
                    action: {
                        HapticFeedback.impact()
                        onCategorySelected(category)
                    }
                )
            }
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    VStack {
        Text("Category Grid Preview")
            .font(.headline)
            .padding()
        
        CategoryGrid(
            selectedCategoryID: .constant(Category.food.categoryID),
            categories: FinanceCategory.builtInCategories
        )
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding()
    }
} 
