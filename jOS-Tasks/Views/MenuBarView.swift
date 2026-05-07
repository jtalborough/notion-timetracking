import SwiftUI
import Combine
#if os(macOS)

struct MenubarView: View {
    @EnvironmentObject var notionController: NotionController
    @Binding var isMenuPresented: Bool
    @State private var searchText: String = ""

    let timeAdjustments = [-60, -45, -30, -15, -10, -5, 5, 10, 15, 30, 45, 60]

    // Tasks filtered by search text
    private var filteredTasks: [Task] {
        guard !searchText.isEmpty else { return notionController.tasks }
        return notionController.tasks.filter { task in
            task.title.localizedCaseInsensitiveContains(searchText) ||
            task.properties?.ProjectName.formula.string.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    // Tasks grouped by project name, sorted: named projects first (alphabetically), then ungrouped
    private var groupedTasks: [(project: String, tasks: [Task])] {
        var groups: [String: [Task]] = [:]
        for task in filteredTasks {
            let project = task.properties?.ProjectName.formula.string ?? ""
            let key = project.isEmpty ? "" : project
            groups[key, default: []].append(task)
        }
        let namedKeys = groups.keys.filter { !$0.isEmpty }.sorted()
        let orderedKeys = namedKeys + (groups[""] != nil ? [""] : [])
        return orderedKeys.map { key in (project: key, tasks: groups[key]!) }
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Header
            VStack(spacing: 6) {
                HStack(alignment: .center, spacing: 10) {
                    Button(action: {
                        if let url = notionController.currentOpenTimeEntries.first?.attachedTask?.url {
                            openUrlInNotion(from: url)
                            isMenuPresented = false
                        }
                    }) {
                        Text(notionController.currentTimeEntry)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    if notionController.currentOpenTimeEntries.count > 0 {
                        Button("Done") {
                            let task = notionController.currentOpenTimeEntries[0].attachedTask
                            let timeEntry = notionController.currentOpenTimeEntries[0]
                            notionController.endTimeEntry(entry: timeEntry)
                            notionController.markTaskComplete(taskId: task!.id)
                        }
                        .buttonStyle(
                            PillButtonStyle(
                                color: Color(red: 0.7, green: 0.1, blue: 0.1),
                                labelColor: .white
                            )
                        )

                        Button("End") {
                            notionController.stopCurrentTimeEntry()
                        }
                        .buttonStyle(PillButtonStyle(color: Color.primary.opacity(0.15)))
                    }
                }

                HStack(spacing: 8) {
                    Spacer()
                    Button("+ Timed Task") {
                        notionController.createNewTaskWithTimer()
                        isMenuPresented = false
                    }
                    .buttonStyle(PillButtonStyle(color: Color.accentColor.opacity(0.2)))

                    Button("+ Inbox") {
                        notionController.createNewTask()
                        isMenuPresented = false
                    }
                    .buttonStyle(PillButtonStyle(color: Color.primary.opacity(0.1)))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            // MARK: - Time Adjustments
            VStack(spacing: 6) {
                TimeAdjustRow(label: "Start", adjustments: timeAdjustments) { min in
                    notionController.updateCurrentTimerStartTime(minutes: min)
                }
                TimeAdjustRow(label: "End", adjustments: timeAdjustments) { min in
                    notionController.updateCurrentTimerEndTime(minutes: min)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // MARK: - Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("Search tasks or projects…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            // MARK: - Task List (grouped)
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    if groupedTasks.isEmpty {
                        Text(searchText.isEmpty ? "No tasks" : "No results")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(groupedTasks, id: \.project) { group in
                            Section {
                                ForEach(group.tasks, id: \.id) { task in
                                    MenuBarTaskRowView(task: task, isMenuPresented: $isMenuPresented)
                                    Divider().padding(.leading, 14)
                                }
                            } header: {
                                if !group.project.isEmpty {
                                    HStack {
                                        Text(group.project)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 5)
                                    .background(Color(NSColor.windowBackgroundColor))
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            // Fills remaining vertical space; scrolls when content overflows
            .frame(minHeight: 60, maxHeight: .infinity)
        }
        .frame(width: 720, height: 850)
    }
}

// MARK: - Time Adjust Row

struct TimeAdjustRow: View {
    let label: String
    let adjustments: [Int]
    let onTap: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 32, alignment: .leading)

            HStack(spacing: 3) {
                ForEach(adjustments, id: \.self) { min in
                    Button(action: { onTap(min) }) {
                        Text("\(min < 0 ? "" : "+")\(min)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(min < 0
                                          ? Color(red: 0.65, green: 0.1, blue: 0.1)
                                          : Color(red: 0.1, green: 0.45, blue: 0.2))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

// MARK: - Task Row

struct MenuBarTaskRowView: View {
    let task: Task
    @EnvironmentObject var notionController: NotionController
    @Binding var isMenuPresented: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button("Done") {
                notionController.markTaskComplete(taskId: task.id)
            }
            .buttonStyle(
                PillButtonStyle(
                    color: Color(red: 0.6, green: 0.1, blue: 0.1),
                    labelColor: .white
                )
            )

            Button(action: {
                openUrlInNotion(from: task.url!)
                isMenuPresented = false
            }) {
                Text(task.title)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .buttonStyle(PlainButtonStyle())

            Button("Start") {
                openUrlInNotion(from: task.url!)
                notionController.startNewTimeEntry(task: task)
                isMenuPresented = false
            }
            .buttonStyle(PillButtonStyle(color: Color.accentColor, labelColor: .white))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Pill Button Style

struct PillButtonStyle: ButtonStyle {
    let color: Color
    var labelColor: Color = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(labelColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(configuration.isPressed ? color.opacity(0.6) : color)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#endif
