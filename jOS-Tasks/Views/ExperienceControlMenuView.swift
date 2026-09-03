import SwiftUI

#if os(macOS)
struct ExperienceControlMenuView: View {
    @ObservedObject var model: ExperienceControlModel
    @State private var showPlanned = true
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { header; Divider(); content; Divider(); footer }
            .padding(16).frame(width: 380).frame(maxHeight: 480)
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) { Text("jOS").font(.headline); Text("Experience control · 0.64.0 (66)").font(.caption).foregroundStyle(.secondary) }
            Spacer()
            if case .synced = model.state { Label("Synced", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green) }
        }
    }
    @ViewBuilder private var content: some View {
        switch model.state {
        case .loading: stateMessage("Loading jOS…", icon: "arrow.triangle.2.circlepath")
        case .signedOut(let message):
            VStack(alignment: .leading, spacing: 10) {
                stateMessage(message ?? "Sign in to your jOS workspace.", icon: "person.crop.circle.badge.questionmark")
                TextField("Email", text: $model.email).textFieldStyle(.roundedBorder).accessibilityLabel("jOS account email").onSubmit { _Concurrency.Task { await model.requestSignIn() } }
                Button("Email sign-in link") { _Concurrency.Task { await model.requestSignIn() } }.keyboardShortcut(.defaultAction).disabled(model.email.isEmpty)
            }
        case .choosingWorkspace:
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose a writable personal workspace").font(.headline)
                ForEach(model.workspaces) { workspace in
                    Button { _Concurrency.Task { await model.select(workspace: workspace) } } label: { HStack { Text(workspace.name); Spacer(); Text(workspace.role.capitalized).foregroundStyle(.secondary) } }
                        .buttonStyle(.bordered).accessibilityLabel("Use \(workspace.name) workspace")
                }
            }
        case .offline(let message): recoverable(message, icon: "wifi.slash")
        case .stale(let message): recoverable(message, icon: "exclamationmark.arrow.triangle.2.circlepath")
        case .failure(let message): recoverable(message, icon: "exclamationmark.triangle")
        case .synced: syncedContent
        }
    }
    private var syncedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let current = model.snapshot?.current {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NOW").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(current.title).font(.title3.weight(.semibold)).lineLimit(2)
                    if let start = current.actualStartsAt { Text("Started \(start.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
                    Button("Stop current Experience") { _Concurrency.Task { await model.stopCurrent() } }.buttonStyle(.borderedProminent).tint(.red).disabled(model.isMutating)
                        .keyboardShortcut(".", modifiers: [.command]).accessibilityHint("Stops only the exact currently displayed actual session")
                }
            } else { stateMessage("Nothing is running.", icon: "pause.circle") }
            DisclosureGroup("Planned Today", isExpanded: $showPlanned) {
                if model.snapshot?.planned.isEmpty != false { Text("No ordinary planned Experiences.").foregroundStyle(.secondary).padding(.top, 6) }
                else {
                    VStack(spacing: 8) {
                        ForEach(model.snapshot?.planned ?? []) { experience in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) { Text(experience.title).lineLimit(2); if let start = experience.intendedStartsAt { Text(start.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary) } }
                                Spacer()
                                Button("Start") { _Concurrency.Task { await model.start(experience) } }.disabled(model.isMutating || model.snapshot?.current != nil).accessibilityLabel("Start \(experience.title)")
                            }
                        }
                    }.padding(.top, 8)
                }
            }
        }
    }
    private func recoverable(_ message: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) { stateMessage(message, icon: icon); HStack { Button("Reload") { _Concurrency.Task { await model.reload() } }.keyboardShortcut("r", modifiers: [.command]); if model.canRetryCommand { Button("Retry this action") { _Concurrency.Task { await model.retryCommand() } } } } }
    }
    private func stateMessage(_ message: String, icon: String) -> some View { Label(message, systemImage: icon).frame(maxWidth: .infinity, alignment: .leading) }
    private var footer: some View {
        HStack {
            Button("Reload") { _Concurrency.Task { await model.reload() } }.disabled(isSignedOut)
            Spacer()
            Button("Sign Out") { _Concurrency.Task { await model.signOut() } }.disabled(isSignedOut).accessibilityHint("Clears the local Keychain session even if server revocation fails")
        }
    }
    private var isSignedOut: Bool { if case .signedOut = model.state { return true }; return false }
}
#endif
