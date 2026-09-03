import XCTest
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
    let configuration = ExperienceControlConfiguration(supabaseURL: URL(string: "https://project-ref.supabase.co")!, publishableKey: "publishable-key")
    let userID = UUID(uuidString: "64000000-0000-4000-8000-000000000001")!
    let workspaceID = UUID(uuidString: "64000000-0000-4000-8000-000000000002")!

    func testConfigurationRejectsSecretAndServiceRoleKeys() {
        let base = ["JOS_SUPABASE_URL": "https://project-ref.supabase.co"]
        for key in ["sb_secret_never-ship", "e30.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.signature"] {
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
        XCTAssertEqual(body["email_redirect_to"] as? String, "jos://auth/callback")
        XCTAssertEqual(body["code_challenge_method"] as? String, "s256")
        XCTAssertNotNil(store.values["pkce-verifier"])
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "publishable-key")
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
        XCTAssertEqual(zeroModel.state, .signedOut("No writable personal jOS workspace is available."))

        let several = InMemoryExperienceControl(); several.hasSession = true; several.workspaces = [workspace, ExperienceWorkspace(id: UUID(), name: "Other", role: "owner")]
        let severalModel = ExperienceControlModel(control: several); await severalModel.start()
        XCTAssertEqual(severalModel.state, .choosingWorkspace)
        XCTAssertNil(several.activeWorkspaceID)
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
        await model.retryCommand()
        let starts = adapter.requests.filter { $0.kind == "start" }
        XCTAssertEqual(starts.count, 2)
        XCTAssertEqual(starts[0].requestID, starts[1].requestID)
    }

    func testStaleStopReloadsAuthoritativeStateWithoutRetryEnvelope() async {
        let adapter = readyAdapter(running: true), model = ExperienceControlModel(control: adapter)
        await model.start()
        adapter.nextError = .stale("newer actual")
        await model.stopCurrent()
        XCTAssertEqual(model.state, .stale("newer actual"))
        XCTAssertFalse(model.canRetryCommand)
    }

    private func readyAdapter(running: Bool = false) -> InMemoryExperienceControl {
        let adapter = InMemoryExperienceControl(); adapter.hasSession = true; adapter.workspaces = [workspace]
        let experienceID = UUID(), actualID = running ? UUID() : nil, now = Date()
        let experience = ControlledExperience(experienceID: experienceID, actualID: actualID, title: "Plan", description: nil, categoryKey: "work", projectID: nil, taskIDs: [], intendedStartsAt: now, intendedEndsAt: now.addingTimeInterval(3600), actualStartsAt: running ? now : nil)
        adapter.value = ExperienceControlSnapshot(apiVersion: "experience_control_v1", workspaceID: workspace.id, generatedAt: now, windowStartsAt: now, windowEndsAt: now.addingTimeInterval(86400), current: running ? experience : nil, planned: running ? [] : [experience])
        return adapter
    }
}
