import SwiftUI

struct MenubarView: View {
    @EnvironmentObject var notionController: NotionController

    var body: some View {
        VStack {
//            HStack {
//                if let {
//                    // ... (existing VStacks)
//                } else {
//                    Text("No current task.")
//                }
//            }
//            .padding()
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
            //.background(Color(NSColor.windowBackgroundColor))
            
            // Adding the List to display all task titles
            Divider()
                        
            ForEach(notionController.tasks,id: \.id) { task in
                MenuBarTaskRowView(task: task)
            }
        }
    }
}

struct MenuBarTaskRowView: View {
    let task: Task
    @Environment(\.openURL) var openURL
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Button(action: {
                    let url = URL(string: task.url!)
                    openURL(url!)
                }) {
                    Text(task.title)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer(minLength: 20) // Reserve a minimum space between the buttons
                
                Button("Start") {
                    // Your action code here
                }
            }.frame(minWidth: 556)
        }
        .padding(.horizontal, 10)
        .cornerRadius(5)
        .padding(.vertical, 1)




    }
}
