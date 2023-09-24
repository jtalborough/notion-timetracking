//
//import EventKit
//import SwiftUI
//
//class NotionController : ObservableObject {
//    
//    init(){
//        print("Debug: Initialize")
//        // checkCalendarAuthorizationStatus()
//        //timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) {
//        //    timer in self.getEvents()
//        //}
//    }
//    //var timer = Timer()
//    let eventCalander = EKEventStore()
//    @Published var MyEvents = [Events]()
//    @Published var NextEvent: String = ""
//    @Published var tryList = [Events]()
//    @Published var active: Bool = true
//
//    func getNextEventTitle() -> String {
//        var title: String
//        let now = Date()
//
//        // Find the current event, if any
//        let currentEvent = MyEvents.first { event in
//            let eventStartTime = event.Event.startDate!
//            let eventEndTime = event.Event.endDate!
//            return now >= eventStartTime && now <= eventEndTime
//        }
//
//        // Find the next event, if any
//        let nextEvent = MyEvents.first { event in
//            return event.Event.startDate! > now
//        }
//
//        // Calculate time difference for the next event
//        let nextEventTimeDifference = nextEvent != nil ? Calendar.current.dateComponents([.minute], from: now, to: nextEvent!.Event.startDate!).minute ?? 0 : nil
//
//        if let currentEvent = currentEvent {
//            title = currentEvent.Title
//
//            // Check if there's a next event starting within 10 minutes
//            if let nextEvent = nextEvent, nextEventTimeDifference! <= 10 {
//                title = "🔔 " + nextEvent.Title + " • " + nextEvent.RelativeStartTime
//            }
//        } else if let nextEvent = nextEvent {
//            // Prepend a bell icon if the next event starts within 10 minutes
//            title = nextEventTimeDifference! <= 10 ? "🔔 " : ""
//            title += nextEvent.Title + " • " + nextEvent.RelativeStartTime
//        } else {
//            title = "No more events for today"
//        }
//
//        return title
//    }
//
//
//    struct NotionFilter: Encodable {
//        let property: String
//        let text: TextFilter
//        
//        struct TextFilter: Encodable {
//            let contains: String
//        }
//    }
//    
//    // Method to query Notion database using a complex filter
//    func queryNotionDatabaseWithComplexFilter(databaseId: String, complexFilter: [String: Any], apiKey: String, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
//        // Endpoint URL
//        let url = URL(string: "https://api.notion.com/v1/databases/\(databaseId)/query")!
//        
//        // Create the request
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.addValue(apiKey, forHTTPHeaderField: "Authorization")
//        
//        // Encode the filter into JSON
//        do {
//            let jsonData = try JSONSerialization.data(withJSONObject: complexFilter, options: [])
//            request.httpBody = jsonData
//        } catch {
//            print("Error encoding filter: \(error)")
//            return
//        }
//        
//        // Perform the request
//        let task = URLSession.shared.dataTask(with: request, completionHandler: completion)
//        task.resume()
//    }
//    
//
//    func queryNotionDatabase(databaseId: String, filterProperty: String, filterValue: String, apiKey: String, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
//        // Endpoint URL
//        let url = URL(string: "https://api.notion.com/v1/databases/\(databaseId)/query")!
//        
//        // Create the filter
//        let filter = NotionFilter(property: filterProperty, text: NotionFilter.TextFilter(contains: filterValue))
//        
//        // Create the request
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.addValue(apiKey, forHTTPHeaderField: "Authorization")
//        
//        // Encode the filter into JSON
//        do {
//            let jsonData = try JSONEncoder().encode(filter)
//            request.httpBody = jsonData
//        } catch {
//            print("Error encoding filter: \(error)")
//            return
//        }
//        
//        // Perform the request
//        let task = URLSession.shared.dataTask(with: request, completionHandler: completion)
//        task.resume()
//    }
//    
//    func getEvents() {
//        // Create a predicate
//        guard let interval = Calendar.current.dateInterval(of: .day, for: Date()) else { return }
//        let predicate = eventCalander.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
//
//        // Fetch the events
//        let events = eventCalander.events(matching: predicate)
//        let sortedEvents = events.sorted { a, b in a.startDate < b.startDate }
//
//        MyEvents.removeAll()
//        for tempevent in sortedEvents {
//            
//            if tempevent.endDate.timeIntervalSinceNow > 0 && !tempevent.isAllDay {
//                
//                print("Debug: tempEvent.title = \(String(describing: tempevent.title))")
//                
//                let newEvent = Events(title: tempevent.title, startTime: formatRelativeTime(to: tempevent.startDate), event: tempevent)
//                
//                let location = tempevent.location
//                print("Debug: location = \(String(describing: tempevent.location))") //
//
//                if let location = location, location.contains("http") {
//                    if let httpIndex = location.range(of: "http")?.lowerBound {
//                        let substringFromHttp = String(location[httpIndex...])
//                        if let endIndex = substringFromHttp.rangeOfCharacter(from: CharacterSet(charactersIn: " ;\n"))?.lowerBound {
//                            let firstUrl = String(substringFromHttp[..<endIndex])
//                            newEvent.Url = URL(string: firstUrl)
//                        } else {
//                            newEvent.Url = URL(string: substringFromHttp)
//                        }
//                    }
//                }  else {
//                    // print("Debug: tempEvent.notes = \(String(describing: tempevent.notes))") // Debugging line
//                    let extractedURL = extractMeetingURL(from: tempevent.notes ?? "") ?? ""
//                    print("Debug: extractedURL = \(extractedURL)") // Debugging line
//                    newEvent.Url = URL(string: extractedURL)
//                }
//
//                print("Debug: extractedURL = \(String(describing: newEvent.Url))") //
//
//                MyEvents.append(newEvent)
//
//            }
//        }
//        NextEvent = getNextEventTitle()
//    }
//
//    enum TimeFormat {
//        case exact
//        case fuzzy
//    }
//
//    func formatRelativeTime(to eventDate: Date, format: TimeFormat = .fuzzy) -> String {
//        let currentDate = Date() // Get the current date directly within the function
//        
//        // Calculate the difference between the two dates
//        let calendar = Calendar.current
//        let components = calendar.dateComponents([.hour, .minute], from: currentDate, to: eventDate)
//
//        var hours = components.hour ?? 0
//        var minutes = components.minute ?? 0
//
//        if format == .fuzzy {
//            // Round minutes to the nearest 5
//            minutes = (minutes + 2) / 5 * 5
//            if minutes == 60 {
//                hours += 1
//                minutes = 0
//            }
//        }
//
//        // Format the difference using DateComponentsFormatter
//        let formatter = DateComponentsFormatter()
//        formatter.allowedUnits = [.hour, .minute]
//        formatter.unitsStyle = .full
//        formatter.maximumUnitCount = 2 // Display at most 2 units (e.g., 1 hour, 45 minutes)
//
//        if let formattedString = formatter.string(from: DateComponents(hour: hours, minute: minutes)) {
//            if eventDate < currentDate {
//                // If the eventDate is in the past
//                return format == .fuzzy ? "about \(formattedString.replacingOccurrences(of: "-", with: "")) ago" : "\(formattedString.replacingOccurrences(of: "-", with: "")) ago"
//            } else {
//                // If the eventDate is in the future
//                return format == .fuzzy ? "about \(formattedString)" : "in \(formattedString)"
//            }
//        }
//        return ""
//    }
//    
//    func extractMeetingURL(from text: String) -> String? {
//        let pattern = "(https://(?:teams\\.microsoft\\.com|zoom\\.us|meet\\.google\\.com|goto\\.webex\\.com)/[^\\s>]+)"
//        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
//        let range = NSRange(location: 0, length: text.utf16.count)
//        if let match = regex?.firstMatch(in: text, options: [], range: range),
//           let urlRange = Range(match.range(at: 1), in: text) {
//            let url = String(text[urlRange])
//            return url
//        }
//        return nil
//    }
//
//    
//    func checkCalendarAuthorizationStatus() {
//        if #available(macOS 14, *)
//        {
//            if(EKEventStore.authorizationStatus(for: EKEntityType.event) != EKAuthorizationStatus.fullAccess)
//            {
//                eventCalander.requestFullAccessToEvents(completion: )
//                {
//                    granted, error in
//                    if (granted)
//                    {
//                        self.eventCalander.reset()
//                        self.getEvents()
//                    }
//                }
//            }
//        }
//        else
//        {
//            if(EKEventStore.authorizationStatus(for: EKEntityType.event) != EKAuthorizationStatus.authorized)
//            {
//                eventCalander.requestAccess(to: .event)
//                {
//                    granted, error in
//                    if (granted)
//                    {
//                        self.eventCalander.reset()
//                        self.getEvents()
//                    }
//                }
//            }
//            
//        }
//    }
//        
//}
//
//class Events: ObservableObject, Equatable {
//    static func == (lhs: Events, rhs: Events) -> Bool {
//        return lhs.Uuid == rhs.Uuid
//    }
//
//    init(title: String, startTime: String, event: EKEvent){
//        Title = title
//        RelativeStartTime = startTime
//        Event = event
//        timeFormat.dateFormat = "h:mm a"
//        StartTime = timeFormat.string(from: event.startDate)
//        EndTime = timeFormat.string(from: event.endDate)
//    }
//    private let timeFormat = DateFormatter()
//    @Published var Title: String = ""
//    @Published var RelativeStartTime: String = ""
//    @Published var Url: URL?
//    @Published var Event: EKEvent
//    @Published var StartTime: String
//    @Published var EndTime: String
//    @Published var Uuid: UUID = UUID()
//}
//
//
