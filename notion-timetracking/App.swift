//
//  notion_timetrackingApp.swift
//  notion-timetracking
//
//  Created by Jason T Alborough on 9/24/23.
//

import SwiftUI
import KeychainSwift  // Make sure to import KeychainSwift
// Initialize the GlobalSettings object
import MenuBarExtraAccess


@main
struct notion_timetrackingApp: App {
    let globalSettings = GlobalSettings.shared
    @State var isMenuPresented: Bool = false
    @StateObject var notionController: NotionController = NotionController()
    let keychain = KeychainSwift()

    init() {

        //notionController = NotionController()
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(globalSettings)
                .environmentObject(notionController)
                .onAppear {
                                loadFromKeychain()
                                notionController.GetOpenTimeTickets()
                                notionController.GetOpenTasks()
                            }
                
        }
        MenuBarExtra(notionController.currentTimeEntry, content:
        {
            MenubarView(isMenuPresented: $isMenuPresented)
                .introspectMenuBarExtraWindow { window in // <-- the magic ✨
                    window.animationBehavior = .alertPanel
                }
                .environmentObject(notionController)
        }).menuBarExtraStyle(.window)
        .menuBarExtraAccess(isPresented: $isMenuPresented) { statusItem in // <-- the magic ✨
                         // access status item or store it in a @State var
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





        

        








