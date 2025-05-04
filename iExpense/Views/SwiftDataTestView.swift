//
//  SwiftDataTestView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI
import SwiftData

// This is a test view to verify that SwiftData is working correctly
// Without modifying any existing functionality
struct SwiftDataTestView: View {
    // Access to SwiftData store
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [ExpenseItem]
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if expenses.isEmpty {
                    Text("No expenses found in SwiftData")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(expenses) { expense in
                        VStack(alignment: .leading) {
                            Text(expense.name)
                                .font(.headline)
                            
                            HStack {
                                Text(expense.amount, format: .currency(code: "USD"))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text(expense.date, format: .dateTime.day().month().year())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("Category: \(expense.categoryName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("SwiftData Test")
            .toolbar {
                Button("Load from SwiftData") {
                    loadData()
                }
            }
            .onAppear {
                loadData()
            }
        }
    }
    
    private func loadData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // This is just to force a refresh of the @Query results
                let context = modelContext
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

#Preview {
    SwiftDataTestView()
        .modelContainer(for: ExpenseItem.self, inMemory: true)
} 