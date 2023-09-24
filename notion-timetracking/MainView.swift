//
//  ContentView.swift
//  notion-timetracking
//
//  Created by Jason T Alborough on 9/24/23.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var globalSettings: GlobalSettings
    @EnvironmentObject var notionController: NotionController

    @State private var showingPreferences = false
    
    var body: some View {
        ZStack {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            showingPreferences.toggle()
                        }
                    }) {
                        Image(systemName: "gear")
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                    .padding()
                }
            }
            
            if showingPreferences {
                        PreferencesView(showingPreferences: $showingPreferences)
                            .environmentObject(globalSettings)
                    }
        }
    }
}








#Preview {
    MainView()
}
