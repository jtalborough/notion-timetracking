import Foundation
import Alamofire
import SwiftyJSON
import SwiftUI

class NotionController : ObservableObject {
    //@ObservedObject var globalSettings = GlobalSettings() // Instantiate GlobalSettings
    let globalSettings = GlobalSettings.shared


    var accessToken: String {
        return globalSettings.apiKey // Use apiKey from GlobalSettings
    }
    var databaseId: String {
        return globalSettings.TimeTrackingDatatbaseId // Use TimeTrackingDatatbaseId from GlobalSettings
    }
    let pollingInterval: TimeInterval = 60.0 // 60 seconds
    var retryCount: Int = 0
    
    init() {
        queryOpenTasks()
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
        // Parse the JSON response to extract relevant task data
        // Update your app's state accordingly
    }
    
    func createNewTask(startTime: String, taskReference: String, projectReference: String) {
        // Implement API call to create a new task
    }
    
    func endExistingTask(taskId: String, endTime: String) {
        // Implement API call to end an existing task
    }
    
    func handleFailure() {
        // Implement exponential backoff for retries
        let delay = pow(2.0, Double(retryCount))
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            self.retryCount += 1
            self.queryOpenTasks()
        }
    }
}
