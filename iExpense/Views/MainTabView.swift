//
//  MainTabView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var viewModel = ExpenseViewModel()
    @StateObject private var analyticsViewModel = AnalyticsViewModel(expenses: [])
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var colorScheme: ColorScheme?

    var body: some View {
        NavigationView {
            TabView {
                HomeView(viewModel: viewModel, analyticsViewModel: analyticsViewModel)
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }

                AnalyticsView(analyticsViewModel: analyticsViewModel)
                    .tabItem {
                        Label("Analytics", systemImage: "chart.pie.fill")
                    }

                ExpensesListView(viewModel: viewModel)
                    .tabItem {
                        Label("Expenses", systemImage: "list.bullet.rectangle.portrait.fill")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
        }
        .preferredColorScheme(colorScheme)
        .onAppear {
            analyticsViewModel.updateExpenses(viewModel.expenses)
            updateColorScheme()
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
