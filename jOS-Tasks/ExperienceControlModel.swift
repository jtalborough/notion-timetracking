import Foundation
import SwiftUI

@MainActor
final class ExperienceControlModel: ObservableObject {
    enum State: Equatable { case loading, signedOut(String?), unauthorized(String), choosingWorkspace, synced(Date), offline(String), stale(String), failure(String) }
    private enum RetryEnvelope {
        case start(experienceID: UUID, expectedOpenActualID: UUID?, at: Date, requestID: UUID)
        case stop(experienceID: UUID, expectedActualID: UUID, at: Date, requestID: UUID)
    }
    @Published var state: State = .loading
    @Published var snapshot: ExperienceControlSnapshot?
    @Published var workspaces: [ExperienceWorkspace] = []
    @Published var email = ""
    @Published private(set) var isMutating = false
    @Published private(set) var hasRetainedSession = false
    private let control: ExperienceControl
    private var retryEnvelope: RetryEnvelope?
    private var retryReady = false
    private var retryMessage: String?

    init(control: ExperienceControl) { self.control = control }
    static func production() -> ExperienceControlModel {
        do { return ExperienceControlModel(control: SupabaseExperienceControl(configuration: try .bundled())) }
        catch { return ExperienceControlModel(control: UnavailableExperienceControl(message: error.localizedDescription)) }
    }
    var menuTitle: String { snapshot?.current?.title ?? "jOS" }
    var canRetryCommand: Bool { retryEnvelope != nil && retryReady }

    func start() async {
        state = .loading
        do {
            if try await control.restoreSession() {
                hasRetainedSession = true
                try await chooseOrBindWorkspace()
            } else {
                hasRetainedSession = false
                state = .signedOut(nil)
            }
        } catch { refreshRetainedSession(); handle(error) }
    }
    func requestSignIn() async {
        state = .loading
        do { try await control.requestSignIn(email: email); state = .signedOut("Check your email, then open the jOS sign-in link.") }
        catch { handle(error) }
    }
    func handle(callbackURL: URL) async {
        state = .loading
        do { try await control.completeSignIn(callbackURL: callbackURL); hasRetainedSession = true; try await chooseOrBindWorkspace() }
        catch { refreshRetainedSession(); handle(error) }
    }
    func select(workspace: ExperienceWorkspace) async {
        state = .loading
        do { try await control.bind(workspaceID: workspace.id); await reload() }
        catch { refreshRetainedSession(); handle(error) }
    }
    func reload() async {
        state = .loading
        do {
            let window = try todayWindow()
            snapshot = try await control.snapshot(windowStart: window.start, windowEnd: window.end)
            resolvePendingEnvelopeAfterReload()
        } catch { refreshRetainedSession(); retryReady = false; handle(error) }
    }
    func recover() async {
        refreshRetainedSession()
        guard hasRetainedSession else { state = .signedOut(nil); return }
        if snapshot != nil { await reload(); return }
        state = .loading
        do { try await chooseOrBindWorkspace() }
        catch { refreshRetainedSession(); handle(error) }
    }
    func start(_ experience: ControlledExperience) async {
        await execute(.start(experienceID: experience.experienceID, expectedOpenActualID: snapshot?.current?.actualID, at: Date(), requestID: UUID()))
    }
    func stopCurrent() async {
        guard let current = snapshot?.current, let actualID = current.actualID else { return }
        await execute(.stop(experienceID: current.experienceID, expectedActualID: actualID, at: Date(), requestID: UUID()))
    }
    func retryCommand() async { if retryReady, let retryEnvelope { await execute(retryEnvelope) } }
    func signOut() async {
        do { try await control.signOut(); clearLocalView(); state = .signedOut(nil) }
        catch {
            snapshot = nil
            workspaces = []
            clearRetry()
            refreshRetainedSession()
            state = hasRetainedSession ? .failure("Local sign-out failed: \(error.localizedDescription)") : .signedOut(error.localizedDescription)
        }
    }

    private func chooseOrBindWorkspace() async throws {
        workspaces = try await control.writablePersonalWorkspaces()
        if workspaces.count == 1, let only = workspaces.first { try await control.bind(workspaceID: only.id); await reload() }
        else if workspaces.count > 1 { state = .choosingWorkspace }
        else { throw ExperienceControlError.unauthorized("No writable personal jOS workspace is available.") }
    }
    private func execute(_ envelope: RetryEnvelope) async {
        isMutating = true; defer { isMutating = false }
        retryReady = false
        do {
            switch envelope {
            case .start(let experienceID, let expected, let at, let requestID): _ = try await control.start(experienceID: experienceID, expectedOpenActualID: expected, at: at, requestID: requestID)
            case .stop(let experienceID, let expected, let at, let requestID): _ = try await control.stop(experienceID: experienceID, expectedActualID: expected, at: at, requestID: requestID)
            }
            clearRetry(); await reload()
        } catch let error as ExperienceControlError {
            if case .ambiguous = error {
                retryEnvelope = envelope
                retryMessage = error.localizedDescription
                await reloadAfterUncertainty()
            } else if case .stale = error {
                clearRetry()
                await reloadAfterConflict(message: error.localizedDescription)
            } else {
                clearRetry()
                refreshRetainedSession()
                handle(error)
            }
        } catch {
            retryEnvelope = envelope
            retryMessage = "The result is uncertain. Authoritative state must be reloaded."
            await reloadAfterUncertainty()
        }
    }
    private func reloadAfterConflict(message: String) async {
        do { let window = try todayWindow(); snapshot = try await control.snapshot(windowStart: window.start, windowEnd: window.end); state = .stale(message) }
        catch { refreshRetainedSession(); handle(error) }
    }
    private func reloadAfterUncertainty() async {
        do {
            let window = try todayWindow()
            snapshot = try await control.snapshot(windowStart: window.start, windowEnd: window.end)
            resolvePendingEnvelopeAfterReload()
        } catch {
            retryReady = false
            refreshRetainedSession()
            handle(error)
        }
    }
    private func resolvePendingEnvelopeAfterReload() {
        guard let envelope = retryEnvelope else { state = .synced(Date()); return }
        if isStillUnresolved(envelope) {
            retryReady = true
            state = .stale(retryMessage ?? "The action remains unresolved after reloading authoritative state.")
        } else {
            clearRetry()
            state = .synced(Date())
        }
    }
    private func isStillUnresolved(_ envelope: RetryEnvelope) -> Bool {
        switch envelope {
        case .start(let experienceID, _, _, _):
            return snapshot?.current == nil && snapshot?.planned.contains(where: { $0.experienceID == experienceID }) == true
        case .stop(let experienceID, let expectedActualID, _, _):
            return snapshot?.current?.experienceID == experienceID && snapshot?.current?.actualID == expectedActualID
        }
    }
    private func clearRetry() {
        retryEnvelope = nil
        retryReady = false
        retryMessage = nil
    }
    private func clearLocalView() {
        snapshot = nil
        workspaces = []
        clearRetry()
        hasRetainedSession = false
    }
    private func refreshRetainedSession() {
        hasRetainedSession = control.hasStoredSession()
    }
    private func todayWindow() throws -> (start: Date, end: Date) {
        let calendar = Calendar.autoupdatingCurrent, start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { throw ExperienceControlError.server("Could not determine Today.") }
        return (start, end)
    }
    private func handle(_ error: Error) {
        guard let value = error as? ExperienceControlError else { state = .failure(error.localizedDescription); return }
        switch value {
        case .unauthorized: state = hasRetainedSession ? .unauthorized(value.localizedDescription) : .signedOut(value.localizedDescription)
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
    func hasStoredSession() -> Bool { false }
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
