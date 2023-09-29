import Foundation
import Alamofire
import SwiftyJSON
import SwiftUI

class NotionControllerOld : ObservableObject {
    //@ObservedObject var globalSettings = GlobalSettings() // Instantiate GlobalSettings
    let globalSettings = GlobalSettings.shared
    @Published var currentOpenTimeEntry: TimeEntry?  // Add this line to hold the current open task
    

    var accessToken: String {
        return globalSettings.apiKey // Use apiKey from GlobalSettings
    }
    var databaseId: String {
        return globalSettings.TimeTrackingDatatbaseId // Use TimeTrackingDatatbaseId from GlobalSettings
    }
    let pollingInterval: TimeInterval = 60.0 // 60 seconds
    var retryCount: Int = 0
    
    init() {
        self.startPolling()
        
        
    }
    
    func startPolling() {
        Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { _ in
            self.queryOpenTasks()
        }
    }
    
    func queryOpenTasks() {
            let headers: HTTPHeaders = [
                "Authorization": "Bearer \(accessToken)",
                "Notion-Version": "2022-06-28"
            ]
            
            let parameters: [String: Any] = [
                "filter": [
                    "and": [
                        ["property": "StartTime", "date": ["is_not_empty": true]],
                        ["property": "EndTime", "date": ["is_empty": true]]
                    ]
                ]
            ]
        let url = "https://api.notion.com/v1/databases/\(databaseId)/query"

            print("Debug: Full URL: \(url)")  // Debugging statement
            print("Debug: Headers: \(headers)")  // Debugging statement
            print("Debug: Parameters: \(parameters)")  // Debugging statement
        
            
            print("Debug: Starting API call to query open tasks.") // Debugging statement
            
        AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    print("Debug: API call successful. Received JSON: \(json)") // Debugging statement
                    self.parseOpenTasks(json: json)
                    self.retryCount = 0 // Reset retry count on successful request
                case .failure(let error):
                    print("Debug: API call failed. Error: \(error)") // Debugging statement
                    self.handleFailure()
                }
            }
        }
    
    func parseOpenTasks(json: JSON) {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        if(json["results"].arrayValue.isEmpty)
        {
            let newStartTime = Date() // Current time
            let newEndTime: Date? = nil
            let newTaskReference = "No Task Reference"
            let newTaskName = "No Task"
            let newIsDone = false

           // self.currentOpenTimeEntry = TimeEntry(id: UUID().uuidString, startTime: newStartTime, endTime: newEndTime, taskReference: newTaskReference, taskName: newTaskName, isDone: newIsDone)

        
        }
        for result in json["results"].arrayValue {
            let id = result["id"].stringValue
            let properties = result["properties"]
            
            guard let startTimeString = properties["StartTime"]["date"]["start"].string,
                  let startTime = dateFormatter.date(from: startTimeString),
                  let taskReference = properties["📜 TasksDB"]["relation"].array?.first?["id"].string
            else {
                print("Debug: Missing or invalid fields in task data.")
                return
            }
            
            let endTimeString = properties["EndTime"]["date"].string
            let endTime = endTimeString != nil ? dateFormatter.date(from: endTimeString!) : nil
            let isDone = properties["Done"]["checkbox"].boolValue
            
            fetchTaskDetails(taskID: taskReference) { fetchedTaskName in
                let taskName = fetchedTaskName ?? "Unknown Task"
                
                // self.currentOpenTimeEntry = TimeEntry(id: id, startTime: startTime, endTime: endTime, taskReference: taskReference, taskName: taskName, isDone: isDone)
                
//                // Debug statement to log the details of the newly created TimeEntry object
//                if let currentOpenTimeEntry = self.currentOpenTimeEntry {
////                    print("Debug: Created new TimeEntry with the following details:")
////                    print("Start Time: \(currentOpenTimeEntry.startTime)")
////                    print("End Time: \(String(describing: currentOpenTimeEntry.endTime))")  // Using String(describing:) to handle optional
////                    print("Task Reference: \(currentOpenTimeEntry.taskReference)")
////                    print("Task Name: \(currentOpenTimeEntry.taskName)")
////                    print("Is Done: \(currentOpenTimeEntry.isDone)")
////                    print("Time Used: \(currentOpenTimeEntry.timeUsed) seconds")
//                } else {
//                    print("Debug: currentOpenTimeEntry is nil.")
//                }
            }
        }
    }


    func fetchTaskDetails(taskID: String, completion: @escaping (String?) -> Void) {
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(accessToken)",
            "Notion-Version": "2021-08-16"
        ]
        
        let url = "https://api.notion.com/v1/pages/\(taskID)"
        
        AF.request(url, headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                let json = JSON(value)
                print("Debug: Received JSON from fetchTaskDetails: \(json)") // Debugging the received JSON
                
                if let title = json["properties"]["Task"]["title"][0]["text"]["content"].string {
                    print("Debug: Successfully fetched title: \(title)") // Debugging successful title fetch
                    completion(title)
                } else {
                    print("Debug: Missing or invalid title in task details.")
                    print("Debug: 'properties' field in JSON: \(json["properties"])") // Debugging the 'properties' field
                    completion(nil)
                }
                
            case .failure(let error):
                print("Debug: API call failed with error: \(error)")
                print("Debug: Response received: \(String(describing: response.response))") // Debugging the HTTP response
                print("Debug: Response data: \(String(describing: response.data))") // Debugging the received data
                completion(nil)
            }
        }
    }


    
    func createNewTask(startTime: String, taskReference: String, projectReference: String) {
        // Implement API call to create a new task
    }
    
    func stopCurrentTimeEntry() {
        guard var currentEntry = currentOpenTimeEntry else {
            print("Debug: No open time entry to stop.")
            return
        }
        
        // Update the endTime to the current time
       // currentEntry.endTime = Date()
        
        // Make an API call to update the endTime in your database
        // Assuming you have a function updateTaskInDatabase that takes a TimeEntry object and updates it
        updateTaskInDatabase(timeEntry: currentEntry) { success in
            if success {
                // Update the local currentOpenTimeEntry
                self.currentOpenTimeEntry = currentEntry
                
                print("Debug: Successfully stopped the time entry.")
                print("End Time: \(String(describing: currentEntry))")
                print("Time Used: \(currentEntry) seconds")
            } else {
                print("Debug: Failed to stop the time entry.")
            }
        }
    }
    
    func updateTaskInDatabase(timeEntry: TimeEntry, completion: @escaping (Bool) -> Void) {
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(accessToken)",
            "Notion-Version": "2021-08-16",
            "Content-Type": "application/json"
        ]
        
        let url = "https://api.notion.com/v1/pages/\(timeEntry.id)"
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        //let endTimeString = dateFormatter.string(from: timeEntry.endTime ?? Date())

        
//        let parameters: [String: Any] = [
//            "properties": [
//                "EndTime": [
//                    "date": [
//                        "start": endTimeString
//                    ]
//                ]
//            ]
//        ]
        
//        AF.request(url, method: .patch, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
//            switch response.result {
//            case .success:
//                print("Debug: Successfully updated the endTime in the database.")
//                completion(true)
//                self.queryOpenTasks()
//                
//            case .failure(let error):
//                print("Debug: Failed to update the endTime in the database. Error: \(error)")
//                completion(false)
//            }
//        }
//    }


    
    func handleFailure() {
        // Implement exponential backoff for retries
        let delay = pow(2.0, Double(retryCount))
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            self.retryCount += 1
            self.queryOpenTasks()
        }
    }
}
