//
//  SettingsView.swift
//  iExpense
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Text("Theme (Coming Soon)")
                }

                Section(header: Text("Data")) {
                    Text("iCloud Sync (Coming Soon)")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
