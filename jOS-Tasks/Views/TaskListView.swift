import SwiftUI

#if os(iOS)
struct TaskListView: View {
    @EnvironmentObject var notionController: NotionController
    @Environment(\.openURL) var openURL
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Current Time Entry")) {
                    Button(action: {
                        let urlString = notionController.currentOpenTimeEntries[0].url
                        if let url = URL(string: urlString ?? "") {
                            openURL(url)
                        }

                    }) {
                        Text(notionController.currentTimeEntry)
                    }
                }
                
                Section(header: Text("Tasks")) {
                    ForEach(notionController.tasks, id: \.id) { task in
                        TaskRowView(task: task)
                    }
                }
                
                Section {
                    Button("Create New Task") {
                        notionController.createNewTask()
                    }
                }
            }
                .listStyle(GroupedListStyle())
                .navigationBarTitle("Task List", displayMode: .inline)
        }
    }
}

struct TaskRowView: View {
    let task: Task
    @Environment(\.openURL) var openURL
    @EnvironmentObject var notionController: NotionController
    
    var body: some View {
        HStack {
            Text(task.title)
            Spacer()
            Button("Start") {
                notionController.startNewTimeEntry(task: task)
                let url = URL(string: task.url!)
                openURL(url!)
            }
        }
    }
}
#endif
