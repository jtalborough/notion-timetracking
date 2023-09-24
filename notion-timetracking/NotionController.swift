import Foundation
import Alamofire
import SwiftyJSON
import SwiftUI

class NotionController {
    @ObservedObject var globalSettings = GlobalSettings() // Instantiate GlobalSettings
    
    var accessToken: String {
        return globalSettings.apiKey // Use apiKey from GlobalSettings
    }
    var databaseId: String {
        return globalSettings.TimeTrackingDatatbaseId // Use TimeTrackingDatatbaseId from GlobalSettings
    }
    let pollingInterval: TimeInterval = 60.0 // 60 seconds
    var retryCount: Int = 0
    
    init() {
        // Initialize and start polling
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
            "Notion-Version": "2021-08-16"
        ]
        
        let parameters: [String: Any] = [
            "filter": [
                "and": [
                    ["property": "Start Time", "date": ["is_not_empty": true]],
                    ["property": "End Time", "date": ["is_empty": true]]
                ]
            ]
        ]
        
        AF.request("https://api.notion.com/v1/databases/\(databaseId)/query", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                let json = JSON(value)
                self.parseOpenTasks(json: json)
                self.retryCount = 0 // Reset retry count on successful request
            case .failure(let error):
                print("Error: \(error)")
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
