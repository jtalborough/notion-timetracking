//
//  ButtonStyle_Example.swift
//  jOS-Tasks
//
//  Created by Jason T Alborough on 10/11/23.
//

import Foundation
import SwiftUI

struct MyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Basic Modifiers
            .foregroundColor(configuration.isPressed ? .gray : .white) // Set the color of the text
            .background(configuration.isPressed ? Color.gray : Color.blue) // Set the background view
            .border(Color.red, width: configuration.isPressed ? 1 : 2) // Add a border with specified color and width
            
            // Shape and Size Modifiers
            .cornerRadius(configuration.isPressed ? 4 : 8) // Round the corners
            .frame(width: configuration.isPressed ? 90 : 100, height: configuration.isPressed ? 45 : 50) // Set the size and alignment
            
            // Padding and Font
            .padding(10) // Add padding
            .font(.system(size: 14, weight: .bold, design: .default)) // Set the font properties
            
            // Visual Effect Modifiers
            .shadow(radius: configuration.isPressed ? 5 : 10, x: 0, y: configuration.isPressed ? 2 : 5) // Add a shadow with specified radius and offset
            .opacity(configuration.isPressed ? 0.5 : 1.0) // Adjust the opacity based on button state
            
            // Transformation Modifiers
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0) // Scale the view based on button state
            .rotationEffect(Angle(degrees: configuration.isPressed ? -5 : 0)) // Rotate based on button state
            .offset(x: 0, y: configuration.isPressed ? 2 : 0) // Offset position based on button state
    }
}
