//
//  TimeEntry.swift
//  notion-timetracking
//
//  Created by Jason T Alborough on 9/24/23.
//
import Foundation

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
    init(
        archived: Bool? = nil,
        cover: String? = nil,
        createdBy: User? = nil,
        createdTime: String? = nil,
        icon: String? = nil,
        id: String? = nil,
        lastEditedBy: User? = nil,
        lastEditedTime: String? = nil,
        object: String? = nil,
        parent: Parent? = nil,
        properties: Properties? = nil,
        publicURL: String? = nil,
        url: String? = nil,
        attachedTask: Task? = nil
        )
    {
        self.archived = archived
        self.cover = cover
        self.createdBy = createdBy
        self.createdTime = createdTime
        self.icon = icon
        self.id = id
        self.lastEditedBy = lastEditedBy
        self.lastEditedTime = lastEditedTime
        self.object = object
        self.parent = parent
        self.properties = properties
        self.publicURL = publicURL
        self.url = url
        self.attachedTask = attachedTask
    }
}

// Properties Structure
struct Properties: Codable {
    let createdTime: CreatedTime?
    let endTime: EndTime?
    let name: Name?
    let startTime: StartTime?
    let tasksDB: TasksDB?

    enum CodingKeys: String, CodingKey {
        case createdTime = "Created Time"
        case endTime = "EndTime"
        case name = "Name"
        case startTime = "StartTime"
        case tasksDB = "\u{1F4DC} TasksDB"
    }

    init(
        createdTime: CreatedTime? = nil,
        done: Done? = nil,
        endTime: EndTime? = nil,
        name: Name? = nil,
        startTime: StartTime? = nil,
        tasksDB: TasksDB? = nil
    ) {
        self.createdTime = createdTime
        self.endTime = endTime
        self.name = name
        self.startTime = startTime
        self.tasksDB = tasksDB
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
    let date: DateObject?
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
