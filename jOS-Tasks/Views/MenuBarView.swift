import SwiftUI
import Combine
#if os(macOS)
struct MenubarView: View {
    @EnvironmentObject var notionController: NotionController
    @Binding var isMenuPresented: Bool
    
    let timeAdjustments = [-60, -45, -30, -15, -10, -5, 5, 10, 15, 30, 45, 60]
    @State private var selectedTimeAdjustment: Int? = nil
    
    private func handleTimeAdjustment(_ newValue: Int?) {
        if let min = newValue {
            notionController.updateCurrentTimerStartTime(minutes: min)
            DispatchQueue.main.async {
                selectedTimeAdjustment = nil // Reset the picker
            }
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                Button(
                    action: {
                        let url = notionController.currentOpenTimeEntries[0].attachedTask?.url
                        if (url != nil) {
                            openUrlInNotion(from: url!)
                            isMenuPresented = false
                        }
                        
                    }) {
                        Text(notionController.currentTimeEntry)
                            .foregroundColor(.white)
                        
                    }
                    .padding()
                    .buttonStyle(PlainButtonStyle())
                
                Spacer()
                Button(action: {
                    notionController.stopCurrentTimeEntry()
                }) {
                    Text("End")
                        .foregroundColor(.white)
                }
                .padding()
            }
            
            // New row of segmented buttons for time adjustments
                       HStack(spacing: 2) {
                           ForEach(timeAdjustments, id: \.self) { min in
                               Button(action: {
                                   notionController.updateCurrentTimerStartTime(minutes: min)
                               }) {
                                   Text("\(min < 0 ? "" : "+")\(min)")
                                       .frame(minWidth: 25, minHeight: 10)  // Reduced minimum width
                                       .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))  // Reduced padding
                                       .foregroundColor(.white)
                               }
                               //.background(min < 0 ? Color.red : Color(red: 0, green: 0.5, blue: 0))  // Darker green
                               .cornerRadius(8)
                           }
                       }
                       .padding(.top, 10)
            
            Button(action: {
                notionController.createNewTaskWithTimer()
                isMenuPresented = false
            }) {
                Text("Create New")
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    
            }
            .buttonStyle(PlainButtonStyle())
            .padding(10)
                    
            // Adding the List to display all task titles
            Divider()
                    
            ForEach(notionController.tasks, id: \.id) { task in
                MenuBarTaskRowView(task: task, isMenuPresented: $isMenuPresented)
            }
            
            
        }
        
    }
    
}




struct MenuBarTaskRowView: View {
    let task: Task
    @EnvironmentObject var notionController: NotionController
    @Binding var isMenuPresented: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Button("Done") { notionController.markTaskComplete(taskId: task.id)}.buttonStyle(ButtonStyle_Standard())
                Button(action: {
                    openUrlInNotion(from: task.url!)
                    isMenuPresented = false
                }) {
                    Text(task.title)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(task.properties?.ProjectName.formula.string ?? "")
                Spacer(minLength: 20) // Reserve a minimum space between the buttons
                Button("Start") {
                    openUrlInNotion(from: task.url!)
                    notionController.startNewTimeEntry(task: task)
                    isMenuPresented = false
                }
            }.frame(minWidth: 556)
        }
        .padding(.horizontal, 10)
        .cornerRadius(5)
        .padding(.vertical, 1)
    }
}
#endif
