import SwiftUI
#if os(macOS)
import AppKit
#endif

#if os(macOS)
@MainActor
final class ExperienceReadAppDelegate: NSObject, NSApplicationDelegate {
    static var callback: ((URL) -> Void)?

    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.count == 1, let url = urls.first else { return }
        Self.callback?(url)
    }
}
#endif

@main
struct jOSWorkspaceReaderApp: App {
#if os(macOS)
    @NSApplicationDelegateAdaptor(ExperienceReadAppDelegate.self) private var appDelegate
#endif
    @StateObject private var experienceRead = ExperienceReadModel.production()

    var body: some Scene {
#if os(macOS)
        MenuBarExtra(experienceRead.menuTitle, systemImage: experienceRead.snapshot?.current == nil ? "clock" : "clock.badge.checkmark") {
            ExperienceReadMenuView(model: experienceRead)
                .task {
                    ExperienceReadAppDelegate.callback = { url in
                        _Concurrency.Task { @MainActor in
                            await experienceRead.handle(callbackURL: url)
                        }
                    }
                    await experienceRead.start()
                }
        }
        .menuBarExtraStyle(.window)
#else
        WindowGroup { Text("jOS workspace reading is available in the Mac menu-bar build.") }
#endif
    }
}
