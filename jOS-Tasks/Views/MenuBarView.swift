import SwiftUI

#if os(macOS)
struct MenubarView: View {
    @EnvironmentObject var notionController: NotionController
    @Binding var isMenuPresented: Bool
    
    var body: some View {
        VStack {
            HStack {
                if(notionController.currentOpenTimeEntries.count > 0) {
                    Text("\(String(notionController.currentTimeEntry))")
                        .font(.title)
                }
                else {
                    Text("No Current Task")
                        .font(.title)
                }
                
                Spacer()

                Button(action: {
                    notionController.stopCurrentTimeEntry()
                    }) {
                    Text("End")
                        .font(.title)
                        .foregroundColor(.white)
                    }
                    .padding()
                }
                Button(action: {
                   notionController.createNewTask()
                    isMenuPresented = false
                }) {
                    Text("Create New")
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(10)
                        
            // Adding the List to display all task titles
            Divider()
                        
            ForEach(notionController.tasks,id: \.id) { task in
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
                Button(action: {
                    openUrlInNotion(from: task.url!)
                    isMenuPresented = false
                }) {
                    Text(task.title)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer(minLength: 20) // Reserve a minimum space between the buttons
                Button("Done") {
                    notionController.markTaskComplete(taskId: task.id)
                }
                
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
