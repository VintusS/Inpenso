//
//  CategoryManagementTile.swift
//  iExpense
//

import SwiftUI

struct CategoryManagementTile: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let category: FinanceCategory
    let isTargeted: Bool
    let isHidden: Bool
    let canReset: Bool
    let onEdit: () -> Void
    let onHide: () -> Void
    let onRestore: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(category.color)
                    .frame(width: 56, height: 56)

                Image(systemName: category.iconName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(category.color.badgeForeground)
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)

                menu
                    .offset(x: 10, y: -10)
            }

            Text(category.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isHidden ? .secondary : .primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 32)

            if isHidden {
                Button(action: onRestore) {
                    Label("Restore", systemImage: "eye")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.borderless)
            } else {
                Image(systemName: "line.3.horizontal")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 124)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .opacity(isHidden ? 0.65 : 1)
        .scaleEffect(isTargeted && !reduceMotion ? 1.03 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture(perform: onEdit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(category.displayName)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onEdit() }
        .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.85), value: isTargeted)
    }

    private var menu: some View {
        Menu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }

            if isHidden {
                Button(action: onRestore) {
                    Label("Restore", systemImage: "eye")
                }
            } else {
                Button(role: .destructive, action: onHide) {
                    Label("Remove", systemImage: "eye.slash")
                }
            }

            if canReset {
                Divider()

                Button(role: .destructive, action: onReset) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.headline.weight(.semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.secondary, Color(.systemBackground))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More Options for \(category.displayName)")
    }
}

struct CategoryDragPreview: View {
    let category: FinanceCategory

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(category.color)
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: category.iconName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(category.color.badgeForeground)
                }

            Text(category.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }
}
