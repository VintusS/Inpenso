//
//  SettingsView.swift
//  iExpense
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    
    @State private var showingImportFilePicker = false
    @State private var showingExportShareSheet = false
    @State private var exportURL: URL?
    @State private var showingResetConfirmation = false
    @State private var showingImportSuccess = false
    @State private var restorePreview: RestorePreview?
    @State private var dataErrorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                // Appearance Section
                appearanceSection
                
                // Currency Section
                currencySection
                
                // Default Settings Section
                defaultSettingsSection

                // Category Management Section
                categoriesSection
                
                // Data Management Section
                dataManagementSection
                
                // About Section
                aboutSection
            }
            .navigationTitle("Settings")
            .onAppear { settingsManager.refreshLedgerCurrency() }
            .onReceive(NotificationCenter.default.publisher(for: .inpensoDataDidChange)) { _ in
                settingsManager.refreshLedgerCurrency()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                settingsManager.refreshLedgerCurrency()
            }
            .sheet(isPresented: $showingImportFilePicker) {
                documentPicker
            }
            .sheet(isPresented: $showingExportShareSheet) {
                shareSheet
            }
            .alert("Data Reset", isPresented: $showingResetConfirmation) {
                resetAlertButtons
            } message: {
                Text("This will delete all transactions, transfers, and monthly budgets. This action cannot be undone.")
            }
            .confirmationDialog(
                "Restore Backup",
                isPresented: Binding(
                    get: { restorePreview != nil },
                    set: { if !$0 { restorePreview = nil } }
                ),
                titleVisibility: .visible,
                presenting: restorePreview
            ) { preview in
                Button("Merge Backup") {
                    restore(preview, mode: .merge)
                }
                .disabled(preview.currencyDiffers || (
                    preview.newTransactionCount == 0 && preview.newBudgetCount == 0
                        && preview.newCustomCategoryCount == 0 && preview.newWalletCount == 0
                        && preview.newTransferCount == 0
                ))
                Button("Replace All Data", role: .destructive) {
                    restore(preview, mode: .replace)
                }
                Button("Cancel", role: .cancel) { }
            } message: { preview in
                Text(restoreSummary(preview))
            }
            .alert("Backup Restored", isPresented: $showingImportSuccess) {
                Button("OK", role: .cancel) { }
            }
            .alert(
                "Data Problem",
                isPresented: Binding(
                    get: { dataErrorMessage != nil },
                    set: { if !$0 { dataErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(dataErrorMessage ?? "")
            }
        }
    }
}

// MARK: - Sections

extension SettingsView {
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
        Section {
            currencyPicker
                .disabled(settingsManager.isCurrencyLocked)
        } header: {
            Text("Currency")
        } footer: {
            if settingsManager.isCurrencyLocked {
                Text("Currency is locked while the ledger contains transactions or transfers.")
            }
        }
    }
    
    private var currencyPicker: some View {
        Picker("Currency", selection: Binding(
            get: { settingsManager.selectedCurrency },
            set: { currency in
                do {
                    try settingsManager.changeCurrency(to: currency)
                } catch {
                    dataErrorMessage = error.localizedDescription
                }
            }
        )) {
            ForEach(availableCurrencies, id: \.code) { currency in
                currencyRow(for: currency)
            }
        }
        .pickerStyle(.menu)
    }
    
    private func currencyRow(for currency: CurrencyOption) -> some View {
        Text("\(currency.symbol) \(currency.name) (\(currency.code))")
            .tag(currency.code)
    }
    
    private var defaultSettingsSection: some View {
        Section(header: Text("Default Settings")) {
            categoryPicker
        }
    }
    
    private var categoryPicker: some View {
        Picker("Default Category", selection: $settingsManager.defaultCategoryID) {
            ForEach(categoryStore.categoriesForPicker(kind: .expense)) { category in
                categoryRow(for: category)
            }
        }
        .pickerStyle(.menu)
        .onAppear {
            normalizeDefaultCategory()
        }
        .onChange(of: categoryStore.allCategories.map(\.id)) { _, _ in
            normalizeDefaultCategory()
        }
    }
    
    private func categoryRow(for category: FinanceCategory) -> some View {
        HStack {
            Circle()
                .fill(category.color)
                .frame(width: 12, height: 12)
            Text(category.displayName)
        }
        .tag(category.id)
    }

    private func normalizeDefaultCategory() {
        let preferredCategoryID = categoryStore.preferredCategoryID(for: settingsManager.defaultCategoryID)
        if preferredCategoryID != settingsManager.defaultCategoryID {
            settingsManager.defaultCategoryID = preferredCategoryID
        }
    }

    private var categoriesSection: some View {
        Section(header: Text("Categories")) {
            NavigationLink {
                CategoryManagementView()
            } label: {
                Label("Manage Categories", systemImage: "square.grid.2x2")
            }
        }
    }
    
    private var dataManagementSection: some View {
        Section(header: Text("Data Management")) {
            exportButton
            Button(action: exportCSV) {
                Label("Export CSV", systemImage: "tablecells")
            }
            importButton
            resetButton
        }
    }
    
    private var exportButton: some View {
        Button {
            exportData()
        } label: {
            Label("Back Up Data", systemImage: "square.and.arrow.up")
        }
    }

    private var importButton: some View {
        Button {
            showingImportFilePicker = true
        } label: {
            Label("Restore Backup", systemImage: "square.and.arrow.down")
        }
    }

    private var resetButton: some View {
        Button(role: .destructive) {
            showingResetConfirmation = true
        } label: {
            Label("Reset All Data", systemImage: "trash")
        }
        .foregroundColor(.red)
    }
    
    private var aboutSection: some View {
        Section {
            versionRow
            if let expiry = ProvisioningInfo.expirationDate {
                reinstallRow(expiry)
            }
        } header: {
            Text("About")
        } footer: {
            if ProvisioningInfo.expirationDate != nil {
                Text("This build is signed for development and stops opening after that date. "
                     + "Reinstall it from Xcode before then; your data stays.")
            }
        }
    }

    private func reinstallRow(_ expiry: Date) -> some View {
        let calendar = Calendar.current
        let daysLeft = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()),
                                               to: calendar.startOfDay(for: expiry)).day ?? 0
        let tint: Color = expiry < Date() ? .red : (daysLeft <= 1 ? .orange : .secondary)
        let relative: String = {
            if expiry < Date() { return "Expired" }
            switch daysLeft {
            case 0:
                return "Today"
            case 1:
                return "Tomorrow"
            default:
                return "In \(daysLeft) days"
            }
        }()
        return HStack(alignment: .firstTextBaseline) {
            Text("Reinstall by")
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(expiry, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
                    .foregroundColor(tint == .secondary ? .secondary : tint)
                Text(relative)
                    .font(.caption)
                    .foregroundColor(tint)
            }
            .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
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
            do {
                restorePreview = try settingsManager.previewRestore(from: url)
            } catch {
                dataErrorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "This file couldn't be read. Choose a backup made with Inpenso."
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
        do {
            exportURL = try settingsManager.exportBackup()
            showingExportShareSheet = true
        } catch {
            dataErrorMessage = "The backup couldn't be created. Try again."
        }
    }

    private func exportCSV() {
        do {
            guard let ledger = StorageService.loadLedger() else { throw WalletError.storageFailure }
            exportURL = try CSVExportService.export(
                transactions: ledger.transactions,
                currencyCode: ledger.currency,
                wallets: ledger.wallets,
                transfers: ledger.transfers,
                categoryName: { categoryStore.category(for: $0).displayName }
            )
            showingExportShareSheet = true
        } catch {
            dataErrorMessage = "The CSV couldn't be created. Try again."
        }
    }

    private func restore(_ preview: RestorePreview, mode: RestoreMode) {
        do {
            try settingsManager.applyRestore(preview, mode: mode)
            showingImportSuccess = true
        } catch {
            dataErrorMessage = error.localizedDescription
        }
    }

    private func restoreSummary(_ preview: RestorePreview) -> String {
        var lines: [String] = []
        lines.append("\(preview.totalTransactionCount) transactions in this file: \(preview.newTransactionCount) new, \(preview.duplicateTransactionCount) already here.")
        if preview.newWalletCount > 0 {
            lines.append("\(preview.newWalletCount) new wallets.")
        }
        if preview.newTransferCount > 0 {
            lines.append("\(preview.newTransferCount) new transfers.")
        }
        if preview.newBudgetCount > 0 {
            lines.append("\(preview.newBudgetCount) monthly budgets not set here yet.")
        }
        if preview.newCustomCategoryCount > 0 {
            lines.append("\(preview.newCustomCategoryCount) custom categories to add.")
        }
        if preview.isLegacyFormat {
            lines.append("Older export: contains transactions only. Amounts will use your current currency (\(preview.currentCurrencyCode)).")
        } else if preview.currencyDiffers {
            lines.append("This backup uses \(preview.backup.currencyCode); you use \(preview.currentCurrencyCode). Replacing the ledger restores \(preview.backup.currencyCode).")
        }
        lines.append("Replacing deletes your current transactions, budgets and categories.")
        return lines.joined(separator: "\n\n")
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
        .environmentObject(CategoryStore())
}
