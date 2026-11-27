//
//  IconUtils.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

/// Utility functions for working with category icons
enum IconUtils {
    /// Returns the system icon name for a given category
    static func iconName(for category: Category) -> String {
        category.defaultIconName
    }
    
    /// Returns a styled category icon view with appropriate color and shape
    static func styledIcon(for category: Category, size: CGFloat = 24, padding: CGFloat = 8) -> some View {
        CategoryArtwork(category: category, size: size, padding: padding)
    }
}

private struct CategoryArtwork: View {
    let category: Category
    let size: CGFloat
    let padding: CGFloat
    @ScaledMetric(relativeTo: .title2) private var scale = 1.0

    var body: some View {
        Image(systemName: category.defaultIconName)
            .font(Font.system(size: size * scale))
            .foregroundStyle(category.color.badgeForeground)
            .frame(width: (size + padding * 2) * scale, height: (size + padding * 2) * scale)
            .background(category.color, in: Circle())
            .accessibilityHidden(true)
    }
}

extension Color {
    /// Chooses the higher-contrast foreground for a solid badge color.
    var badgeForeground: Color {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: nil) else {
            return .primary
        }

        func linearize(_ component: CGFloat) -> CGFloat {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }

        let luminance = 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
        let contrastOnBlack = (luminance + 0.05) / 0.05
        let contrastOnWhite = 1.05 / (luminance + 0.05)
        return contrastOnBlack >= contrastOnWhite ? .black : .white
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
