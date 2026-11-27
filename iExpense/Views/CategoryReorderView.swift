//
//  CategoryReorderView.swift
//  iExpense
//

import SwiftUI

/// Drag-handle list for the manual category order, one section per kind.
struct CategoryReorderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var categoryStore: CategoryStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(CategoryKind.allCases) { kind in
                    Section {
                        ForEach(categoryStore.manuallyOrderedCategories(kind: kind)) { category in
                            Label(category.displayName, systemImage: category.iconName)
                                .foregroundStyle(.primary)
                        }
                        .onMove { source, destination in
                            categoryStore.moveCategories(kind: kind, fromOffsets: source, toOffset: destination)
                        }
                    } header: {
                        Text(kind == .income ? "Income" : "Expenses")
                    } footer: {
                        if kind == .income && categoryStore.sortsByUsage {
                            Text("Always Sort by Most Used is on, so pickers ignore this order until you turn it off.")
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Live reordering while a category tile is dragged on the Manage Categories grid.
struct CategoryReorderDropDelegate: DropDelegate {
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

        moveCategory(sourceCategoryID, destinationCategoryID)
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
