import Foundation
import SwiftUI
import KeychainSwift

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
        let keychain = KeychainSwift()
        keychain.set(globalSettings.apiKey, forKey: "apiKey")
        keychain.set(globalSettings.TimeTrackingDatatbaseId, forKey: "timeTrackingDatabaseId")
        keychain.set(globalSettings.TaskDatatbaseId, forKey: "taskDatabaseId")
        print("Keychain save operation completed.")
    }

}
