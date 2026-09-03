//
//  notion_timetrackingApp.swift
//  notion-timetracking
//
//  Created by Jason T Alborough on 9/24/23.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

extension Notification.Name { static let josAuthCallback = Notification.Name("josAuthCallback") }

#if os(macOS)
@MainActor final class ExperienceControlAppDelegate: NSObject, NSApplicationDelegate {
    static var callback: ((URL) -> Void)?
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        Self.callback?(url)
    }
}
#endif

@main
struct notion_timetrackingApp: App {
#if os(macOS)
    @NSApplicationDelegateAdaptor(ExperienceControlAppDelegate.self) private var appDelegate
#endif
    @StateObject private var experienceControl = ExperienceControlModel.production()
    var body: some Scene {
#if os(macOS)
        MenuBarExtra(experienceControl.menuTitle, systemImage: experienceControl.snapshot?.current == nil ? "clock" : "clock.badge.checkmark") {
            ExperienceControlMenuView(model: experienceControl)
                .task {
                    ExperienceControlAppDelegate.callback = { url in
                        _Concurrency.Task { @MainActor in await experienceControl.handle(callbackURL: url) }
                    }
                    await experienceControl.start()
                }
        }.menuBarExtraStyle(.window)
#else
        WindowGroup { Text("jOS Experience control is available in the Mac menu-bar build.") }
#endif
    }
}





        

        



