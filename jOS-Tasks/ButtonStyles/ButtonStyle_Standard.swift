//
//  StandardButtonStyle.swift
//  jOS-Tasks
//
//  Created by Jason T Alborough on 10/11/23.
//

import Foundation
import SwiftUI

struct ButtonStyle_Standard: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.primary)
            .padding(3)
            //.background(Color.gray)
            .cornerRadius(3)
            //.scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .background(
                            RoundedRectangle(cornerRadius: 3) // Rounded rectangle as the background
                                .fill(configuration.isPressed ? Color(red: 0.4, green: 0, blue: 0) : Color(red: 0.55, green: 0, blue: 0))  // Dark red fill color
                        )
                        .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)  // Animation for button press
    }
}

struct ButtonStyle_Red: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.primary)
            .padding(3)
            //.background(Color.gray)
            .cornerRadius(3)
            //.scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .background(
                            RoundedRectangle(cornerRadius: 3) // Rounded rectangle as the background
                                .fill(configuration.isPressed ? Color(red: 0.4, green: 0, blue: 0) : Color(red: 0.55, green: 0, blue: 0))  // Dark red fill color
                        )
                        .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)  // Animation for button press
    }
}
