//
//  jOSApp.swift
//  jOS
//
//  Created by Jason T Alborough on 10/1/23.
//

import SwiftUI
import KeychainSwift  // Make sure to import KeychainSwift

@main
struct jOSApp: App {
    @StateObject var notionController: NotionController = NotionController()
    let globalSettings = GlobalSettings.shared
    @State private var showingPreferences = false
    let keychain = KeychainSwift()
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                TaskListView()
                    .environmentObject(notionController)
                    .environmentObject(globalSettings)
                    #if os(iOS)
                    .navigationBarTitle("Menu Bar", displayMode: .inline)
                    .navigationBarItems(trailing:
                        NavigationLink(destination: PreferencesView(showingPreferences: $showingPreferences)
                                        .environmentObject(globalSettings)) {
                            Image(systemName: "gear")
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                    )
                    .preferredColorScheme(.dark)  // Enable dark mode
                    #endif
                    .onAppear {
                        loadFromKeychain()
                        notionController.GetOpenTimeTickets()
                        notionController.GetOpenTasks()
                    }
            }
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

