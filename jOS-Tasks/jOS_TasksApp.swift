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
    @State var idleTime = 0

    init() {
        // Load credentials before any polling or API calls happen
        let kc = KeychainSwift()
        let settings = GlobalSettings.shared
        if let apiKey = kc.get("apiKey") { settings.apiKey = apiKey }
        if let ttDbId = kc.get("timeTrackingDatabaseId") { settings.TimeTrackingDatatbaseId = ttDbId }
        if let taskDbId = kc.get("taskDatabaseId") { settings.TaskDatatbaseId = taskDbId }
        print("Loaded from keychain — apiKey empty: \(settings.apiKey.isEmpty), ttDb empty: \(settings.TimeTrackingDatatbaseId.isEmpty), taskDb empty: \(settings.TaskDatatbaseId.isEmpty)")
    }

#if os(macOS)
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(globalSettings)
                .environmentObject(notionController)
                .onAppear {
                    notionController.startPolling()
//                    Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
//                        idleTime = getIdleTime() ?? 0 // In nano-seconds
//                        if idleTime >= 600  { // 10 minutes in nano-seconds
//                            showWarningDialog(idleTe: idleTime)
//                        }
//                    }
                }
        }
        MenuBarExtra("\(String(notionController.currentTimeEntry))", content:
                        {
            MenubarView(isMenuPresented: $isMenuPresented)
                .introspectMenuBarExtraWindow { window in // <-- the magic ✨
                    window.animationBehavior = .utilityWindow
                    // Observe each time the window becomes key (i.e. opens)
                    // so we resize after SwiftUI's layout pass is done
                    NotificationCenter.default.addObserver(
                        forName: NSWindow.didBecomeKeyNotification,
                        object: window,
                        queue: .main
                    ) { _ in
                        let screenHeight = window.screen?.visibleFrame.height
                            ?? NSScreen.main?.visibleFrame.height
                            ?? 800
                        let targetHeight = (screenHeight * 0.75).rounded()
                        var frame = window.frame
                        frame.origin.y = frame.maxY - targetHeight
                        frame.size = NSSize(width: 720, height: targetHeight)
                        window.setFrame(frame, display: true, animate: false)
                    }
                }
                .environmentObject(notionController)
        }).menuBarExtraStyle(.window)
            .menuBarExtraAccess(isPresented: $isMenuPresented) { statusItem in // <-- the magic ✨
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
    
    func showWarningDialog(idleTime: Int) {
        let idleTimeInMinutes = (idleTime / 60)
        let alert = NSAlert()
        alert.messageText = "You have been idle for \(Int(idleTimeInMinutes)) minute(s)"
        alert.informativeText = "Do you want to stop the timer?"
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            self.notionController.updateCurrentTimerEndTime(minutes: (Int(idleTimeInMinutes) *  -1))
        } else if response == .alertSecondButtonReturn {
            
        }
    }

}





        

        








