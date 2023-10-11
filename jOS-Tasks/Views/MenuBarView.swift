import SwiftUI

#if os(macOS)
struct MenubarView: View {
    @EnvironmentObject var notionController: NotionController
    @Binding var isMenuPresented: Bool
    
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


struct MenuBarTaskRowView: View {
    let task: Task
    @EnvironmentObject var notionController: NotionController
    @Binding var isMenuPresented: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Button("Done") {
                    notionController.markTaskComplete(taskId: task.id)
                }
                Button(action: {
                    openUrlInNotion(from: task.url!)
                    isMenuPresented = false
                }) {
                    Text(task.title)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
                
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
        .foregroundColor(.white)
    }
}
#endif
