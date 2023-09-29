//
//  TimeEntry.swift
//  notion-timetracking
//
//  Created by Jason T Alborough on 9/24/23.
//
import Foundation

//struct TimeEntry {
//    let id: String
//    let startTime: Date
//    var endTime: Date?  // Changed from 'let' to 'var'
//    let taskReference: String
//    let taskName: String
//    let isDone: Bool
//    
//    var timeUsed: TimeInterval {
//        // If endTime exists, calculate the time used between startTime and endTime
//        // Otherwise, calculate the time used from startTime to the current time
//        // Convert the time from seconds to minutes by dividing by 60
//        return (endTime ?? Date()).timeIntervalSince(startTime) / 60
//    }
//}

// Result Structure
class TimeEntry: Codable {
    let archived: Bool?
    let cover: String?
    let createdBy: User?
    let createdTime: String?
    let icon: String?
    let id: String?
    let lastEditedBy: User?
    let lastEditedTime: String?
    let object: String?
    let parent: Parent?
    let properties: Properties?
    let publicURL: String?
    let url: String?
    var attachedTask: Task?
    
    enum CodingKeys: String, CodingKey {
        case archived
        case cover
        case createdBy = "created_by"
        case createdTime = "created_time"
        case icon
        case id
        case lastEditedBy = "last_edited_by"
        case lastEditedTime = "last_edited_time"
        case object
        case parent
        case properties
        case publicURL = "public_url"
        case url
    }
}

// Properties Structure
struct Properties: Codable {
    let createdTime: CreatedTime?
    let done: Done?
    let endTime: EndTime?
    let name: Name?
    let startTime: StartTime?
    let tasksDB: TasksDB?
    
    enum CodingKeys: String, CodingKey {
        case createdTime = "Created Time"
        case done = "Done"
        case endTime = "EndTime"
        case name = "Name"
        case startTime = "StartTime"
        case tasksDB = "\u{1F4DC} TasksDB"
    }
}
// User Structure
struct User: Codable {
    let id: String?
    let object: String?
}

// Parent Structure
struct Parent: Codable {
    let databaseID: String?
    let type: String?
    
    enum CodingKeys: String, CodingKey {
        case databaseID = "database_id"
        case type
    }
}

// CreatedTime Structure
struct CreatedTime: Codable {
    let createdTime: String?
    let id: String?
    let type: String?
    
    enum CodingKeys: String, CodingKey {
        case createdTime = "created_time"
        case id
        case type
    }
}

// Checkbox Type
struct Done: Codable {
    let checkbox: Bool?
    let id: String?
    let type: String?
}

// Date Type
struct EndTime: Codable {
    let date: String?
    let id: String?
    let type: String?
}

struct StartTime: Codable {
    let date: DateObject?
    let id: String?
    let type: String?
}

// DateObject Structure
struct DateObject: Codable {
    let end: String?
    let start: String?
    let timeZone: String?
    
    enum CodingKeys: String, CodingKey {
        case end
        case start
        case timeZone = "time_zone"
    }
}

// Name Structure
struct Name: Codable {
    let id: String?
    let title: [Title]?
    let type: String?
}

// Title Structure
struct Title: Codable {
    let annotations: Annotations?
    let plainText: String?
    let text: TextType?
    let type: String?
    
    enum CodingKeys: String, CodingKey {
        case annotations
        case plainText = "plain_text"
        case text
     
        case type
    }
}
struct TextType: Codable {
    let someKey: String?
}

// Annotations Structure
struct Annotations: Codable {
    let bold: Bool?
    let code: Bool?
    let color: String?
    let italic: Bool?
    let strikethrough: Bool?
    let underline: Bool?
}

 
//struct Text: Codable {
//    let content: String?
//    let link: String?
//}

// TasksDB Structure
struct TasksDB: Codable {
    let hasMore: Bool?
    let id: String?
    let relation: [Relation]?
    let type: String?
    
    enum CodingKeys: String, CodingKey {
        case hasMore = "has_more"
        case id
        case relation
        case type
    }
}

// Relation Structure
struct Relation: Codable {
    let id: String?
}
