import Foundation
import SwiftUI

@MainActor
final class ExperienceControlModel: ObservableObject {
    enum State: Equatable { case loading, signedOut(String?), choosingWorkspace, synced(Date), offline(String), stale(String), failure(String) }
    private enum RetryEnvelope {
        case start(experienceID: UUID, expectedOpenActualID: UUID?, at: Date, requestID: UUID)
        case stop(experienceID: UUID, expectedActualID: UUID, at: Date, requestID: UUID)
    }
    @Published var state: State = .loading
    @Published var snapshot: ExperienceControlSnapshot?
    @Published var workspaces: [ExperienceWorkspace] = []
    @Published var email = ""
    @Published private(set) var isMutating = false
    private let control: ExperienceControl
    private var retryEnvelope: RetryEnvelope?

    init(control: ExperienceControl) { self.control = control }
    static func production() -> ExperienceControlModel {
        do { return ExperienceControlModel(control: SupabaseExperienceControl(configuration: try .bundled())) }
        catch { return ExperienceControlModel(control: UnavailableExperienceControl(message: error.localizedDescription)) }
    }
    var menuTitle: String { snapshot?.current?.title ?? "jOS" }
    var canRetryCommand: Bool { retryEnvelope != nil }

    func start() async {
        state = .loading
        do { if try await control.restoreSession() { try await chooseOrBindWorkspace() } else { state = .signedOut(nil) } }
        catch { handle(error) }
    }
    func requestSignIn() async {
        state = .loading
        do { try await control.requestSignIn(email: email); state = .signedOut("Check your email, then open the jOS sign-in link.") }
        catch { handle(error) }
    }
    func handle(callbackURL: URL) async {
        state = .loading
        do { try await control.completeSignIn(callbackURL: callbackURL); try await chooseOrBindWorkspace() }
        catch { handle(error) }
    }
    func select(workspace: ExperienceWorkspace) async {
        state = .loading
        do { try await control.bind(workspaceID: workspace.id); await reload() }
        catch { handle(error) }
    }
    func reload() async {
        state = .loading
        do {
            let window = try todayWindow()
            snapshot = try await control.snapshot(windowStart: window.start, windowEnd: window.end)
            retryEnvelope = nil
            state = .synced(Date())
        } catch { handle(error) }
    }
    func start(_ experience: ControlledExperience) async {
        await execute(.start(experienceID: experience.experienceID, expectedOpenActualID: snapshot?.current?.actualID, at: Date(), requestID: UUID()))
    }
    func stopCurrent() async {
        guard let current = snapshot?.current, let actualID = current.actualID else { return }
        await execute(.stop(experienceID: current.experienceID, expectedActualID: actualID, at: Date(), requestID: UUID()))
    }
    func retryCommand() async { if let retryEnvelope { await execute(retryEnvelope) } }
    func signOut() async {
        do { try await control.signOut(); snapshot = nil; workspaces = []; retryEnvelope = nil; state = .signedOut(nil) }
        catch { snapshot = nil; workspaces = []; retryEnvelope = nil; state = .signedOut(error.localizedDescription) }
    }

    private func chooseOrBindWorkspace() async throws {
        workspaces = try await control.writablePersonalWorkspaces()
        if workspaces.count == 1, let only = workspaces.first { try await control.bind(workspaceID: only.id); await reload() }
        else if workspaces.count > 1 { state = .choosingWorkspace }
        else { throw ExperienceControlError.unauthorized("No writable personal jOS workspace is available.") }
    }
    private func execute(_ envelope: RetryEnvelope) async {
        isMutating = true; defer { isMutating = false }
        do {
            switch envelope {
            case .start(let experienceID, let expected, let at, let requestID): _ = try await control.start(experienceID: experienceID, expectedOpenActualID: expected, at: at, requestID: requestID)
            case .stop(let experienceID, let expected, let at, let requestID): _ = try await control.stop(experienceID: experienceID, expectedActualID: expected, at: at, requestID: requestID)
            }
            retryEnvelope = nil; await reload()
        } catch let error as ExperienceControlError {
            if case .ambiguous = error { retryEnvelope = envelope } else { retryEnvelope = nil }
            if case .stale = error { await reloadAfterConflict(message: error.localizedDescription) }
            else if case .ambiguous = error { await reloadAfterConflict(message: error.localizedDescription) }
            else { handle(error) }
        } catch { retryEnvelope = envelope; await reloadAfterConflict(message: "The result is uncertain. Authoritative state was reloaded.") }
    }
    private func reloadAfterConflict(message: String) async {
        do { let window = try todayWindow(); snapshot = try await control.snapshot(windowStart: window.start, windowEnd: window.end); state = .stale(message) }
        catch { handle(error) }
    }
    private func todayWindow() throws -> (start: Date, end: Date) {
        let calendar = Calendar.autoupdatingCurrent, start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { throw ExperienceControlError.server("Could not determine Today.") }
        return (start, end)
    }
    private func handle(_ error: Error) {
        guard let value = error as? ExperienceControlError else { state = .failure(error.localizedDescription); return }
        switch value {
        case .unauthorized: state = .signedOut(value.localizedDescription)
        case .offline: state = .offline(value.localizedDescription)
        case .stale: state = .stale(value.localizedDescription)
        default: state = .failure(value.localizedDescription)
        }
    }
}

private final class UnavailableExperienceControl: ExperienceControl {
    let message: String
    init(message: String) { self.message = message }
    private func failure() -> ExperienceControlError { .configuration(message) }
    func restoreSession() async throws -> Bool { throw failure() }
    func requestSignIn(email: String) async throws { throw failure() }
    func completeSignIn(callbackURL: URL) async throws { throw failure() }
    func writablePersonalWorkspaces() async throws -> [ExperienceWorkspace] { throw failure() }
    func bind(workspaceID: UUID) async throws { throw failure() }
    func snapshot(windowStart: Date, windowEnd: Date) async throws -> ExperienceControlSnapshot { throw failure() }
    func start(experienceID: UUID, expectedOpenActualID: UUID?, at: Date, requestID: UUID) async throws -> ExperienceCommandResult { throw failure() }
    func stop(experienceID: UUID, expectedActualID: UUID, at: Date, requestID: UUID) async throws -> ExperienceCommandResult { throw failure() }
    func signOut() async throws { throw failure() }
}
