import Foundation
import SwiftUI

@MainActor
final class ExperienceReadModel: ObservableObject {
    enum State: Equatable {
        case loading
        case signedOut(String?)
        case unauthorized(String)
        case choosingWorkspace
        case synced(Date)
        case offline(String)
        case stale(String)
        case failure(String)
    }

    @Published var state: State = .loading
    @Published var snapshot: ExperienceReadSnapshot?
    @Published var workspaces: [ReadableWorkspace] = []
    @Published var email = ""
    @Published private(set) var hasRetainedSession = false

    private let reader: ExperienceReading

    init(reader: ExperienceReading) { self.reader = reader }

    static func production() -> ExperienceReadModel {
        do {
            return ExperienceReadModel(reader: SupabaseExperienceReader(configuration: try .bundled()))
        } catch {
            return ExperienceReadModel(reader: UnavailableExperienceReader(message: error.localizedDescription))
        }
    }

    var menuTitle: String { snapshot?.current?.title ?? "jOS" }

    func start() async {
        state = .loading
        do {
            if try await reader.restoreSession() {
                hasRetainedSession = true
                try await chooseOrBindWorkspace()
            } else {
                clearWorkspaceView()
                state = .signedOut(nil)
            }
        } catch {
            refreshRetainedSession()
            handle(error)
        }
    }

    func requestSignIn() async {
        state = .loading
        do {
            try await reader.requestSignIn(email: email)
            state = .signedOut("Check your email, then open the jOS sign-in link.")
        } catch {
            refreshRetainedSession()
            handle(error)
        }
    }

    func handle(callbackURL: URL) async {
        state = .loading
        do {
            try await reader.completeSignIn(callbackURL: callbackURL)
            hasRetainedSession = true
            try await chooseOrBindWorkspace()
        } catch {
            refreshRetainedSession()
            handle(error)
        }
    }

    func select(workspace: ReadableWorkspace) async {
        state = .loading
        do {
            try await reader.bind(workspaceID: workspace.id)
            await reload()
        } catch {
            refreshRetainedSession()
            handle(error)
        }
    }

    func reload() async {
        state = .loading
        do {
            let window = try todayWindow()
            snapshot = try await reader.snapshot(windowStart: window.start, windowEnd: window.end)
            hasRetainedSession = true
            state = .synced(Date())
        } catch {
            refreshRetainedSession()
            handle(error)
        }
    }

    func recover() async {
        refreshRetainedSession()
        guard hasRetainedSession else {
            clearWorkspaceView()
            state = .signedOut(nil)
            return
        }
        if snapshot != nil {
            await reload()
        } else {
            await start()
        }
    }

    func signOut() async {
        do {
            try await reader.signOut()
            clearAll()
            state = .signedOut(nil)
        } catch {
            clearWorkspaceView()
            refreshRetainedSession()
            state = hasRetainedSession
                ? .failure("Local sign-out failed: \(error.localizedDescription)")
                : .signedOut(error.localizedDescription)
        }
    }

    private func chooseOrBindWorkspace() async throws {
        workspaces = try await reader.authorizedWorkspaces()
        if workspaces.count == 1, let only = workspaces.first {
            try await reader.bind(workspaceID: only.id)
            await reload()
        } else if workspaces.count > 1 {
            state = .choosingWorkspace
        } else {
            throw ExperienceReadError.unauthorized("No authorized jOS workspace is available.")
        }
    }

    private func todayWindow() throws -> (start: Date, end: Date) {
        let calendar = Calendar.autoupdatingCurrent
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            throw ExperienceReadError.server("Could not determine Today.")
        }
        return (start, end)
    }

    private func handle(_ error: Error) {
        guard let value = error as? ExperienceReadError else {
            state = snapshot == nil ? .failure(error.localizedDescription) : .stale(error.localizedDescription)
            return
        }
        switch value {
        case .unauthorized:
            if hasRetainedSession {
                state = .unauthorized(value.localizedDescription)
            } else {
                clearWorkspaceView()
                state = .signedOut(value.localizedDescription)
            }
        case .offline:
            state = .offline(value.localizedDescription)
        case .malformedLocalSession:
            clearAll()
            state = .signedOut(value.localizedDescription)
        case .invalidCallback:
            if hasRetainedSession {
                state = snapshot == nil ? .failure(value.localizedDescription) : .stale(value.localizedDescription)
            } else {
                clearWorkspaceView()
                state = .signedOut(value.localizedDescription)
            }
        case .configuration, .server:
            state = snapshot == nil ? .failure(value.localizedDescription) : .stale(value.localizedDescription)
        }
    }

    private func refreshRetainedSession() { hasRetainedSession = reader.hasStoredSession() }

    private func clearWorkspaceView() {
        snapshot = nil
        workspaces = []
    }

    private func clearAll() {
        clearWorkspaceView()
        hasRetainedSession = false
    }
}

private final class UnavailableExperienceReader: ExperienceReading {
    let message: String
    init(message: String) { self.message = message }
    private func failure() -> ExperienceReadError { .configuration(message) }
    func hasStoredSession() -> Bool { false }
    func restoreSession() async throws -> Bool { throw failure() }
    func requestSignIn(email: String) async throws { throw failure() }
    func completeSignIn(callbackURL: URL) async throws { throw failure() }
    func authorizedWorkspaces() async throws -> [ReadableWorkspace] { throw failure() }
    func bind(workspaceID: UUID) async throws { throw failure() }
    func snapshot(windowStart: Date, windowEnd: Date) async throws -> ExperienceReadSnapshot { throw failure() }
    func signOut() async throws { throw failure() }
}
