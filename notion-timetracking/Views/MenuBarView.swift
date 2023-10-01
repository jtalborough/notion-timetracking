import SwiftUI

struct MenubarView: View {
    @EnvironmentObject var notionController: NotionController
    @Environment(\.openURL) var openURL
    @Binding var isMenuPresented: Bool
    
    var body: some View {
        VStack {
                Button(action: {
                    let url = URL(string: notionController.currentOpenTimeEntries[0].url!)
                    openURL(url!)
                }) {
                    Text(notionController.currentTimeEntry)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(10)
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
    @Environment(\.openURL) var openURL
    @EnvironmentObject var notionController: NotionController
    @Binding var isMenuPresented: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Button(action: {
                    let url = URL(string: task.url!)
                    openURL(url!)
                    isMenuPresented = false
                }) {
                    Text(task.title)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer(minLength: 20) // Reserve a minimum space between the buttons
                
                Button("Start") {
                    notionController.startNewTimeEntry(task: task)
                    let url = URL(string: task.url!)
                    openURL(url!)
                    isMenuPresented = false
                }
            }.frame(minWidth: 556)
        }
        .padding(.horizontal, 10)
        .cornerRadius(5)
        .padding(.vertical, 1)
       //.background(Color(NSColor.windowBackgroundColor))

    }
}
