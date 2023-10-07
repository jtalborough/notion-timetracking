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
    @State private var showingPreferences = false


#if os(macOS)
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(globalSettings)
                .environmentObject(notionController)
                .onAppear {
                    loadFromKeychain()
                    notionController.GetOpenTasks()
                    notionController.GetOpenTimeTickets()
                }
        }
        MenuBarExtra("\(String(notionController.currentTimeEntry))", content:
                        {
            MenubarView(isMenuPresented: $isMenuPresented)
                .introspectMenuBarExtraWindow { window in // <-- the magic ✨
                    window.animationBehavior = .utilityWindow
                }
                .environmentObject(notionController)
        }).menuBarExtraStyle(.window)
            .menuBarExtraAccess(isPresented: $isMenuPresented) { statusItem in // <-- the magic ✨
            }
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
    }
#endif
#if os(iOS)
    var body: some Scene {
        WindowGroup {
            NavigationView {
                TaskListView()
                    .environmentObject(notionController)
                    .environmentObject(globalSettings)
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
                    .onAppear {
                        loadFromKeychain()
                        notionController.GetOpenTimeTickets()
                        notionController.GetOpenTasks()
                    }
            }
        }
    }
#endif
    
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





        

        








