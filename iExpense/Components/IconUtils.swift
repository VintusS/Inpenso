import SwiftUI

/// Utility functions for working with category icons
enum IconUtils {
    /// Returns the system icon name for a given category
    static func iconName(for category: Category) -> String {
        switch category {
        case .food:
            return "cart.fill"
        case .eatingOut:
            return "fork.knife"
        case .rent:
            return "house.fill"
        case .shopping:
            return "bag.fill"
        case .entertainment:
            return "tv.fill"
        case .transportation:
            return "car.fill"
        case .utilities:
            return "bolt.fill"
        case .subscriptions:
            return "repeat"
        case .healthcare:
            return "heart.fill"
        case .education:
            return "book.fill"
        case .others:
            return "ellipsis"
        }
    }
    
    /// Returns a styled category icon view with appropriate color and shape
    static func styledIcon(for category: Category, size: CGFloat = 24, padding: CGFloat = 8) -> some View {
        ZStack {
            Circle()
                .fill(category.color)
                .frame(width: size + padding * 2, height: size + padding * 2)
            
            Image(systemName: iconName(for: category))
                .font(.system(size: size))
                .foregroundColor(.white)
        }
    }
}

// Extension to use the icon methods directly on Category
extension Category {
    var iconName: String {
        IconUtils.iconName(for: self)
    }
    
    func styledIcon(size: CGFloat = 24, padding: CGFloat = 8) -> some View {
        IconUtils.styledIcon(for: self, size: size, padding: padding)
    }
} 