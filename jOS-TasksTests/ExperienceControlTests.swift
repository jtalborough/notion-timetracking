import XCTest
import SwiftUI
@testable import jOS_Tasks

final class MemorySecureStore: ExperienceSecureStore {
    var values: [String: Data] = [:]
    func read(account: String) throws -> Data? { values[account] }
    func save(_ data: Data, account: String) throws { values[account] = data }
    func delete(account: String) throws { values.removeValue(forKey: account) }
}

final class ScriptedTransport: ExperienceHTTPTransport {
    var responses: [(Int, String)]
    private(set) var requests: [URLRequest] = []
    init(_ responses: [(Int, String)]) { self.responses = responses }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        XCTAssertNotEqual(request.url?.host, "api.notion.com", "active jOS adapter must fail fast on Notion traffic")
        guard !responses.isEmpty else { throw ExperienceControlError.server("Unexpected request") }
        let next = responses.removeFirst()
        return (Data(next.1.utf8), HTTPURLResponse(url: request.url!, statusCode: next.0, httpVersion: nil, headerFields: nil)!)
    }
}

final class ExperienceControlAdapterTests: XCTestCase {
    var configuration: ExperienceControlConfiguration { try! ExperienceControlConfiguration(supabaseURL: URL(string: "https://project-ref.supabase.co")!, publishableKey: "sb_publishable_test") }
    let userID = UUID(uuidString: "64000000-0000-4000-8000-000000000001")!
    let workspaceID = UUID(uuidString: "64000000-0000-4000-8000-000000000002")!

    func testConfigurationAcceptsOnlyPublishableOrLegacyAnonKeys() throws {
        let base = ["JOS_SUPABASE_URL": "https://project-ref.supabase.co"]
        for key in ["sb_publishable_test", legacyJWT(role: "anon")] {
            XCTAssertNoThrow(try ExperienceControlConfiguration.bundled(environment: base.merging(["JOS_SUPABASE_KEY": key]) { _, new in new }))
        }
        for key in ["", "arbitrary", "sb_publishable_", "sb_publishable_bad value", "sb_secret_never-ship", legacyJWT(role: "service_role"), "e30.e30.signature", "not.a.jwt", "e30.@@@.signature"] {
            XCTAssertThrowsError(try ExperienceControlConfiguration.bundled(environment: base.merging(["JOS_SUPABASE_KEY": key]) { _, new in new }))
        }
    }

    func testPKCESignInUsesStrictCallbackAndNeverCreatesAUser() async throws {
        let store = MemorySecureStore(), transport = ScriptedTransport([(200, "{}")])
        let adapter = SupabaseExperienceControl(configuration: configuration, secureStore: store, transport: transport)
        try await adapter.requestSignIn(email: "j@example.test")
        let request = try XCTUnwrap(transport.requests.first)
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["create_user"] as? Bool, false)
        XCTAssertNil(body["email_redirect_to"])
        XCTAssertNil(body["redirect_to"])
        XCTAssertEqual(body["code_challenge_method"] as? String, "s256")
        let query = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query.count, 1)
        XCTAssertEqual(query.first?.name, "redirect_to")
        XCTAssertEqual(query.first?.value, "jos://auth/callback")
        XCTAssertNotNil(store.values["pkce-verifier"])
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "sb_publishable_test")
    }

    func testCallbackRejectsEveryNonExactRouteBeforeNetwork() async {
        let transport = ScriptedTransport([])
        let adapter = SupabaseExperienceControl(configuration: configuration, secureStore: MemorySecureStore(), transport: transport)
        for value in ["jos://auth/other?code=x", "jos://evil/callback?code=x", "https://auth/callback?code=x"] {
            do { try await adapter.completeSignIn(callbackURL: URL(string: value)!); XCTFail("Accepted \(value)") }
            catch { XCTAssertEqual(error as? ExperienceControlError, .invalidCallback) }
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testWorkspaceBindingAndSnapshotDecodeCanonicalContext() async throws {
        let store = try sessionStore()
        let workspaceJSON = """
        [{"workspace_id":"\(workspaceID.uuidString)","role":"owner","workspaces":{"id":"\(workspaceID.uuidString)","name":"Personal","created_by":"\(userID.uuidString)"}}]
        """
        let snapshotJSON = """
        {"api_version":"experience_control_v1","workspace_id":"\(workspaceID.uuidString)","generated_at":"2026-09-03T14:00:00Z","window_starts_at":"2026-09-03T00:00:00Z","window_ends_at":"2026-09-04T00:00:00Z","current":null,"planned":[{"experience_id":"64000000-0000-4000-8000-000000000003","actual_id":null,"title":"Plan","description":"Context","category_key":"work","project_id":"64000000-0000-4000-8000-000000000004","task_ids":["64000000-0000-4000-8000-000000000005"],"intended_starts_at":"2026-09-03T15:00:00Z","intended_ends_at":"2026-09-03T16:00:00Z","actual_starts_at":null}]}
        """
        let transport = ScriptedTransport([(200, workspaceJSON), (200, workspaceJSON), (200, snapshotJSON)])
        let adapter = SupabaseExperienceControl(configuration: configuration, secureStore: store, transport: transport)
        let restored = try await adapter.restoreSession()
        let workspaces = try await adapter.writablePersonalWorkspaces()
        XCTAssertTrue(restored)
        XCTAssertEqual(workspaces, [ExperienceWorkspace(id: workspaceID, name: "Personal", role: "owner")])
        try await adapter.bind(workspaceID: workspaceID)
        let value = try await adapter.snapshot(windowStart: Date(timeIntervalSince1970: 0), windowEnd: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(value.apiVersion, "experience_control_v1")
        XCTAssertEqual(value.planned.first?.projectID?.uuidString.lowercased(), "64000000-0000-4000-8000-000000000004")
        XCTAssertEqual(value.planned.first?.taskIDs.count, 1)
        XCTAssertTrue(transport.requests.allSatisfy { $0.url?.host == "project-ref.supabase.co" })
    }

    func testNullCategoryCurrentDecodesAndStopsByExactActualID() async throws {
        let actualID = UUID(uuidString: "64000000-0000-4000-8000-000000000007")!
        let experienceID = UUID(uuidString: "64000000-0000-4000-8000-000000000008")!
        let workspaceJSON = """
        [{"workspace_id":"\(workspaceID.uuidString)","role":"owner","workspaces":{"id":"\(workspaceID.uuidString)","name":"Personal","created_by":"\(userID.uuidString)"}}]
        """
        let snapshotJSON = """
        {"api_version":"experience_control_v1","workspace_id":"\(workspaceID.uuidString)","generated_at":"2026-09-03T14:00:00Z","window_starts_at":"2026-09-03T00:00:00Z","window_ends_at":"2026-09-04T00:00:00Z","current":{"experience_id":"\(experienceID.uuidString)","actual_id":"\(actualID.uuidString)","title":"Legacy current","description":null,"category_key":null,"project_id":null,"task_ids":[],"intended_starts_at":null,"intended_ends_at":null,"actual_starts_at":"2026-09-03T13:00:00Z"},"planned":[]}
        """
        let resultJSON = """
        {"experience_id":"\(experienceID.uuidString)","actual_id":"\(actualID.uuidString)","event_id":"64000000-0000-4000-8000-000000000009","source":"jos.mac.menu.v1"}
        """
        let transport = ScriptedTransport([(200, workspaceJSON), (200, snapshotJSON), (200, resultJSON)])
        let adapter = SupabaseExperienceControl(configuration: configuration, secureStore: try sessionStore(), transport: transport)
        let restored = try await adapter.restoreSession()
        XCTAssertTrue(restored)
        try await adapter.bind(workspaceID: workspaceID)
        let snapshot = try await adapter.snapshot(windowStart: .distantPast, windowEnd: .distantFuture)
        XCTAssertNil(snapshot.current?.categoryKey)
        _ = try await adapter.stop(experienceID: experienceID, expectedActualID: actualID, at: Date(), requestID: UUID())
        let stopBody = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(transport.requests.last?.httpBody)) as? [String: Any])
        XCTAssertEqual(stopBody["p_expected_actual_id"] as? String, actualID.uuidString.lowercased())
    }

    func testNetworkConnectionLossIsAmbiguousButPreflightOfflineIsDefinite() {
        guard case .ambiguous(let message) = URLSessionExperienceTransport.classify(URLError(.networkConnectionLost)) else {
            return XCTFail("networkConnectionLost must be ambiguous")
        }
        XCTAssertFalse(message.contains("Nothing was queued"))
        guard case .offline(let offlineMessage) = URLSessionExperienceTransport.classify(URLError(.notConnectedToInternet)) else {
            return XCTFail("notConnectedToInternet must be definite offline")
        }
        XCTAssertTrue(offlineMessage.contains("Nothing was sent or queued"))
    }

    func testSeveralPersonalWorkspacesRequireExplicitBindingAndForeignWorkspaceIsRejected() async throws {
        let second = UUID(uuidString: "64000000-0000-4000-8000-000000000006")!
        let rows = """
        [{"workspace_id":"\(workspaceID.uuidString)","role":"owner","workspaces":{"id":"\(workspaceID.uuidString)","name":"One","created_by":"\(userID.uuidString)"}},{"workspace_id":"\(second.uuidString)","role":"owner","workspaces":{"id":"\(second.uuidString)","name":"Two","created_by":"\(userID.uuidString)"}}]
        """
        let transport = ScriptedTransport([(200, rows), (200, rows)])
        let adapter = SupabaseExperienceControl(configuration: configuration, secureStore: try sessionStore(), transport: transport)
        let restored = try await adapter.restoreSession()
        let workspaces = try await adapter.writablePersonalWorkspaces()
        XCTAssertTrue(restored)
        XCTAssertEqual(workspaces.count, 2)
        do { try await adapter.bind(workspaceID: UUID()); XCTFail("Bound an unauthorized workspace") }
        catch { XCTAssertEqual(error as? ExperienceControlError, .unauthorized("That workspace is not a writable personal workspace.")) }
    }

    func testSignOutClearsLocalSessionAndReportsRevocationFailure() async throws {
        let store = try sessionStore(), transport = ScriptedTransport([(500, "{\"message\":\"down\"}")])
        let adapter = SupabaseExperienceControl(configuration: configuration, secureStore: store, transport: transport)
        let restored = try await adapter.restoreSession()
        XCTAssertTrue(restored)
        do { try await adapter.signOut(); XCTFail("Revocation failure was hidden") }
        catch { XCTAssertEqual(error as? ExperienceControlError, .server("Signed out locally; server revocation failed.")) }
        XCTAssertNil(store.values["supabase-session"])
    }

    func testNamespacedKeychainRoundTripUnderTestArtifact() throws {
        let store = NamespacedKeychainStore(bundleID: "jta.jos.tasks.macos.tests", projectNamespace: UUID().uuidString)
        let account = "probe-\(UUID().uuidString)"
        defer { try? store.delete(account: account) }
        try store.save(Data("probe".utf8), account: account)
        XCTAssertEqual(try store.read(account: account), Data("probe".utf8))
        try store.delete(account: account)
        XCTAssertNil(try store.read(account: account))
    }

    func testActiveAppSourceDoesNotInstantiateLegacyNotionController() throws {
        let tests = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let root = tests.deletingLastPathComponent()
        let source = root.appendingPathComponent("jOS-Tasks/jOS_TasksApp.swift")
        let text = try String(contentsOf: source, encoding: .utf8)
        XCTAssertFalse(text.contains("NotionController"))
        XCTAssertFalse(text.contains("startPolling"))
        XCTAssertFalse(text.contains("NotionAPI"))

        let project = try String(contentsOf: root.appendingPathComponent("jOS-Tasks.xcodeproj/project.pbxproj"), encoding: .utf8)
        let appSources = try XCTUnwrap(project.range(of: "6B9281862ACAC57C00E39EF4 /* Sources */ = {")).lowerBound
        let appSourcesEnd = try XCTUnwrap(project.range(of: "/* End PBXSourcesBuildPhase section */", range: appSources..<project.endIndex)).lowerBound
        let activeBuildPhase = String(project[appSources..<appSourcesEnd])
        for legacySource in ["NotionAPI.swift", "NotionController.swift", "MenuBarView.swift", "TaskListView.swift", "TimeEntry.swift"] {
            XCTAssertFalse(activeBuildPhase.contains(legacySource), "\(legacySource) must remain dormant")
        }

        let menuSource = try String(contentsOf: root.appendingPathComponent("jOS-Tasks/Views/ExperienceControlMenuView.swift"), encoding: .utf8)
        let scroll = try XCTUnwrap(menuSource.range(of: "ScrollView"))
        XCTAssertLessThan(try XCTUnwrap(menuSource.range(of: "header")).lowerBound, scroll.lowerBound)
        XCTAssertGreaterThan(try XCTUnwrap(menuSource.range(of: "footer", range: scroll.upperBound..<menuSource.endIndex)).lowerBound, scroll.upperBound)
        XCTAssertTrue(menuSource.contains("frame(maxHeight: 480)"))
        XCTAssertEqual(menuSource.components(separatedBy: ".disabled(!model.hasRetainedSession)").count - 1, 2)
    }

    private func legacyJWT(role: String) -> String {
        func encode(_ object: [String: Any]) -> String {
            let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            return data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        }
        return "\(encode(["alg": "HS256", "typ": "JWT"])).\(encode(["role": role])).\(Data(repeating: 7, count: 32).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: ""))"
    }

    private func sessionStore() throws -> MemorySecureStore {
        let store = MemorySecureStore(), encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        store.values["supabase-session"] = try encoder.encode(ExperienceControlSession(accessToken: "access", refreshToken: "refresh", expiresAt: Date().addingTimeInterval(3600), userID: userID))
        return store
    }
}

@MainActor
final class ExperienceControlModelTests: XCTestCase {
    private let workspace = ExperienceWorkspace(id: UUID(), name: "Personal", role: "owner")

    func testZeroWorkspacesFailsClosedAndSeveralRequireSelection() async {
        let zero = InMemoryExperienceControl(); zero.hasSession = true
        let zeroModel = ExperienceControlModel(control: zero); await zeroModel.start()
        XCTAssertEqual(zeroModel.state, .unauthorized("No writable personal jOS workspace is available."))
        XCTAssertTrue(zeroModel.hasRetainedSession)

        let ready = readyAdapter()
        zero.workspaces = [workspace]
        zero.value = ready.value
        await zeroModel.recover()
        guard case .synced = zeroModel.state else { return XCTFail("retained session did not recover") }

        let several = InMemoryExperienceControl(); several.hasSession = true; several.workspaces = [workspace, ExperienceWorkspace(id: UUID(), name: "Other", role: "owner")]
        let severalModel = ExperienceControlModel(control: several); await severalModel.start()
        XCTAssertEqual(severalModel.state, .choosingWorkspace)
        XCTAssertNil(several.activeWorkspaceID)
        XCTAssertTrue(severalModel.hasRetainedSession)
    }

    func testRetainedSessionKeepsRecoveryAndSignOutAvailableAcrossErrors() async {
        let adapter = InMemoryExperienceControl(); adapter.hasSession = true; adapter.workspaceError = .server("membership unavailable")
        let model = ExperienceControlModel(control: adapter)
        await model.start()
        XCTAssertEqual(model.state, .failure("membership unavailable"))
        XCTAssertTrue(model.hasRetainedSession)
        await model.signOut()
        XCTAssertEqual(model.state, .signedOut(nil))
        XCTAssertFalse(model.hasRetainedSession)
    }

    func testOfflineStartIsNotRetainedOrReplayed() async {
        let adapter = readyAdapter(), model = ExperienceControlModel(control: adapter)
        await model.start()
        adapter.nextError = .offline("offline")
        await model.start(adapter.value!.planned[0])
        XCTAssertEqual(model.state, .offline("offline"))
        XCTAssertFalse(model.canRetryCommand)
        XCTAssertEqual(adapter.requests.filter { $0.kind == "start" }.count, 1)
    }

    func testAmbiguousCommandReloadsAndOnlyDeliberateRetryReusesLiveRequestID() async {
        let adapter = readyAdapter(), model = ExperienceControlModel(control: adapter)
        await model.start()
        adapter.nextError = .ambiguous("uncertain")
        await model.start(adapter.value!.planned[0])
        XCTAssertEqual(model.state, .stale("uncertain"))
        XCTAssertTrue(model.canRetryCommand)
        XCTAssertEqual(adapter.requests.filter { $0.kind == "start" }.count, 1, "ambiguity must not auto-replay")
        await model.retryCommand()
        let starts = adapter.requests.filter { $0.kind == "start" }
        XCTAssertEqual(starts.count, 2)
        XCTAssertEqual(starts[0].requestID, starts[1].requestID)
    }

    func testAmbiguousStartReloadsAndSuppressesRetryWhenAuthoritativeStateShowsCommit() async {
        let adapter = readyAdapter(), model = ExperienceControlModel(control: adapter)
        await model.start()
        let planned = adapter.value!.planned[0]
        let actualID = UUID()
        adapter.valueAfterCommandError = ExperienceControlSnapshot(
            apiVersion: "experience_control_v1",
            workspaceID: workspace.id,
            generatedAt: Date(),
            windowStartsAt: adapter.value!.windowStartsAt,
            windowEndsAt: adapter.value!.windowEndsAt,
            current: ControlledExperience(experienceID: planned.experienceID, actualID: actualID, title: planned.title, description: planned.description, categoryKey: planned.categoryKey, projectID: planned.projectID, taskIDs: planned.taskIDs, intendedStartsAt: planned.intendedStartsAt, intendedEndsAt: planned.intendedEndsAt, actualStartsAt: Date()),
            planned: []
        )
        adapter.nextError = .ambiguous("connection lost")
        await model.start(planned)
        guard case .synced = model.state else { return XCTFail("authoritative commit was not resolved") }
        XCTAssertFalse(model.canRetryCommand)
        XCTAssertEqual(adapter.requests.filter { $0.kind == "start" }.count, 1)
        XCTAssertEqual(model.snapshot?.current?.actualID, actualID)
    }

    func testAmbiguousStopReloadsAndSuppressesRetryWhenAuthoritativeStateShowsClosure() async {
        let adapter = readyAdapter(running: true), model = ExperienceControlModel(control: adapter)
        await model.start()
        let before = adapter.value!
        adapter.valueAfterCommandError = ExperienceControlSnapshot(
            apiVersion: before.apiVersion,
            workspaceID: before.workspaceID,
            generatedAt: Date(),
            windowStartsAt: before.windowStartsAt,
            windowEndsAt: before.windowEndsAt,
            current: nil,
            planned: []
        )
        adapter.nextError = .ambiguous("connection lost")
        await model.stopCurrent()
        guard case .synced = model.state else { return XCTFail("authoritative closure was not resolved") }
        XCTAssertFalse(model.canRetryCommand)
        XCTAssertEqual(adapter.requests.filter { $0.kind == "stop" }.count, 1)
        XCTAssertNil(model.snapshot?.current)
    }

    func testStaleStopReloadsAuthoritativeStateWithoutRetryEnvelope() async {
        let adapter = readyAdapter(running: true), model = ExperienceControlModel(control: adapter)
        await model.start()
        adapter.nextError = .stale("newer actual")
        await model.stopCurrent()
        XCTAssertEqual(model.state, .stale("newer actual"))
        XCTAssertFalse(model.canRetryCommand)
    }

    func testTwentyFourPlansRemainInTheBoundedSnapshotModel() async {
        let adapter = readyAdapter(plannedCount: 24), model = ExperienceControlModel(control: adapter)
        await model.start()
        XCTAssertEqual(model.snapshot?.planned.count, 24)
        XCTAssertEqual(model.snapshot?.planned.last?.title, "Plan 24")

        let host = NSHostingView(rootView: ExperienceControlMenuView(model: model))
        host.frame = NSRect(x: 0, y: 0, width: 380, height: 480)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        host.layoutSubtreeIfNeeded()
        let scrollView = try? XCTUnwrap(allSubviews(of: host).compactMap { $0 as? NSScrollView }.first)
        guard let scrollView else { return XCTFail("24-row menu did not create a native scroll container") }
        scrollView.layoutSubtreeIfNeeded()
        let documentHeight = scrollView.documentView?.bounds.height ?? 0
        XCTAssertGreaterThan(documentHeight, scrollView.contentView.bounds.height)
        let bottom = max(0, documentHeight - scrollView.contentView.bounds.height)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: bottom))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        XCTAssertGreaterThan(scrollView.contentView.bounds.origin.y, 0, "last planned rows must be scroll-reachable")
    }

    private func allSubviews(of root: NSView) -> [NSView] {
        root.subviews + root.subviews.flatMap(allSubviews)
    }

    private func readyAdapter(running: Bool = false, plannedCount: Int = 1) -> InMemoryExperienceControl {
        let adapter = InMemoryExperienceControl(); adapter.hasSession = true; adapter.workspaces = [workspace]
        let now = Date()
        let experiences = (0..<plannedCount).map { index in
            let title = plannedCount == 1 ? "Plan" : "Plan \(index + 1)"
            let intendedStart = now.addingTimeInterval(Double(index * 60))
            let intendedEnd = intendedStart.addingTimeInterval(3600)
            return ControlledExperience(experienceID: UUID(), actualID: nil, title: title, description: nil, categoryKey: "work", projectID: nil, taskIDs: [], intendedStartsAt: intendedStart, intendedEndsAt: intendedEnd, actualStartsAt: nil)
        }
        let current = running ? ControlledExperience(experienceID: UUID(), actualID: UUID(), title: "Plan", description: nil, categoryKey: nil, projectID: nil, taskIDs: [], intendedStartsAt: now, intendedEndsAt: now.addingTimeInterval(3600), actualStartsAt: now) : nil
        adapter.value = ExperienceControlSnapshot(apiVersion: "experience_control_v1", workspaceID: workspace.id, generatedAt: now, windowStartsAt: now, windowEndsAt: now.addingTimeInterval(86400), current: current, planned: running ? [] : experiences)
        return adapter
    }
}
