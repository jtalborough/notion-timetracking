import SwiftUI

struct MainView: View {
    @EnvironmentObject var globalSettings: GlobalSettings
    @EnvironmentObject var notionController: NotionController

    @State private var showingPreferences = false

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    if(notionController.currentOpenTimeEntries.count > 0)
                    {
                        Text("\(String(notionController.currentTimeEntry))")
                            .font(.title)
                    }
                    else
                    {
                        Text("No Current Task")
                            .font(.title)
                    }
                    
                    Spacer()

//                    Button(action: {
//                        // Your logic for ending the time entry
//                        // notionController.stopCurrentTimeEntry()
//                    }) {
//                        Text("End" as! Decoder)
//                            .font(.title)
//                            .foregroundColor(.red)
//                    }
//                    .padding()
                }

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

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
