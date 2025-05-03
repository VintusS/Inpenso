import SwiftUI

struct CategoryGrid: View {
    @Binding var selectedCategory: Category
    var onCategorySelected: (() -> Void)? = nil
    
    // Number of columns in the grid
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 15) {
            ForEach(Category.allCases, id: \.self) { category in
                CategoryButton(
                    category: category,
                    isSelected: selectedCategory == category,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = category
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
    let selectedCategory: Category
    let onCategorySelected: (Category) -> Void
    
    // Number of columns in the grid
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 15) {
            ForEach(Category.allCases, id: \.self) { category in
                CategoryButton(
                    category: category,
                    isSelected: selectedCategory == category,
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
        
        CategoryGrid(selectedCategory: .constant(.food))
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding()
    }
} 