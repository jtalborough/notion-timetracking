//
//  ContentView.swift
//  notion-timetracking
//
//  Created by Jason T Alborough on 9/24/23.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var globalSettings: GlobalSettings
    @EnvironmentObject var notionController: NotionController

    @State private var showingPreferences = false
    
    var body: some View {
        ZStack {
            VStack {
                // Display current task and time used
                if let currentEntry = notionController.currentOpenTimeEntry {
                    Text("Current Task: \(currentEntry.taskName)")
                        .font(.title)
                    
                    Text("Time Used: \(String(format: "%", currentEntry.timeUsed))")
                        .font(.subheadline)
                } else {
                    Text("No current task.")
                        .font(.title)
                }
                Button(action: {
                    // Your logic for ending the time entry
                    notionController.updateTaskInDatabase(timeEntry: notionController.currentOpenTimeEntry!) { success in
                        if success {
                            print("Debug: Successfully updated the task in the database.")
                        } else {
                            print("Debug: Failed to update the task in the database.")
                        }
                    }
                }) {
                    Text("End")
                        .font(.title)
                        .foregroundColor(.red)
                }
                .padding()
                
                Spacer()
                
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            showingPreferences.toggle()
                        }
                    }) {
                        Image(systemName: "gear")
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                    .padding()
                }
            }
            
            if showingPreferences {
                PreferencesView(showingPreferences: $showingPreferences)
                    .environmentObject(globalSettings)
            }
        }
    }
}











#Preview {
    MainView()
}
