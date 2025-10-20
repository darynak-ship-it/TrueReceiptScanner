//
//  Receipt_ScannerApp.swift
//  Receipt Scanner
//
//  Created by Daryna Kalnichenko on 10/15/25.
//

import SwiftUI
import CoreData

@main
struct Receipt_ScannerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
