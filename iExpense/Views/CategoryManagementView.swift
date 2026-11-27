//
//  CategoryManagementView.swift
//  iExpense
//

import SwiftUI
import UniformTypeIdentifiers

struct CategoryManagementView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var categoryStore: CategoryStore
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @State private var categoryToEdit: FinanceCategory?
    @State private var showingEditor = false
    @State private var targetedCategoryID: String?
    @State private var draggedCategoryID: String?
    @State private var showingReorder = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 2 : 3)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(categoryStore.sortsByUsage
                     ? "Sorted by most used in the last \(CategoryStore.usageWindowDays) days. Pickers follow this order."
                     : "Pickers follow this order. Press and hold a tile to drag it, or use the sort menu.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                ForEach(CategoryKind.allCases) { kind in
                    categorySection(
                        title: kind == .income ? "Income" : "Expenses",
                        categories: categoryStore.visibleCategories.filter { $0.kind == kind },
                        isHiddenSection: false
                    )
                }

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
                sortMenu
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    categoryToEdit = nil
                    showingEditor = true
                } label: {
                    Label("Add Category", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
            }
        }
        .sheet(isPresented: $showingReorder) {
            CategoryReorderView()
                .environmentObject(categoryStore)
        }
        .sheet(isPresented: $showingEditor) {
            CategoryEditorView(category: categoryToEdit)
                .environmentObject(categoryStore)
                .environmentObject(settingsViewModel)
        }
    }

    private var sortMenu: some View {
        Menu {
            Toggle(isOn: Binding(get: { categoryStore.sortsByUsage }, set: { categoryStore.setSortsByUsage($0) })) {
                Label("Always Sort by Most Used", systemImage: "chart.bar")
            }
            Section("Sort once") {
                Button {
                    CategoryKind.allCases.forEach(categoryStore.sortByUsage(kind:))
                } label: {
                    Label("Most Used", systemImage: "flame")
                }
                Button {
                    CategoryKind.allCases.forEach(categoryStore.sortAlphabetically(kind:))
                } label: {
                    Label("A to Z", systemImage: "textformat")
                }
            }
            Button {
                showingReorder = true
            } label: {
                Label("Reorder…", systemImage: "line.3.horizontal")
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("Sort categories")
    }

    private func categorySection(title: String, categories: [FinanceCategory], isHiddenSection: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(categories) { category in
                    if isHiddenSection || categoryStore.sortsByUsage {
                        managementTile(for: category, isHiddenSection: isHiddenSection)
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
                            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: categoryStore.visibleCategories.map(\.id))
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
    @State private var kind: CategoryKind
    @State private var showingValidation = false

    private let icons = [
        "tag.fill", "briefcase.fill", "banknote.fill", "creditcard.fill",
        "gift.fill", "cart.fill", "fork.knife", "house.fill",
        "car.fill", "tram.fill", "airplane", "heart.fill",
        "cross.case.fill", "book.fill", "graduationcap.fill", "gamecontroller.fill",
        "music.note", "pawprint.fill", "leaf.fill", "hammer.fill",
    ]

    private let colors = [
        "#007AFF", "#34C759", "#FF9500", "#FF3B30",
        "#AF52DE", "#FF2D55", "#5856D6", "#00C7BE",
        "#30B0C7", "#FFCC00", "#8E8E93", "#A2845E",
    ]

    init(category: FinanceCategory?) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _iconName = State(initialValue: category?.iconName ?? "tag.fill")
        _colorHex = State(initialValue: category?.colorHex ?? "#007AFF")
        _kind = State(initialValue: category?.kind ?? .expense)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    if category == nil {
                        Picker("Used for", selection: $kind) {
                            ForEach(CategoryKind.allCases) { kind in
                                Text(kind.displayName).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    Text("Details")
                } footer: {
                    if category == nil {
                        Text("Expense categories also hold refunds and cashback for that kind of spending.")
                    }
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                iconName = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: 44, height: 44)
                                    .background(iconName == icon ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemBackground))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(icon.replacingOccurrences(of: ".", with: " "))
                            .accessibilityAddTraits(iconName == icon ? .isSelected : [])
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
                                                .foregroundStyle((Color(hex: color) ?? .gray).badgeForeground)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color \(color)")
                            .accessibilityAddTraits(colorHex == color ? .isSelected : [])
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
            categoryStore.addCategory(name: trimmedName, iconName: iconName, colorHex: colorHex, kind: kind)
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

#Preview {
    NavigationStack {
        CategoryManagementView()
            .environmentObject(SettingsViewModel())
            .environmentObject(CategoryStore())
    }
}
