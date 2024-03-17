import SwiftUI
import Combine
#if os(macOS)
struct MenubarView: View {
    @EnvironmentObject var notionController: NotionController
    @Binding var isMenuPresented: Bool
    
    let timeAdjustments = [-60, -45, -30, -15, -10, -5, 5, 10, 15, 30, 45, 60]
    @State private var selectedTimeAdjustment: Int? = nil
        
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    if(notionController.currentOpenTimeEntries.count > 0) {
                        if let url = notionController.currentOpenTimeEntries[0].attachedTask?.url {
                            openUrlInNotion(from: url)
                            isMenuPresented = false
                        }
                    }
                }) {
                    Text(notionController.currentTimeEntry)
                        .font(.title) // Makes the font size larger, suitable for titles
                        .fontWeight(.bold) // Makes the text bold
                        .padding() // Adjust padding as needed
                }
                .buttonStyle(PlainButtonStyle())
                Spacer()
                Button("Done", action: {
                    let task = notionController.currentOpenTimeEntries[0].attachedTask
                    let timeEntry = notionController.currentOpenTimeEntries[0]
                    notionController.endTimeEntry(entry: timeEntry)
                    notionController.markTaskComplete(taskId: task!.id)
                }).buttonStyle(ButtonStyle_Red())
                Button("End", action: { notionController.stopCurrentTimeEntry() }).buttonStyle(ButtonStyle_Standard())
            }.padding(10)
            // Adding the List to display all task titles
            Divider().padding(10)
            
            Text("Adjust Start Time")
                        .font(.headline) // Optional: Adjust the font style as needed
                        .padding(0) // Optional: Adjust padding as needed

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
            }.padding(10)

            Text("Adjust End Time")
                        .font(.headline) // Optional: Adjust the font style as needed
                        .padding(0) // Optional: Adjust padding as needed

            HStack(spacing: 2) {
                ForEach(timeAdjustments, id: \.self) { min in
                    Button(action: {
                            notionController.updateCurrentTimerEndTime(minutes: min)
                         }) {
                           Text("\(min < 0 ? "" : "+")\(min)")
                               .frame(minWidth: 25, minHeight: 10)  // Reduced minimum width
                               .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))  // Reduced padding
                               .foregroundColor(.white)
                   }
                       //.background(min < 0 ? Color.red : Color(red: 0, green: 0.5, blue: 0))  // Darker green
                   .cornerRadius(8)
                 }
             }.padding(10)
            Divider()
            
            HStack {
                Spacer()  // Pushes the following items to the right
                
                Button("New Timed") { notionController.createNewTaskWithTimer(); isMenuPresented = false }
                    .buttonStyle(ButtonStyle_Standard())
                    .padding(1)
                
                Button("New Inbox") { notionController.createNewTask(); isMenuPresented = false }
                    .buttonStyle(ButtonStyle_Standard())
                    
            }.padding(10)


                    
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
                Button("Done") { notionController.markTaskComplete(taskId: task.id)}.buttonStyle(ButtonStyle_Red())
                Button(action: {
                    openUrlInNotion(from: task.url!)
                    isMenuPresented = false
                }) {
                    Text(String("\(task.DoTime) \(task.title)"))
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(task.properties?.ProjectName.formula.string ?? "")
                Spacer(minLength: 20) // Reserve a minimum space between the buttons
                Button("Start") {
                    openUrlInNotion(from: task.url!)
                    notionController.startNewTimeEntry(task: task)
                    isMenuPresented = false
                }.buttonStyle(ButtonStyle_Standard())
            }.frame(minWidth: 700)
        }
        .padding(.horizontal, 10)
        .cornerRadius(5)
        .padding(.vertical, 1)
    }
}
#endif
