//
//  CategoryManagementView.swift
//  iExpense
//

import SwiftUI

struct CategoryManagementView: View {
    @EnvironmentObject private var categoryStore: CategoryStore
    @State private var categoryToEdit: FinanceCategory?
    @State private var showingEditor = false

    var body: some View {
        List {
            Section("Built In") {
                ForEach(FinanceCategory.builtInCategories) { category in
                    categoryRow(category)
                }
            }

            Section("Custom") {
                if categoryStore.customCategories.isEmpty {
                    Text("No custom categories yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(categoryStore.customCategories) { category in
                        categoryRow(category)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                categoryToEdit = category
                                showingEditor = true
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    categoryStore.deleteCategory(category)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
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
        }
    }

    private func categoryRow(_ category: FinanceCategory) -> some View {
        HStack(spacing: 12) {
            Image(systemName: category.iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(category.color)
                .clipShape(Circle())

            Text(category.displayName)

            Spacer()

            if category.isCustom {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var categoryStore: CategoryStore

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
}

#Preview {
    NavigationView {
        CategoryManagementView()
            .environmentObject(CategoryStore())
    }
}

