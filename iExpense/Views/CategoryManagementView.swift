//
//  CategoryManagementView.swift
//  iExpense
//

import SwiftUI
import UniformTypeIdentifiers

struct CategoryManagementView: View {
    @EnvironmentObject private var categoryStore: CategoryStore
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @State private var categoryToEdit: FinanceCategory?
    @State private var showingEditor = false
    @State private var targetedCategoryID: String?
    @State private var draggedCategoryID: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                categorySection(title: "Visible", categories: categoryStore.visibleCategories, isHiddenSection: false)

                if !categoryStore.hiddenCategories.isEmpty {
                    categorySection(title: "Hidden", categories: categoryStore.hiddenCategories, isHiddenSection: true)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    categoryToEdit = nil
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            CategoryEditorView(category: categoryToEdit)
                .environmentObject(categoryStore)
                .environmentObject(settingsViewModel)
        }
    }

    private func categorySection(title: String, categories: [FinanceCategory], isHiddenSection: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(categories) { category in
                    if isHiddenSection {
                        managementTile(for: category, isHiddenSection: true)
                    } else {
                        managementTile(for: category, isHiddenSection: false)
                            .onDrag {
                                draggedCategoryID = category.id
                                return NSItemProvider(object: category.id as NSString)
                            } preview: {
                                CategoryDragPreview(category: category)
                            }
                            .onDrop(
                                of: [UTType.text],
                                delegate: CategoryReorderDropDelegate(
                                    destinationCategoryID: category.id,
                                    draggedCategoryID: $draggedCategoryID,
                                    targetedCategoryID: $targetedCategoryID,
                                    moveCategory: { sourceID, destinationID in
                                        categoryStore.moveCategory(sourceID, to: destinationID)
                                    },
                                    clearDragState: {
                                        clearDragState()
                                    }
                                )
                            )
                            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: categoryStore.visibleCategories.map(\.id))
                            .onDisappear {
                                if draggedCategoryID == category.id {
                                    clearDragState()
                                } else {
                                    targetedCategoryID = nil
                                }
                            }
                    }
                }
            }
        }
    }

    private func managementTile(for category: FinanceCategory, isHiddenSection: Bool) -> CategoryManagementTile {
        CategoryManagementTile(
            category: category,
            isTargeted: draggedCategoryID != nil && targetedCategoryID == category.id,
            isHidden: isHiddenSection,
            canReset: !category.isCustom && categoryStore.hasBuiltInOverride(for: category.id),
            onEdit: {
                edit(category)
            },
            onHide: {
                hide(category)
            },
            onRestore: {
                restore(category)
            },
            onReset: {
                categoryStore.resetBuiltInOverride(for: category.id)
            }
        )
    }

    private func edit(_ category: FinanceCategory) {
        categoryToEdit = category
        showingEditor = true
    }

    private func hide(_ category: FinanceCategory) {
        categoryStore.hideCategory(category)
        normalizeDefaultCategory()
    }

    private func restore(_ category: FinanceCategory) {
        categoryStore.restoreCategory(category)
    }

    private func normalizeDefaultCategory() {
        let preferredCategoryID = categoryStore.preferredCategoryID(for: settingsViewModel.defaultCategoryID)
        if preferredCategoryID != settingsViewModel.defaultCategoryID {
            settingsViewModel.defaultCategoryID = preferredCategoryID
        }
    }

    private func clearDragState() {
        draggedCategoryID = nil
        targetedCategoryID = nil
    }
}

private struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var categoryStore: CategoryStore
    @EnvironmentObject private var settingsViewModel: SettingsViewModel

    let category: FinanceCategory?

    @State private var name: String
    @State private var iconName: String
    @State private var colorHex: String
    @State private var showingValidation = false

    private let icons = [
        "tag.fill", "briefcase.fill", "banknote.fill", "creditcard.fill",
        "gift.fill", "cart.fill", "fork.knife", "house.fill",
        "car.fill", "tram.fill", "airplane", "heart.fill",
        "cross.case.fill", "book.fill", "graduationcap.fill", "gamecontroller.fill",
        "music.note", "pawprint.fill", "leaf.fill", "hammer.fill"
    ]

    private let colors = [
        "#007AFF", "#34C759", "#FF9500", "#FF3B30",
        "#AF52DE", "#FF2D55", "#5856D6", "#00C7BE",
        "#30B0C7", "#FFCC00", "#8E8E93", "#A2845E"
    ]

    init(category: FinanceCategory?) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _iconName = State(initialValue: category?.iconName ?? "tag.fill")
        _colorHex = State(initialValue: category?.colorHex ?? "#007AFF")
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                iconName = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(iconName == icon ? .white : .primary)
                                    .frame(width: 44, height: 44)
                                    .background(iconName == icon ? Color.accentColor : Color(.tertiarySystemBackground))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Button {
                                colorHex = color
                            } label: {
                                Circle()
                                    .fill(Color(hex: color) ?? .gray)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if colorHex == color {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                if let category {
                    Section("Actions") {
                        if categoryStore.isHidden(category.id) {
                            Button {
                                categoryStore.restoreCategory(category)
                                dismiss()
                            } label: {
                                Label("Restore Category", systemImage: "eye")
                            }
                        } else {
                            Button(role: .destructive) {
                                categoryStore.hideCategory(category)
                                normalizeDefaultCategory()
                                dismiss()
                            } label: {
                                Label("Remove from Pickers", systemImage: "eye.slash")
                            }
                        }

                        if !category.isCustom && categoryStore.hasBuiltInOverride(for: category.id) {
                            Button(role: .destructive) {
                                categoryStore.resetBuiltInOverride(for: category.id)
                                dismiss()
                            } label: {
                                Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                            }
                        }
                    }
                }
            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        save()
                    }
                }
            }
            .alert("Category name is required", isPresented: $showingValidation) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showingValidation = true
            return
        }

        if var category {
            category.name = trimmedName
            category.iconName = iconName
            category.colorHex = colorHex
            categoryStore.updateCategory(category)
        } else {
            categoryStore.addCategory(name: trimmedName, iconName: iconName, colorHex: colorHex)
        }

        dismiss()
    }

    private func normalizeDefaultCategory() {
        let preferredCategoryID = categoryStore.preferredCategoryID(for: settingsViewModel.defaultCategoryID)
        if preferredCategoryID != settingsViewModel.defaultCategoryID {
            settingsViewModel.defaultCategoryID = preferredCategoryID
        }
    }
}

private struct CategoryManagementTile: View {
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
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)

                menu
                    .offset(x: 10, y: -10)
            }

            Text(category.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isHidden ? .secondary : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(height: 32)

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
        .scaleEffect(isTargeted ? 1.03 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture(perform: onEdit)
        .animation(.spring(response: 0.22, dampingFraction: 0.85), value: isTargeted)
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
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.secondary, Color(.systemBackground))
                .padding(6)
        }
        .buttonStyle(.plain)
    }
}

private struct CategoryDragPreview: View {
    let category: FinanceCategory

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(category.color)
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: category.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
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

private struct CategoryReorderDropDelegate: DropDelegate {
    let destinationCategoryID: String
    @Binding var draggedCategoryID: String?
    @Binding var targetedCategoryID: String?
    let moveCategory: (String, String) -> Void
    let clearDragState: () -> Void

    func dropEntered(info: DropInfo) {
        guard let sourceCategoryID = draggedCategoryID,
              sourceCategoryID != destinationCategoryID else {
            return
        }

        targetedCategoryID = destinationCategoryID

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            moveCategory(sourceCategoryID, destinationCategoryID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if targetedCategoryID == destinationCategoryID {
            targetedCategoryID = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        clearDragState()
        return true
    }
}

#Preview {
    NavigationView {
        CategoryManagementView()
            .environmentObject(SettingsViewModel())
            .environmentObject(CategoryStore())
    }
}
