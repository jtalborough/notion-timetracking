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
    }

    func loadFromKeychain() {
        if let savedApiKey = keychain.get("apiKey"), let savedDatabaseId = keychain.get("databaseId") {
            self.globalSettings.apiKey = savedApiKey
            self.globalSettings.TimeTrackingDatatbaseId = savedDatabaseId
        }
    }
}




struct TaskListView: View {
    //@Environment(\.openURL) var openURL
    //@ObservedObject var calendar: NotionController
    @State private var showingPreferences = false
    
    var body: some View {
        VStack(spacing: 5) {
            // Display current date
            Text(currentDate())
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(currentWeek())
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.bottom, 5)
            /*
             ForEach(calendar.MyEvents, id: \.Uuid) {
             event in EventRowView(event: event)
             }
             */
        }.padding(10)
        //.border(Color.white).padding(5)
        Divider()
        Menu("Settings") {
            //Form {
            //   LaunchAtLogin.Toggle()
            //}
            Button("Preferences") {
                print("Preferences button clicked")  // Debugging
                showingPreferences.toggle()
                print("showingPreferences is now \(showingPreferences)")  // Debugging
            }                .sheet(isPresented: $showingPreferences) {
                let _ =  print("Trying to present test view")  // Debugging
                Text("Hello, this is a test.")  // Test view
            }
            Button(action: {
                NSApplication.shared.terminate(self)
            }) {
                Text("Quit")
                Image(systemName: "xmark.circle")
            }

        }
            .menuStyle(BorderlessButtonMenuStyle())
            .padding(10)

            
        
       
    }
        

        


    
    func currentDate() -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return "\(formatter.string(from: date))"
    }
    
    func currentWeek() -> String {
        let date = Date()
        
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: date)
        
        return "Week \(weekOfYear)"
    }
}






