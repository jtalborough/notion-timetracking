import SwiftUI

#if os(macOS)
struct ExperienceReadMenuView: View {
    @ObservedObject var model: ExperienceReadModel
    @State private var showPlanned = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
            }
            .focusable()
            .accessibilityLabel("jOS current and planned Experiences")
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 380)
        .frame(maxHeight: 480)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("jOS").font(.headline)
                Text("Workspace reader · 0.65.0 (67)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if case .synced = model.state {
                Label("Current", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            stateMessage("Loading jOS…", icon: "arrow.triangle.2.circlepath")
        case .signedOut(let message):
            VStack(alignment: .leading, spacing: 10) {
                stateMessage(message ?? "Sign in to read your jOS workspace.", icon: "person.crop.circle.badge.questionmark")
                TextField("Email", text: $model.email)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("jOS account email")
                    .onSubmit { _Concurrency.Task { await model.requestSignIn() } }
                Button("Email sign-in link") { _Concurrency.Task { await model.requestSignIn() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        case .choosingWorkspace:
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose an authorized workspace").font(.headline)
                ForEach(model.workspaces) { workspace in
                    Button {
                        _Concurrency.Task { await model.select(workspace: workspace) }
                    } label: {
                        HStack {
                            Text(workspace.name)
                            Spacer()
                            Text(workspace.role.capitalized).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Use \(workspace.name) workspace")
                }
            }
        case .offline(let message):
            recoverable(message, icon: "wifi.slash", includeSnapshot: true)
        case .unauthorized(let message):
            recoverable(message, icon: "person.crop.circle.badge.exclamationmark", includeSnapshot: false)
        case .stale(let message):
            recoverable(message, icon: "exclamationmark.arrow.triangle.2.circlepath", includeSnapshot: true)
        case .failure(let message):
            recoverable(message, icon: "exclamationmark.triangle", includeSnapshot: false)
        case .synced:
            snapshotContent
        }
    }

    private var snapshotContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let current = model.snapshot?.current {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NOW").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(current.title).font(.title3.weight(.semibold)).lineLimit(2)
                    Text(current.categoryKey?.capitalized ?? "Category unresolved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let start = current.actualStartsAt {
                        Text("Started \(start.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                stateMessage("Nothing is running.", icon: "pause.circle")
            }

            DisclosureGroup("Planned Today", isExpanded: $showPlanned) {
                if model.snapshot?.planned.isEmpty != false {
                    Text("No ordinary planned Experiences.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(model.snapshot?.planned ?? []) { experience in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(experience.title).lineLimit(2)
                                HStack(spacing: 6) {
                                    if let start = experience.intendedStartsAt {
                                        Text(start.formatted(date: .omitted, time: .shortened))
                                    }
                                    Text(experience.categoryKey?.capitalized ?? "Category unresolved")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.top, 8)
                }
            }

            if model.snapshot?.plannedTruncated == true {
                Label("Showing the first 24 planned Experiences.", systemImage: "ellipsis.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func recoverable(_ message: String, icon: String, includeSnapshot: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            stateMessage(message, icon: icon)
            if includeSnapshot, model.snapshot != nil {
                Text("Last loaded state").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                snapshotContent
            }
        }
    }

    private func stateMessage(_ message: String, icon: String) -> some View {
        Label(message, systemImage: icon).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            Button("Reload") { _Concurrency.Task { await model.recover() } }
                .disabled(!model.hasRetainedSession)
                .keyboardShortcut("r", modifiers: [.command])
            Spacer()
            Button("Sign Out") { _Concurrency.Task { await model.signOut() } }
                .disabled(!model.hasRetainedSession)
                .accessibilityHint("Clears the local jOS session even if server logout is unavailable")
        }
    }
}
#endif
