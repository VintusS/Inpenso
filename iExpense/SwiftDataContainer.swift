//
//  SwiftDataContainer.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation
import SwiftData
import SwiftUI

// This class wraps the SwiftData container so it can be used selectively
// without modifying the existing app structure yet
class SwiftDataProvider {
    
    // Singleton instance
    static let shared = SwiftDataProvider()
    
    // The model container
    private(set) var container: ModelContainer?
    
    // Private initializer for singleton
    private init() {
        setupContainer()
    }
    
    // Setup the SwiftData container
    private func setupContainer() {
        do {
            container = try SwiftDataManager.shared.createContainer()
        } catch {
            // Silent failure - don't show errors in UI
        }
    }
    
    // Start the migration process
    func startMigration() async {
        guard let container = container else { return }
        
        do {
            // Run migration silently (no UI indication)
            try await SwiftDataManager.shared.migrateData(using: container.mainContext, silent: true)
        } catch {
            // Silent failure - don't show errors in UI
        }
    }
}

// SwiftUI view modifier to add the container to the environment
// without forcing its use throughout the app
struct OptionalSwiftDataContainer: ViewModifier {
    func body(content: Content) -> some View {
        if let container = SwiftDataProvider.shared.container {
            content.modelContainer(container)
        } else {
            content
        }
    }
}

extension View {
    // Use this to optionally add SwiftData to a view
    func withSwiftData() -> some View {
        self.modifier(OptionalSwiftDataContainer())
    }
} 