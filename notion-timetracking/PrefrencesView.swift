import Foundation
import SwiftUI

struct PreferencesView: View {
    @Binding var showingPreferences: Bool
    @EnvironmentObject var globalSettings: GlobalSettings

    var body: some View {
        VStack {
            Form {
                TextField("API Key", text: $globalSettings.apiKey)
                TextField("Time Tracking Database ID", text: $globalSettings.TimeTrackingDatatbaseId)
                TextField("Task Database ID", text: $globalSettings.TaskDatatbaseId)
                Button("Save") {
                    saveToKeychain()
                }
            }
        }
        .padding()
    }


    
    func saveToKeychain() {
        DispatchQueue.global(qos: .userInitiated).async {
            print("saveToKeychain called")  // Add this line
            let keychain = KeychainHelper.standard

            // Use globalSettings.apiKey and globalSettings.databaseId
            if let apiKeyData = self.globalSettings.apiKey.data(using: .utf8)
            {
                keychain.save(apiKeyData, service: "NotionTimeTracking", account: "apiKey")
            }
            
            if   let timeTrackingDatabaseId = self.globalSettings.TimeTrackingDatatbaseId.data(using: .utf8)
            {
                keychain.save(timeTrackingDatabaseId, service: "NotionTimeTracking", account: "timeTrackingDatabaseId")
            }
            if let taskDatabaseId = self.globalSettings.TaskDatatbaseId.data(using: .utf8)
            {
                keychain.save(taskDatabaseId, service: "NotionTimeTracking", account: "taskDatabaseId")
            }

            DispatchQueue.main.async {
                // Log or handle UI updates here, if needed
                print("Keychain save operation completed.")
            }
        }
    }

}
