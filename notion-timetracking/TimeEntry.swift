//
//  TimeEntry.swift
//  notion-timetracking
//
//  Created by Jason T Alborough on 9/24/23.
//
import Foundation

struct TimeEntry {
    let id: String
    let startTime: Date
    var endTime: Date?  // Changed from 'let' to 'var'
    let taskReference: String
    let taskName: String
    let isDone: Bool
    
    var timeUsed: TimeInterval {
        // If endTime exists, calculate the time used between startTime and endTime
        // Otherwise, calculate the time used from startTime to the current time
        // Convert the time from seconds to minutes by dividing by 60
        return (endTime ?? Date()).timeIntervalSince(startTime) / 60
    }
}
