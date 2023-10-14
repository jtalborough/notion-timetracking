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
            .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))  // Increased horizontal padding
            .frame(minWidth: 50)  // Set a minimum width
            .cornerRadius(4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? Color.secondary.opacity(0.5) : Color.primary.opacity(0.2))
            )
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .padding(EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 10))
    }
}



struct ButtonStyle_Red: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.primary)
            .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))  // Increased horizontal padding
            .frame(minWidth: 50)  // Set a minimum width
            .cornerRadius(4)
            .background(
                RoundedRectangle(cornerRadius: 4) // Rounded rectangle as the background
                    .fill(configuration.isPressed ? Color(red: 0.4, green: 0, blue: 0) : Color(red: 0.55, green: 0, blue: 0))  // Dark red fill color
            )
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .padding(EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 10))
    }
}
