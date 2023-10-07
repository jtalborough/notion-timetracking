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
    var cancellables = Set<AnyCancellable>()
    
    var databaseId: String {
        return globalSettings.TimeTrackingDatatbaseId
    }
    let pollingInterval: TimeInterval = 15
    var retryCount: Int = 0
    
    init() {
        self.currentOpenTimeEntries = []
        self.startPolling()
    }
    
    func startPolling() {
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
    }
//    func startPolling() {
//        Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { _ in
//            self.GetOpenTasks()
//        }
//        Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { _ in
//            self.GetOpenTimeTickets()
//        }
//
//    }
    // writte a funciton for setting the stop time 5 min earlier
    func SetStopTime(numberOfMinBack: Int)
    {
            
        
    }
    
    func GetOpenTasks() {
        let filterParameters: [String: Any] = [
            "filter": [
                "and": [
                    [
                        "property": "Status",
                        "status": [
                            "equals": "Focus"
                        ]
                    ]
                ]
            ],
            "sorts": [
                    [
                        "property": "DoDate",
                        "direction": "descending"
                    ]
            ]
        ]
    // writte a funciton for setting the stop time 5 min earlier
        
//        let filterParameters: [String: Any] = [
//            "filter": [
//                "or": [
//                    [
//                        "and": [
//                            [
//                                "property": "DoDate",
//                                "is_empty": true
//                            ],
//                            [
//                                "or": [
//                                    [
//                                        "property": "Status",
//                                        "status": [
//                                            "equals": "Focus"
//                                        ]
//                                    ],
//                                    [
//                                        "property": "Status",
//                                        "status": [
//                                            "equals": "Active"
//                                        ]
//                                    ]
//                                ]
//                            ]
//                        ]
//                    ],
//                    [
//                        "and": [
//                            [
//                                "property": "DoDate",
//                                "date" : [
//                                    "on_or_before":
//                                    ]
//                            ],
//                            [
//                                "not": [
//                                    "or": [
//                                        [
//                                            "property": "Status",
//                                            "select": [
//                                                "equals": "Done"
//                                            ]
//                                        ],
//                                        [
//                                            "property": "Status",
//                                            "select": [
//                                                "equals": "Info"
//                                            ]
//                                        ],
//                                        [
//                                            "property": "Status",
//                                            "select": [
//                                                "equals": "Someday"
//                                            ]
//                                        ]
//                                    ]
//                                ]
//                            ]
//                        ]
//                    ],
//                    [
//                        "and": [
//                            [
//                                "property": "Parent item",
//                                "is_empty": false
//                            ],
//                            [
//                                "property": "Status",
//                                "select": [
//                                    "does_not_equal": "Done"
//                                ]
//                            ],
//                            [
//                                "property": "DoDate StartDate",
//                                "date": [
//                                    "on_or_before": "today"
//                                ]
//                            ]
//                        ]
//                    ]
//                ]
//            ]
//        ]

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

    func createNewTask() {
        // Set the default properties for the new task
        let properties: [String: Any] = [
            "Task": [
                "title": [
                    [
                        "text": [
                            "content": ""
                        ]
                    ]
                ]
            ],
            "Status": [
                "status": [
                    "name": "Focus"
                ]
            ]
        ]
        
        // Prepare the parameters for the API call
        let parameters: [String: Any] = [
            "properties": properties
        ]
        

        
        // Make the API call to create a new task
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

                    for entry in self.currentOpenTimeEntries {
                        self.updateAttachedTask(for: entry)
                    }
                } catch let decodeError {
                    print("Failed to decode JSON into TimeEntry array: \(decodeError)")
                }
            }
        }
        updateCurrentTimer()
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
                entry.attachedTask = try JSONDecoder().decode(Task.self, from: data)
                self.updateCurrentTimer()
            } catch {
                print("Error parsing JSON: \(error)")
            }
        }
    }

    func updateCurrentTimer() {
        if !currentOpenTimeEntries.isEmpty {
            let title = String(currentOpenTimeEntries[0].attachedTask?.properties?.Task?.title?[0].plain_text ?? "")
            
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
    }
    
    func startNewTimeEntry(task: Task) {
        startNewTimeEntry(taskId: task.id)
    }
    
    func startNewTimeEntry(taskId: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
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
