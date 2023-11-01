// NotionAPI.swift

import Foundation
import Alamofire
import SwiftyJSON

class NotionAPI {
    let debug = false
    let globalSettings = GlobalSettings.shared
    
    
    var accessToken: String {
        return globalSettings.apiKey // Use apiKey from GlobalSettings
    }
    
    init(){
        
    }
    
    func queryDatabase(databaseId: String, parameters: [String: Any], completion: @escaping (JSON?, Error?) -> Void) {
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(accessToken)",
            "Notion-Version": "2022-06-28"
        ]
        
        let url = "https://api.notion.com/v1/databases/\(databaseId)/query"
        
        if debug {
            print("Debug: Starting API request to \(url)")
            print("Debug: header \(headers)")
            
            print("Debug: Parameters: \(parameters)")
        }
        
        AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
            
            if self.debug {
                print("Debug: Response received.")
                print("Debug: HTTP Status Code: \(String(describing: response.response?.statusCode))")
                print("Debug: Response Data: \(String(describing: response.data))")
            }
            
            switch response.result {
            case .success(let value):
                if self.debug {
                    print("Debug: API call successful. Parsed JSON: \(value)")
                }
                completion(JSON(value), nil)
            case .failure(let error):
                if self.debug {
                    print("Debug: API call failed. Error: \(error)")
                }
                completion(nil, error)
            }
        }
    }
    
    func getPageDetails(pageId: String, completion: @escaping (JSON?, Error?) -> Void) {
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(accessToken)",
            "Notion-Version": "2022-06-28"
        ]
        let url = "https://api.notion.com/v1/pages/\(pageId)"
        AF.request(url, headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                completion(JSON(value), nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
    
    func setPageDetails(pageId: String, parameters: [String: Any], completion: @escaping (Bool, Error?) -> Void) {
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(accessToken)",
            "Notion-Version": "2022-06-28"
        ]
        
        let url = "https://api.notion.com/v1/pages/\(pageId)"
        AF.request(url, method: .patch, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
            switch response.result {
            case .success:
                completion(true, nil)
            case .failure(let error):
                completion(false, error)
            }
            if self.debug {
                print("Debug: Response received.")
                print("Debug: HTTP Status Code: \(String(describing: response.response?.statusCode))")
                print("Debug: Response Data: \(String(describing: response.data))")
            }
        }
        
    }

    func createNewDatabaseEntry(databaseId: String, parameters: [String: Any], completion: @escaping (JSON?, Error?) -> Void) {
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(accessToken)",
            "Notion-Version": "2022-06-28"
        ]
        
        let url = "https://api.notion.com/v1/pages"
        
        var payload: [String: Any] = [
            "parent": ["database_id": databaseId]
        ]
        
        payload.merge(parameters) { (_, new) in new }
        
        if debug {
            print("Debug: Starting API request to \(url)")
            print("Debug: header \(headers)")
            print("Debug: Parameters: \(payload)")
        }
        
        AF.request(url, method: .post, parameters: payload, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
            
            if self.debug {
                print("Debug: Response received.")
                print("Debug: HTTP Status Code: \(String(describing: response.response?.statusCode))")
                print("Debug: Response Data: \(String(describing: response.data))")
            }
            
            switch response.result {
            case .success(let value):
                if self.debug {
                    print("Debug: API call successful. Parsed JSON: \(value)")
                }
                completion(JSON(value), nil)
            case .failure(let error):
                if self.debug {
                    print("Debug: API call failed. Error: \(error)")
                }
                completion(nil, error)
            }
        }
    }
}
