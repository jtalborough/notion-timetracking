import Foundation

struct Task: Codable {
    var title: String {
        let temp = self.properties?.Task?.title?.first?.plain_text ?? ""
        return (temp)
    }
    var DoTime: String {
        let date = self.properties?.DoDate?.date?.start ?? ""
        
        if date.contains("T") {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let fullDate = isoFormatter.date(from: date) {
                let timeFormatter = DateFormatter()
                timeFormatter.locale = Locale(identifier: "en_US_POSIX")
                timeFormatter.dateFormat = "HH:mm"
                
                let timeString = timeFormatter.string(from: fullDate)
                return timeString
            }
            else {
                return String("")
            }
        }
        else {
            return String("")
        }
        
    }
    struct Properties: Codable {
        struct DateValue: Codable {
            let start: String?
            let end: String?
            let time_zone: String?
        }
        
        struct StatusValue: Codable {
            let name: String
            let id: String
            let color: String
        }
        
        struct FormulaValue: Codable {
            let string: String
            let type: String
        }
        
        struct RollupValue: Codable {
            let type: String
            let function: String
            let array: [String] // This could be more complex depending on the data
        }
        let ProjectName: ProjectName
        //let `Parent item`: RelationProperty?
        let Edited: TimeProperty?
        let Done: CheckboxProperty?
        let Tag: MultiSelectProperty?
       // let Start: DateProperty?
        let Cost: NumberProperty?
//        let Area: RollupProperty?
        let Status: StatusProperty?
        let TimeTracking: RelationProperty?
    // let `Sub-item`: RelationProperty?
        let DoDate: DateProperty?
        let Task: TitleProperty?
        let Time: NumberProperty?
        let Project: RelationProperty?
       // let `Project Status`: RollupProperty?
       // let `Work or Personal`: FormulaProperty?
        let URL: URLProperty?
        let Created: TimeProperty?
    }
    
    struct RelationProperty: Codable {
        let has_more: Bool
        let id: String
        let type: String
        let relation: [RelationObject] // Changed to a custom object to better represent the data.
    }
    
    struct RelationObject: Codable { // This is a new struct that represents individual relation objects.
        let id: String
        let name: String? // Add other fields as needed
    }
    struct TimeProperty: Codable {
        let type: String
        let id: String
        let last_edited_time: String?
        let created_time: String?
    }
    
    struct CheckboxProperty: Codable {
        let checkbox: Bool
        let id: String
        let type: String
    }
    
    struct MultiSelectProperty: Codable {
        let type: String
        let id: String
        let multi_select: [MultiSelectObject] // Change [String] to [MultiSelectObject]
    }

    struct MultiSelectObject: Codable { // New Struct
        let id: String
        let name: String
        // Add any other properties you expect to find in the multi_select dictionaries
    }
    
    struct DateProperty: Codable {
        let type: String
        let id: String
        let date: DateValue?
    }
    
    // DateObject Structure
    struct DateValue: Codable {
        let end: String?
        let start: String?
        let timeZone: String?
        
        enum CodingKeys: String, CodingKey {
            case end
            case start
            case timeZone = "time_zone"
        }
    }
    struct NumberProperty: Codable {
        let type: String
        let id: String
        let number: Double?
    }
    
    struct ProjectName: Codable {
        let formula: Formula
        let id: String
        let type: String
    }

    struct Formula: Codable {
        let string: String
        let type: String
    }
    
    struct StatusProperty: Codable {
        let type: String
        let id: String
        let status: StatusValue?
    }
    
    struct StatusValue: Codable {
        let id: String
        let name: String
        let color: String
    }
    
    
//    struct RollupProperty: Codable {
//        let type: String
//        let id: String
//        let rollup: RollupValue?
//    }
    
    struct TitleProperty: Codable {
        let title: [TextValue]?
    }
    
    struct TextValue: Codable {
        let plain_text: String?
    }
    
//    struct TextValue: Codable {
//        let href: String?
//        let text: Content?
//        let annotations: Annotations?
//        let type: String
//        let plain_text: String?
//    }
    
    struct Content: Codable {
        let content: String?
        let link: String?
    }
    
    struct Annotations: Codable {
        let color: String
        let underline: Bool
        let bold: Bool
        let code: Bool
        let strikethrough: Bool
        let italic: Bool
    }
    
//    struct FormulaProperty: Codable {
//        let type: String
//        let id: String
//        let formula: FormulaValue?
//    }
    
    struct URLProperty: Codable {
        let type: String
        let id: String
        let url: String?
    }
    
    let url: String?
    let parent: Parent?
    let archived: Bool?
    let last_edited_time: String?
    let object: String
 
    let public_url: String?
    let created_time: String?
    let properties: Properties?
    let created_by: CreatedBy?
    let last_edited_by: LastEditedBy?
    let id: String
    let icon: IconObject?
}



struct CreatedBy: Codable {
    let id: String
    let object: String
}

struct LastEditedBy: Codable {
    let id: String
    let object: String
}

struct IconObject: Codable {
    let id: String?
    // Add any other properties you expect to find in the icon dictionary
}
