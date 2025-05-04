//
//  MainTabView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @StateObject private var viewModel = ExpenseViewModel()
    @StateObject private var analyticsViewModel = AnalyticsViewModel(expenses: [])
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var colorScheme: ColorScheme?
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                HomeView(viewModel: viewModel, analyticsViewModel: analyticsViewModel)
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                AnalyticsView(analyticsViewModel: analyticsViewModel)
                    .tabItem {
                        Label("Analytics", systemImage: "chart.pie.fill")
                    }
                    .tag(1)

                ExpensesListView(viewModel: viewModel)
                    .tabItem {
                        Label("Expenses", systemImage: "list.bullet.rectangle.portrait.fill")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(3)
                
                // New tab for SwiftData testing
                SwiftDataTestView()
                    .tabItem {
                        Label("SwiftData", systemImage: "externaldrive.fill")
                    }
                    .tag(4)
            }
        }
        .preferredColorScheme(colorScheme)
        .onAppear {
            analyticsViewModel.updateExpenses(viewModel.expenses)
            updateColorScheme()
            
            // Register for the notification to switch tabs
            NotificationCenter.default.addObserver(forName: NSNotification.Name("SwitchToExpensesTab"), object: nil, queue: .main) { _ in
                selectedTab = 2 // Switch to Expenses tab
            }
        }
        .onChange(of: viewModel.expenses) { newExpenses in
            analyticsViewModel.updateExpenses(newExpenses)
        }
        .onChange(of: settingsViewModel.selectedTheme) { _ in
            updateColorScheme()
        }
    }
    
    private func updateColorScheme() {
        colorScheme = settingsViewModel.selectedTheme.colorScheme
    }
}

#Preview {
    MainTabView()
}
