import SwiftUI

struct CategoryButton: View {
    let category: Category
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
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                    
                    // Selection indicator
                    if isSelected {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 56, height: 56)
                    }
                }
                .shadow(color: isSelected ? category.color.opacity(0.6) : Color.clear, radius: isSelected ? 5 : 0)
                
                // Category name in fixed-height container
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                    .frame(height: 32)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 80)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    HStack(spacing: 20) {
        CategoryButton(
            category: .food,
            isSelected: true,
            action: {}
        )
        CategoryButton(
            category: .transportation,
            isSelected: false,
            action: {}
        )
    }
    .padding()
} 
