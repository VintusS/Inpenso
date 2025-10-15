//
//  SettingsView.swift
//  iExpense
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsViewModel
    
    @State private var showingImportFilePicker = false
    @State private var showingExportShareSheet = false
    @State private var exportURL: URL? = nil
    @State private var showingResetConfirmation = false
    @State private var showingImportSuccess = false
    @State private var showingImportFailure = false
    @State private var showingExportSuccess = false
    
    var body: some View {
        NavigationView {
            Form {
                // Appearance Section
                appearanceSection
                
                // Currency Section
                currencySection
                
                // Default Settings Section
                defaultSettingsSection
                
                // Data Management Section
                dataManagementSection
                
                // About Section
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingImportFilePicker) {
                documentPicker
            }
            .sheet(isPresented: $showingExportShareSheet) {
                shareSheet
            }
            .alert("Data Reset", isPresented: $showingResetConfirmation) {
                resetAlertButtons
            } message: {
                Text("This will delete all your expenses and budgets. This action cannot be undone.")
            }
            .alert("Import Successful", isPresented: $showingImportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your data has been imported successfully.")
            }
            .alert("Import Failed", isPresented: $showingImportFailure) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Failed to import data. Please check the file format and try again.")
            }
            .alert("Export Successful", isPresented: $showingExportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your data has been exported successfully.")
            }
        }
    }
    
    // MARK: - UI Components
    
    private var appearanceSection: some View {
        Section(header: Text("Appearance")) {
            themePicker
        }
    }
    
    private var themePicker: some View {
        Picker("Theme", selection: $settingsManager.selectedTheme) {
            ForEach(AppTheme.allCases) { theme in
                Text(theme.displayName).tag(theme)
            }
        }
        .pickerStyle(.menu)
    }
    
    private var currencySection: some View {
        Section(header: Text("Currency")) {
            currencyPicker
        }
    }
    
    private var currencyPicker: some View {
        Picker("Currency", selection: $settingsManager.selectedCurrency) {
            ForEach(availableCurrencies, id: \.code) { currency in
                currencyRow(for: currency)
            }
        }
        .pickerStyle(.menu)
    }
    
    private func currencyRow(for currency: (code: String, symbol: String, name: String)) -> some View {
        Text("\(currency.symbol) \(currency.name) (\(currency.code))")
            .tag(currency.code)
    }
    
    private var defaultSettingsSection: some View {
        Section(header: Text("Default Settings")) {
            categoryPicker
        }
    }
    
    private var categoryPicker: some View {
        Picker("Default Category", selection: $settingsManager.defaultCategory) {
            ForEach(Category.allCases, id: \.self) { category in
                categoryRow(for: category)
            }
        }
        .pickerStyle(.menu)
    }
    
    private func categoryRow(for category: Category) -> some View {
        HStack {
            Circle()
                .fill(category.color)
                .frame(width: 12, height: 12)
            Text(category.displayName).tag(category)
        }
    }
    
    private var dataManagementSection: some View {
        Section(header: Text("Data Management")) {
            exportButton
            importButton
            resetButton
        }
    }
    
    private var exportButton: some View {
        Button(action: {
            exportData()
        }) {
            Label("Export Data", systemImage: "square.and.arrow.up")
        }
    }
    
    private var importButton: some View {
        Button(action: {
            showingImportFilePicker = true
        }) {
            Label("Import Data", systemImage: "square.and.arrow.down")
        }
    }
    
    private var resetButton: some View {
        Button(role: .destructive, action: {
            showingResetConfirmation = true
        }) {
            Label("Reset All Data", systemImage: "trash")
        }
        .foregroundColor(.red)
    }
    
    private var aboutSection: some View {
        Section(header: Text("About")) {
            versionRow
        }
    }
    
    private var versionRow: some View {
        HStack {
            Text("Version")
            Spacer()
            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                .foregroundColor(.secondary)
        }
    }
    
    private var documentPicker: some View {
        DocumentPicker(
            types: [UTType.json],
            allowsMultipleSelection: false
        ) { urls in
            guard let url = urls.first else { return }
            let success = settingsManager.importData(from: url)
            if success {
                showingImportSuccess = true
            } else {
                showingImportFailure = true
            }
        }
    }
    
    private var shareSheet: some View {
        Group {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    private var resetAlertButtons: some View {
        Group {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settingsManager.resetAllData()
            }
        }
    }
    
    private func exportData() {
        if let url = settingsManager.exportData() {
            exportURL = url
            showingExportShareSheet = true
            showingExportSuccess = true
        }
    }
}

// Document Picker for importing files
struct DocumentPicker: UIViewControllerRepresentable {
    let types: [UTType]
    let allowsMultipleSelection: Bool
    let onPick: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
        }
    }
}

// ShareSheet for exporting files
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .environmentObject(SettingsViewModel())
}
