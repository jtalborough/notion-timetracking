import Foundation
import SwiftUI

func openUrlInNotion(from urlString: String) {
    guard let notionURL = convertToNotionURL(from: urlString) else {
        print("Failed to convert and open URL.")
        return
    }
    
    if NSWorkspace.shared.open(notionURL) {
        print("Successfully opened \(notionURL)")
    } else {
        print("Cannot open the converted URL.")
    }
}

func openUrlInBrowser(from urlString: String) {
    guard let url = URL(string: urlString) else {
        print("Failed to convert and open URL.")
        return
    }
    
    if NSWorkspace.shared.open(url) {
        print("Successfully opened \(url)")
    } else {
        print("Cannot open the converted URL.")
    }
}

func convertToNotionURL(from urlString: String) -> URL? {
    guard var urlComponents = URLComponents(string: urlString) else {
        print("Invalid URL string provided.")
        return nil
    }
    
    if urlComponents.scheme == "https" {
        urlComponents.scheme = "notion"
    } else {
        print("The URL scheme is not 'https', so it's not replaced.")
    }
    
    return urlComponents.url
}

