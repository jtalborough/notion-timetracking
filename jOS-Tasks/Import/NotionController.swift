// NotionController.swift

import Foundation
import SwiftUI
import SwiftyJSON
import MenuBarExtraAccess
import Combine

class NotionController: ObservableObject {
    let globalSettings = GlobalSettings.shared
    let notionAPI = NotionAPI()
    @Environment(\.openURL) var openURL
    
    @Published var tasks: [Task] = []
    @Published var currentOpenTimeEntries: [TimeEntry]
    @Published var currentTimeEntry: String = ""
    @Published var todayTotalTime: String = ""
    var cancellables = Set<AnyCancellable>()
    
    
    var databaseId: String {
        return globalSettings.TimeTrackingDatatbaseId
    }
    let pollingInterval: TimeInterval = 15
    var retryCount: Int = 0
    
    init() {
        self.currentOpenTimeEntries = []
    }
    
    
    func startPolling() {
        
        self.sumTimeEntriesForToday()
        self.GetOpenTimeTickets()
        self.GetOpenTasks()
        
        // First poll: No delay
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                self.GetOpenTasks()
            }
            .store(in: &cancellables)
        
        // Second poll: 15 seconds delay
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .delay(for: .seconds(15), scheduler: RunLoop.main)
            .sink { _ in
                self.GetOpenTimeTickets()
            }
            .store(in: &cancellables)
        // First poll: No delay
        Timer.publish(every: 120, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                self.sumTimeEntriesForToday()
            }
            .store(in: &cancellables)
    }

    
    func GetOpenTasks() {
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        let todayDateString = dateFormatter.string(from: Date())
        
        let filterParameters: [String: Any] = [
            "filter": [
                "and": [
                    [
                        "property": "DoDate",
                        "date": [
                            "on_or_before": todayDateString
                        ]
                    ],
                    [
                        "property": "Status",
                        "status": [
                            "equals": "ToDo"
                        ]
                    ]
                ]
            ],
            "sorts": [
                [
                    "property": "DoDate",
                    "direction": "ascending"
                ]
            ]
        ]
 
        
        notionAPI.queryDatabase(databaseId: globalSettings.TaskDatatbaseId, parameters: filterParameters) { (jsonResponse, error) in
            if let error = error {
                print("Error querying Notion database: \(error)")
                return
            }
            
            guard let json = jsonResponse else {
                print("No data received.")
                return
            }
            
            // Extract tasks and put them into an array (assuming they are in a key named "results")
            if let resultsArray = json["results"].array {
                do {
                    // Convert SwiftyJSON array to Data
                    let data = try JSONSerialization.data(withJSONObject: resultsArray.map { $0.object }, options: [])
                    
                    // Decode the data into an array of Task structs
                    do {
                        let tempTasks = try JSONDecoder().decode([Task].self, from: data)
                        self.updateTasks(newTasks: tempTasks)
                    } catch let error {
                        print("JSON decoding error: \(error)")
                        
                        if let underlyingError = error as? DecodingError {
                            switch underlyingError {
                            case .typeMismatch(let type, let context):
                                print("Type Mismatch: \(type) - \(context)")
                            case .keyNotFound(let key, let context):
                                print("Key Not Found: \(key) - \(context)")
                            case .valueNotFound(let type, let context):
                                print("Value Not Found: \(type) - \(context)")
                            case .dataCorrupted(let context):
                                print("Data Corrupted: \(context)")
                            default:
                                print("Unknown Decoding Error")
                            }
                        }
                    }
                    
                    // Now, 'tasks' is an array of Task structs
                    //print("Received tasks: \(self.tasks)")
                } catch let decodeError {
                    print("Failed to decode JSON Task array: \(decodeError)")
                }
            }
        }
    }

    func updateTasks(newTasks: [Task]) {
        DispatchQueue.main.async {
            self.tasks = newTasks
        }
    }
    
    func sumTimeEntriesForToday() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd" // For example, "2023-10-12"
        dateFormatter.timeZone = TimeZone.current

        // Get today's date without the time component
        let todayDateString = dateFormatter.string(from: Date())

        let filterParameters: [String: Any] = [
            "filter": [
                "and": [
                    ["property": "StartTime", "date": ["equals": todayDateString]],
                    ["property": "EndTime", "date": ["equals": todayDateString]]
                ]
            ]
        ]

        let dateFormatterParse = DateFormatter()
        dateFormatterParse.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        dateFormatterParse.locale = Locale(identifier: "en_US_POSIX")
        dateFormatterParse.timeZone = TimeZone.current

        notionAPI.queryDatabase(databaseId: globalSettings.TimeTrackingDatatbaseId, parameters: filterParameters) { (jsonResponse, error) in
            if let error = error {
                print("Error querying Notion database: \(error)")
                return
            }

            guard let json = jsonResponse else {
                print("No data received.")
                return
            }

            if let resultsArray = json["results"].array {
                var totalTime: TimeInterval = 0

                for result in resultsArray {
                    if let startTimeString = result["properties"]["StartTime"]["date"]["start"].string,
                       let endTimeString = result["properties"]["EndTime"]["date"]["start"].string {

                        if let startTime = dateFormatterParse.date(from: startTimeString),
                           let endTime = dateFormatterParse.date(from: endTimeString) {

                            let timeSpan = endTime.timeIntervalSince(startTime)
                            totalTime += timeSpan
                        } else {
                            print("Failed to convert date strings to Date objects")
                        }
                    }
                }

                // Parse the 'currentOpenTimeEntries[0].properties?.startTime?.date?.start' and calculate the time interval
                if(self.currentOpenTimeEntries.count > 0)
                {
                    if let currentOpenStartTimeString = self.currentOpenTimeEntries[0].properties?.startTime?.date?.start,
                       let currentOpenStartTime = dateFormatterParse.date(from: currentOpenStartTimeString) {
                        
                        let currentTime = Date()
                        let currentInterval = currentTime.timeIntervalSince(currentOpenStartTime)
                        totalTime += currentInterval
                    }
                }

                let roundedTotalTime = round(totalTime / 300) * 300 // Round to nearest 5 minutes (300 seconds)
                let hours = Int(roundedTotalTime) / 3600
                let minutes = (Int(roundedTotalTime) % 3600) / 60

                self.todayTotalTime = String("\(hours)h \(minutes)m")
                print("Total time for today (rounded to nearest 5 minutes): \(hours)h \(minutes)m")
                self.updateCurrentTimer()
            }
        }
    }



    func markTaskComplete(taskId: String) {
        // Set the default properties for the new task
        let properties: [String: Any] = [
            "Status": [
                "status": [
                    "name": "Done"
                ]
            ]
        ]
        
        // Prepare the parameters for the API call
        let parameters: [String: Any] = [
            "properties": properties
        ]
        

        // Make the API call to create a new task
        notionAPI.setPageDetails(pageId: taskId, parameters: parameters){ (jsonResponse, error) in
            if let error = error {
                print("Failed to create new task: \(error)")
                return
            }

            let json = JSON(jsonResponse )
            if let urlResponse = json["url"].string {
                let url = URL(string: urlResponse)
                self.openURL(url!)
            }
            self.GetOpenTasks()
        }
        
    }

    func createNewTaskWithTimer() {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let currentDateStr = dateFormatter.string(from: Date())

        let properties: [String: Any] = [
            "DoDate": [
                "date": [
                    "start": currentDateStr  // Insert the current date string here
                ]
            ]
        ]
        
        let parameters: [String: Any] = [
            "properties": properties
        ]

        notionAPI.createNewDatabaseEntry(databaseId: globalSettings.TaskDatatbaseId, parameters: parameters) { (jsonResponse, error) in
            if let error = error {
                print("Failed to create new task: \(error)")
                return
            }

            let json = JSON(jsonResponse ?? "")
            if let urlResponse = json["url"].string {
                openUrlInNotion(from: urlResponse)
            }
            if let taskId = json["id"].string {
                print("Successfully created new task. Task ID: \(taskId)")
                // Call the new startNewTimeEntry method with the task ID
                self.startNewTimeEntry(taskId: taskId)
            } else {
                print("Received empty or invalid JSON response.")
            }
        }
    }

    func createNewTask() {
        let parameters: [String: Any] = [
            "properties":  [
                "Status": [
                    "status": [
                        "name": "ToDo"
                    ]
                ]
            ]
        ]
        notionAPI.createNewDatabaseEntry(databaseId: globalSettings.TaskDatatbaseId, parameters: parameters) { (jsonResponse, error) in
            if let error = error {
                print("Failed to create new task: \(error)")
                return
            }

            let json = JSON(jsonResponse ?? "")
            if let urlResponse = json["url"].string {
                openUrlInNotion(from: urlResponse)
            }
            if let taskId = json["id"].string {
                print("Successfully created new task. Task ID: \(taskId)")
            } else {
                print("Received empty or invalid JSON response.")
            }
        }
        
    }
    func GetOpenTimeTickets() {
        let filterParameters: [String: Any] = [
            "filter": [
                "and": [
                    ["property": "StartTime", "date": ["is_not_empty": true]],
                    ["property": "EndTime", "date": ["is_empty": true]]
                ]
            ]
        ]


        notionAPI.queryDatabase(databaseId: globalSettings.TimeTrackingDatatbaseId, parameters: filterParameters) { (jsonResponse, error) in
            if let error = error {
                print("Error querying Notion database: \(error)")
                return
            }

            guard let json = jsonResponse else {
                print("No data received.")
                return
            }

            if let resultsArray = json["results"].array {
                do {
                    let data = try JSONSerialization.data(withJSONObject: resultsArray.map { $0.object }, options: [])
                    self.currentOpenTimeEntries = try JSONDecoder().decode([TimeEntry].self, from: data)
                    if(self.currentOpenTimeEntries.isEmpty) {
                        self.updateCurrentTimer()
                    } else {
                        for entry in self.currentOpenTimeEntries {
                            self.updateAttachedTask(for: entry)
                        }
                    }
                } catch let decodeError {
                    print("Failed to decode JSON into TimeEntry array: \(decodeError)")
                }
            }
        }
    }

    func updateAttachedTask(for entry: TimeEntry) {
        guard let unwrappedPageId = entry.properties?.tasksDB?.relation?.first?.id else {
            print("Page ID is nil.")
            return
        }

        notionAPI.getPageDetails(pageId: unwrappedPageId) { (jsonResponse, error) in
            if let error = error {
                print("Error fetching page details: \(error)")
                return
            }

            guard let jsonResponse = jsonResponse else {
                print("No JSON data received")
                return
            }

            do {
                let data = try JSONSerialization.data(withJSONObject: jsonResponse.object, options: [])
                let task = try JSONDecoder().decode(Task.self, from: data)
                if (task.properties?.Status?.status?.name == "Done") {
                    self.stopCurrentTimeEntry()
                } else {
                    entry.attachedTask = task
                }
                self.updateCurrentTimer()
                
            } catch {
                print("Error parsing JSON: \(error)")
            }
        }
    }

    func updateCurrentTimer() {
        if !currentOpenTimeEntries.isEmpty {
            var title = "No Title"
            if let firstEntry = currentOpenTimeEntries.first,
               let taskTitleArray = firstEntry.attachedTask?.properties?.Task?.title,
               !taskTitleArray.isEmpty,
               let taskTitle = taskTitleArray[0].plain_text,
               !taskTitle.isEmpty {
                // Now you have a non-empty taskTitle string to use
                title = taskTitle
            }
//            let title = "No Title"
//            if(!currentOpenTimeEntries[0].attachedTask?.properties?.Task?.title) {
//                let title = String(currentOpenTimeEntries[0].attachedTask?.properties?.Task?.title?[0].plain_text ?? "")
//            }
            
            if let startTimeString = currentOpenTimeEntries[0].properties?.startTime?.date?.start {
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withColonSeparatorInTimeZone, .withFractionalSeconds]
                
                if let startTime = dateFormatter.date(from: startTimeString) {
                    let currentTime = Date()
                    let timeInterval = currentTime.timeIntervalSince(startTime)
                    let timePassed = Int(timeInterval)
                    let hours = timePassed / 3600
                    let minutes = (timePassed % 3600) / 60
                    
                    if hours > 0 {
                        currentTimeEntry = "\(title) • \(hours)h \(minutes)m"
                    } else {
                        currentTimeEntry = "\(title) • \(minutes)m"
                    }
                } else {
                    currentTimeEntry = "\(title) • -"
                }
            } else {
                currentTimeEntry = "\(title) • -"
            }
        } else {
            currentTimeEntry = "No Current Task"
        }
        currentTimeEntry = String("\(currentTimeEntry) | \(todayTotalTime)")
    }
    
    func updateCurrentTimerStartTime(minutes: Int) {
        // Fetch the original start time of the current time entry (as a String)
        guard let originalStartTimeString = currentOpenTimeEntries.first?.properties?.startTime?.date?.start else {
            print("Failed to fetch original start time.")
            return
        }
        
        // Convert the original start time String to a Date object
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        dateFormatter.timeZone = TimeZone.current
        
        guard let originalStartTime = dateFormatter.date(from: originalStartTimeString) else {
            print("Failed to convert original start time to Date.")
            return
        }
        
        // Calculate the new start time based on the original start time and the number of minutes provided
        guard let newStartTime = Calendar.current.date(byAdding: .minute, value: minutes, to: originalStartTime) else {
            print("Failed to calculate new start time.")
            return
        }
        
        let newStartTimeString = dateFormatter.string(from: newStartTime)
        
        // Prepare the parameters to update the Notion database
        let updateParameters: [String: Any] = [
            "properties": [
                "StartTime": [
                    "date": [
                        "start": newStartTimeString
                    ]
                ]
            ]
        ]
        
        // Update the Notion database
        notionAPI.setPageDetails(pageId: currentOpenTimeEntries[0].id!, parameters: updateParameters) { (boolResponse, error) in
            if let error = error {
                print("Error updating start time: \(error)")
                return
            }
            
            if boolResponse {
                print("Successfully updated start time.")
                self.GetOpenTimeTickets()
            }
        }
    }

    func updateCurrentTimerEndTime(minutes: Int) {
        // Initialize Date object to current time
        let currentTime = Date()
        
        // Convert the original start time String to a Date object
        // This part will be kept as a fallback option
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        dateFormatter.timeZone = TimeZone.current
        
        // Calculate the new start time based on the current time and the number of minutes provided
        guard let newStartTime = Calendar.current.date(byAdding: .minute, value: minutes, to: currentTime) else {
            print("Failed to calculate new end time.")
            return
        }
        
        let newEndTimeString = dateFormatter.string(from: newStartTime)
        
        // Prepare the parameters to update the Notion database
        let updateParameters: [String: Any] = [
            "properties": [
                "EndTime": [
                    "date": [
                        "start": newEndTimeString
                    ]
                ]
            ]
        ]
        
        // Update the Notion database
            notionAPI.setPageDetails(pageId: currentOpenTimeEntries[0].id!, parameters: updateParameters) { (boolResponse, error) in
            if let error = error {
                print("Error updating start time: \(error)")
                return
            }
            
            if boolResponse {
                print("Successfully updated end time.")
                // self.stopCurrentTimeEntry()
                self.GetOpenTimeTickets()
            }
        }
        
    }



    func startNewTimeEntry(task: Task) {
        startNewTimeEntry(taskId: task.id)
    }
    
    func startNewTimeEntry(taskId: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        dateFormatter.timeZone = TimeZone.current
        
        let endTimeString = dateFormatter.string(from: Date())
    
        let tempParameters: [String: Any] = [
            "properties": [
                "Name": [
                    "title": [
                        [
                            "text": [
                                "content": "new entry"
                            ]
                        ]
                    ]
                ],
                "StartTime": [
                    "date": [
                        "start": endTimeString
                    ]
                ],
                "\u{1F4DC} TasksDB": [
                    "relation": [
                        ["id": taskId]
                    ]
                ]
            ]
        ]
        
        // Use a standard for-loop instead of ForEach
        for t in self.currentOpenTimeEntries {
            self.endTimeEntry(entry: t)
        }

        notionAPI.createNewDatabaseEntry(databaseId: globalSettings.TimeTrackingDatatbaseId, parameters: tempParameters) { (jsonResponse, error) in
            if let error = error {
                print("Failed to create new database entry: \(error)")
                return
            }
            
            if let jsonResponse = jsonResponse {
                print("Successfully created new database entry. JSON Response: \(jsonResponse)")
                self.GetOpenTimeTickets()
            } else {
                print("Received empty JSON response.")
            }
        }
    }

    func endTimeEntry(entry: TimeEntry)
    {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        dateFormatter.timeZone = TimeZone.current
        
        let endTimeString = dateFormatter.string(from: Date())
        
        let tempParameters: [String: Any] = [
            "properties": [
                "EndTime": [
                    "date": [
                        "start": endTimeString
                    ]
                ]
            ]
        ]
        
        notionAPI.setPageDetails(pageId: entry.id!, parameters: tempParameters) { (boolResponse, error) in
            if let error = error {
                print("Error fetching page details: \(error)")
                return
            }

            if boolResponse {
                print("true")
                return
            }
        }
    }
    
    func stopCurrentTimeEntry() {
        
        for t in self.currentOpenTimeEntries {
            self.endTimeEntry(entry: t)
        }
        self.GetOpenTimeTickets()
    }
    
    func handleFailure() {
        // Same as your existing implementation
    }
}
