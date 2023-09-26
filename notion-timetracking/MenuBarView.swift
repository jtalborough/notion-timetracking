
import SwiftUI

struct MenubarView: View {
    @EnvironmentObject var notionController: NotionController
    
    var body: some View {
        HStack {
            if let currentEntry = notionController.currentOpenTimeEntry {
                VStack(alignment: .leading) {
                    Text("Current Task:")
                        .font(.headline)
                    Text("\(currentEntry.taskName)")
                        .font(.title)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(String(format: "%.0f", currentEntry.timeUsed)) minutes")
                        .font(.title)
                    Button(action: {
                        // Your logic for ending the time entry
                        notionController.updateTaskInDatabase(timeEntry: currentEntry) { success in
                            if success {
                                print("Debug: Successfully updated the task in the database.")
                            } else {
                                print("Debug: Failed to update the task in the database.")
                            }
                        }
                    }) {
                        Text("End")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                }
            } else {
                Text("No current task.")
                    .font(.title)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
