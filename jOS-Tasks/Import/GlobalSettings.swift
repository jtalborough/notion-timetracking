//
//  GlobalSettings.swift
//  notion-timetracking
//
//  Created by Jason T Alborough on 9/24/23.
//

import Foundation

class GlobalSettings: ObservableObject {
    static let shared = GlobalSettings()
    @Published var apiKey: String = ""
    @Published var TimeTrackingDatatbaseId: String = ""
    @Published var TaskDatatbaseId: String = ""
}

