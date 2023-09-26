//
//  notion_timetrackingApp.swift
//  notion-timetracking
//
//  Created by Jason T Alborough on 9/24/23.
//

import SwiftUI
import KeychainSwift  // Make sure to import KeychainSwift
// Initialize the GlobalSettings object


@main
struct notion_timetrackingApp: App {
    let globalSettings = GlobalSettings.shared
    var notionController: NotionController
    let keychain = KeychainSwift()

    init() {
        notionController = NotionController()
        loadFromKeychain()
        notionController.queryOpenTasks()

    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(globalSettings)
                .environmentObject(notionController)
                
        }
        MenuBarExtra("TEST", systemImage: "star")
        {
            MenubarView().environmentObject(notionController)
        }
    }

    func loadFromKeychain() {
        if let savedApiKey = keychain.get("apiKey")
        {
            self.globalSettings.apiKey = savedApiKey
        }
        if let timeTrackingDatabaseId = keychain.get("timeTrackingDatabaseId")
        {
            self.globalSettings.TimeTrackingDatatbaseId = timeTrackingDatabaseId
        }
        
        if let taskDatabaseId = keychain.get("taskDatabaseId")
        {
            self.globalSettings.TaskDatatbaseId = taskDatabaseId
        }
    }
}





        

        








