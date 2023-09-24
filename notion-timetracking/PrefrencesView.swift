import Foundation
import SwiftUI

struct PreferencesView: View {
    @Binding var showingPreferences: Bool
    @EnvironmentObject var globalSettings: GlobalSettings

    var body: some View {
        VStack {
            Form {
                TextField("API Key", text: $globalSettings.apiKey)
                TextField("Database ID", text: $globalSettings.databaseId)
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
            if let apiKeyData = self.globalSettings.apiKey.data(using: .utf8),
               let databaseIdData = self.globalSettings.databaseId.data(using: .utf8) {
                print("Data conversion successful")  // Add this line
                keychain.save(apiKeyData, service: "NotionTimeTracking", account: "apiKey")
                keychain.save(databaseIdData, service: "NotionTimeTracking", account: "databaseId")
            }

            DispatchQueue.main.async {
                // Log or handle UI updates here, if needed
                print("Keychain save operation completed.")
            }
        }
    }

}
