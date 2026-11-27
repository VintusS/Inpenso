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
    @StateObject private var recurringViewModel = RecurringViewModel()
    @StateObject private var walletsViewModel = WalletsViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                HomeView(viewModel: viewModel, analyticsViewModel: analyticsViewModel, recurringViewModel: recurringViewModel)
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
                        Label("Transactions", systemImage: "list.bullet.rectangle.portrait.fill")
                    }
                    .tag(2)

                WalletsView(walletsViewModel: walletsViewModel, expenseViewModel: viewModel)
                    .tabItem {
                        Label("Wallets", systemImage: "wallet.bifold.fill")
                    }
                    .tag(4)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(3)
            }
            .id(settingsViewModel.selectedCurrency)
        }
        .preferredColorScheme(settingsViewModel.selectedTheme.colorScheme)
        .environmentObject(walletsViewModel)
        .onAppear {
            analyticsViewModel.updateExpenses(viewModel.expenses)
            
            // Register for the notification to switch tabs
            NotificationCenter.default.addObserver(forName: NSNotification.Name("SwitchToExpensesTab"), object: nil, queue: .main) { _ in
                selectedTab = 2 // Switch to Expenses tab
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .inpensoDataDidChange)) { _ in
            viewModel.loadExpenses()
            analyticsViewModel.reloadBudgets()
            categoryStore.reload()
            recurringViewModel.refresh()
            walletsViewModel.refresh()
        }
        .onChange(of: scenePhase) {
            // Recurring items can come due while the app is in the background.
            if scenePhase == .active {
                recurringViewModel.refresh()
                walletsViewModel.refresh()
            }
        }
        .onChange(of: viewModel.expenses) {
            analyticsViewModel.updateExpenses(viewModel.expenses)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(SettingsViewModel())
        .environmentObject(WalletsViewModel())
}
