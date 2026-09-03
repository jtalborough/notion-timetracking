import XCTest
import SwiftUI
@testable import jOS_Tasks

final class MemoryReadStore: ExperienceReadSecureStore {
    var values: [String: Data] = [:]
    func read(account: String) throws -> Data? { values[account] }
    func save(_ data: Data, account: String) throws { values[account] = data }
    func delete(account: String) throws { values.removeValue(forKey: account) }
}

final class ScriptedReadTransport: ExperienceReadHTTPTransport {
    enum Step {
        case response(Int, String)
        case failure(ExperienceReadError)
    }

    var steps: [Step]
    private(set) var requests: [URLRequest] = []

    init(_ steps: [Step]) { self.steps = steps }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        XCTAssertNotEqual(request.url?.host, "api.notion.com")
        guard !steps.isEmpty else { throw ExperienceReadError.server("Unexpected request") }
        switch steps.removeFirst() {
        case .failure(let error): throw error
        case .response(let status, let body):
            return (
                Data(body.utf8),
                HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            )
        }
    }
}

final class ExperienceReadAdapterTests: XCTestCase {
    private let key = "sb_publishable_abcdefghijklmnopqrstuvwxyz012345"
    private let userID = UUID(uuidString: "65000000-0000-4000-8000-000000000001")!
    private let workspaceID = UUID(uuidString: "65000000-0000-4000-8000-000000000002")!

    private var configuration: ExperienceReadConfiguration {
        try! ExperienceReadConfiguration(
            supabaseURL: URL(string: "https://project-ref.supabase.co")!,
            publishableKey: key,
            trustedCredentialSHA256: ExperienceReadConfiguration.fingerprint(for: key)
        )
    }

    func testConfigurationRequiresExactTrustAnchorAndPublicCredentialStructure() throws {
        XCTAssertNoThrow(try ExperienceReadConfiguration(
            supabaseURL: URL(string: "https://project-ref.supabase.co")!,
            publishableKey: key,
            trustedCredentialSHA256: ExperienceReadConfiguration.fingerprint(for: key)
        ))

        let future = Date(timeIntervalSince1970: 2_000_000_000)
        let legacy = legacyJWT(algorithm: "HS256", role: "anon", expiration: 2_100_000_000)
        XCTAssertNoThrow(try ExperienceReadConfiguration(
            supabaseURL: URL(string: "https://project-ref.supabase.co")!,
            publishableKey: legacy,
            trustedCredentialSHA256: ExperienceReadConfiguration.fingerprint(for: legacy),
            now: future
        ))

        let rejected = [
            "arbitrary",
            "sb_publishable_x",
            "sb_secret_abcdefghijklmnopqrstuvwxyz012345",
            legacyJWT(algorithm: "none", role: "anon", expiration: 2_100_000_000),
            legacyJWT(algorithm: "HS256", role: "service_role", expiration: 2_100_000_000),
            legacyJWT(algorithm: "HS256", role: "anon", expiration: 1_900_000_000)
        ]
        for candidate in rejected {
            XCTAssertThrowsError(try ExperienceReadConfiguration(
                supabaseURL: URL(string: "https://project-ref.supabase.co")!,
                publishableKey: candidate,
                trustedCredentialSHA256: ExperienceReadConfiguration.fingerprint(for: candidate),
                now: future
            ), "accepted \(candidate.prefix(20))")
        }

        XCTAssertThrowsError(try ExperienceReadConfiguration(
            supabaseURL: URL(string: "https://project-ref.supabase.co")!,
            publishableKey: key,
            trustedCredentialSHA256: String(repeating: "0", count: 64)
        ))
        XCTAssertThrowsError(try ExperienceReadConfiguration(
            supabaseURL: URL(string: "https://attacker.example")!,
            publishableKey: key,
            trustedCredentialSHA256: ExperienceReadConfiguration.fingerprint(for: key)
        ))
    }

    func testPKCERequestUsesExactRedirectAndDoesNotCreateUser() async throws {
        let store = MemoryReadStore()
        let transport = ScriptedReadTransport([.response(200, "{}")])
        let reader = SupabaseExperienceReader(configuration: configuration, secureStore: store, transport: transport)
        try await reader.requestSignIn(email: "j@example.test")

        let request = try XCTUnwrap(transport.requests.first)
        let query = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query, [URLQueryItem(name: "redirect_to", value: "jos://auth/callback")])
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        XCTAssertEqual(body["create_user"] as? Bool, false)
        XCTAssertEqual(body["code_challenge_method"] as? String, "s256")
        XCTAssertNotNil(store.values["pkce-verifier"])
    }

    func testCallbackRejectsNonExactURLsBeforeTokenExchange() async throws {
        let store = MemoryReadStore()
        store.values["pkce-verifier"] = Data("verifier".utf8)
        let transport = ScriptedReadTransport([])
        let reader = SupabaseExperienceReader(configuration: configuration, secureStore: store, transport: transport)
        let rejected = [
            "jos://auth/callback",
            "jos://auth/callback?code=",
            "jos://auth/callback?code=x&extra=y",
            "jos://auth/callback?code=x&code=y",
            "jos://auth/callback?code=x#fragment",
            "jos://user@auth/callback?code=x",
            "jos://auth:42/callback?code=x",
            "jos://auth/other?code=x",
            "https://auth/callback?code=x"
        ]
        for value in rejected {
            do {
                try await reader.completeSignIn(callbackURL: URL(string: value)!)
                XCTFail("Accepted \(value)")
            } catch {
                XCTAssertEqual(error as? ExperienceReadError, .invalidCallback)
            }
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testExactCallbackExchangesCodeAndStoresSession() async throws {
        let store = MemoryReadStore()
        store.values["pkce-verifier"] = Data("verifier".utf8)
        let transport = ScriptedReadTransport([.response(200, authJSON())])
        let reader = SupabaseExperienceReader(configuration: configuration, secureStore: store, transport: transport)
        try await reader.completeSignIn(callbackURL: URL(string: "jos://auth/callback?code=one_value")!)
        XCTAssertNotNil(store.values["supabase-session"])
        XCTAssertNil(store.values["pkce-verifier"])
        XCTAssertEqual(transport.requests.first?.url?.path, "/auth/v1/token")
    }

    func testOfflineExpiredRefreshKeepsStoredSession() async throws {
        let store = try sessionStore(expired: true)
        let transport = ScriptedReadTransport([.failure(.offline("offline"))])
        let reader = SupabaseExperienceReader(configuration: configuration, secureStore: store, transport: transport)
        do { _ = try await reader.restoreSession(); XCTFail("offline refresh succeeded") }
        catch { XCTAssertEqual(error as? ExperienceReadError, .offline("offline")) }
        XCTAssertNotNil(store.values["supabase-session"])
        XCTAssertTrue(reader.hasStoredSession())
    }

    func testServerAndMalformedRefreshKeepStoredSession() async throws {
        for step in [ScriptedReadTransport.Step.response(503, "{}"), .response(200, "{}") ] {
            let store = try sessionStore(expired: true)
            let reader = SupabaseExperienceReader(
                configuration: configuration,
                secureStore: store,
                transport: ScriptedReadTransport([step])
            )
            do { _ = try await reader.restoreSession(); XCTFail("invalid refresh succeeded") }
            catch { XCTAssertNotNil(error as? ExperienceReadError) }
            XCTAssertNotNil(store.values["supabase-session"])
        }
    }

    func testAuthoritativeRefreshInvalidationClearsStoredSession() async throws {
        let store = try sessionStore(expired: true)
        let reader = SupabaseExperienceReader(
            configuration: configuration,
            secureStore: store,
            transport: ScriptedReadTransport([.response(400, "{\"error_code\":\"refresh_token_not_found\"}")])
        )
        do { _ = try await reader.restoreSession(); XCTFail("revoked refresh succeeded") }
        catch { XCTAssertEqual(error as? ExperienceReadError, .unauthorized("The jOS session expired. Sign in again.")) }
        XCTAssertNil(store.values["supabase-session"])
    }

    func testMalformedLocalSessionIsTheOnlyLocalDecodeClear() async throws {
        let store = MemoryReadStore()
        store.values["supabase-session"] = Data("not-json".utf8)
        let reader = SupabaseExperienceReader(configuration: configuration, secureStore: store, transport: ScriptedReadTransport([]))
        do { _ = try await reader.restoreSession(); XCTFail("malformed local session succeeded") }
        catch { XCTAssertEqual(error as? ExperienceReadError, .malformedLocalSession) }
        XCTAssertNil(store.values["supabase-session"])
    }

    func testWorkspaceBindingAndBoundedSnapshotDecode() async throws {
        let workspaces = """
        [{"workspace_id":"\(workspaceID.uuidString)","role":"viewer","workspaces":{"id":"\(workspaceID.uuidString)","name":"Personal"}}]
        """
        let snapshot = snapshotJSON(plannedCount: 24, currentCategory: nil, truncated: true)
        let transport = ScriptedReadTransport([
            .response(200, workspaces),
            .response(200, workspaces),
            .response(200, snapshot)
        ])
        let reader = SupabaseExperienceReader(
            configuration: configuration,
            secureStore: try sessionStore(),
            transport: transport
        )
        let restored = try await reader.restoreSession()
        let authorized = try await reader.authorizedWorkspaces()
        XCTAssertTrue(restored)
        XCTAssertEqual(authorized.first?.role, "viewer")
        try await reader.bind(workspaceID: workspaceID)
        let value = try await reader.snapshot(windowStart: .distantPast, windowEnd: .distantFuture)
        XCTAssertEqual(value.apiVersion, "mac_read_v1")
        XCTAssertNil(value.current?.categoryKey)
        XCTAssertEqual(value.planned.count, 24)
        XCTAssertTrue(value.plannedTruncated)
        XCTAssertEqual(transport.requests.last?.url?.path, "/rest/v1/rpc/mac_read_snapshot_v1")
    }

    func testForeignWorkspaceBindingFailsClosed() async throws {
        let workspaces = """
        [{"workspace_id":"\(workspaceID.uuidString)","role":"owner","workspaces":{"id":"\(workspaceID.uuidString)","name":"Personal"}}]
        """
        let reader = SupabaseExperienceReader(
            configuration: configuration,
            secureStore: try sessionStore(),
            transport: ScriptedReadTransport([.response(200, workspaces)])
        )
        let restored = try await reader.restoreSession()
        XCTAssertTrue(restored)
        do { try await reader.bind(workspaceID: UUID()); XCTFail("foreign workspace bound") }
        catch { XCTAssertEqual(error as? ExperienceReadError, .unauthorized("That workspace is not authorized for this account.")) }
    }

    func testSignOutClearsLocalSessionEvenWhenLogoutIsUnavailable() async throws {
        let store = try sessionStore()
        let reader = SupabaseExperienceReader(
            configuration: configuration,
            secureStore: store,
            transport: ScriptedReadTransport([.response(503, "{}")])
        )
        let restored = try await reader.restoreSession()
        XCTAssertTrue(restored)
        do { try await reader.signOut(); XCTFail("remote failure hidden") }
        catch { XCTAssertEqual(error as? ExperienceReadError, .server("Signed out locally; server revocation was unavailable.")) }
        XCTAssertNil(store.values["supabase-session"])
    }

    func testEndpointAllowlistContainsOnlyAuthMembershipSnapshotAndLogout() {
        XCTAssertEqual(SupabaseExperienceReader.allowedEndpointSignatures, Set([
            "POST /auth/v1/otp",
            "POST /auth/v1/token?grant_type=pkce",
            "POST /auth/v1/token?grant_type=refresh_token",
            "POST /auth/v1/logout?scope=local",
            "GET /rest/v1/workspace_memberships",
            "POST /rest/v1/rpc/mac_read_snapshot_v1"
        ]))
        XCTAssertFalse(SupabaseExperienceReader.allowedEndpointSignatures.contains { $0.contains("start") || $0.contains("stop") || $0.contains("notion") })
    }

    func testDedicatedKeychainNamespaceRoundTrip() throws {
        let store = NamespacedExperienceReadKeychain(bundleID: "jta.jos.tasks.macos.tests", projectNamespace: UUID().uuidString)
        let account = "probe-\(UUID().uuidString)"
        defer { try? store.delete(account: account) }
        try store.save(Data("probe".utf8), account: account)
        XCTAssertEqual(try store.read(account: account), Data("probe".utf8))
        try store.delete(account: account)
        XCTAssertNil(try store.read(account: account))
    }

    func testActiveTargetInventoryIsReadOnlyAndNotionFree() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let project = try String(contentsOf: root.appendingPathComponent("jOS-Tasks.xcodeproj/project.pbxproj"), encoding: .utf8)
        let phaseStart = try XCTUnwrap(project.range(of: "6B9281862ACAC57C00E39EF4 /* Sources */ = {")).lowerBound
        let phaseEnd = try XCTUnwrap(project.range(of: "/* End PBXSourcesBuildPhase section */", range: phaseStart..<project.endIndex)).lowerBound
        let activePhase = String(project[phaseStart..<phaseEnd])
        for dormant in ["NotionAPI.swift", "NotionController.swift", "MenuBarView.swift", "TaskListView.swift", "TimeEntry.swift"] {
            XCTAssertFalse(activePhase.contains(dormant), "\(dormant) must not compile")
        }

        let activeFiles = [
            "jOS-Tasks/jOS_TasksApp.swift",
            "jOS-Tasks/ExperienceRead.swift",
            "jOS-Tasks/ExperienceReadModel.swift",
            "jOS-Tasks/Views/ExperienceReadMenuView.swift"
        ]
        let forbidden = [
            "api.notion.com", "NotionController", "NotionAPI", "start_planned_experience",
            "stop_current_experience", "ExperienceCommand", "request_receipt", "command_receipt"
        ]
        let activeSource = try activeFiles.map {
            try String(contentsOf: root.appendingPathComponent($0), encoding: .utf8)
        }.joined(separator: "\n")
        for value in forbidden { XCTAssertFalse(activeSource.localizedCaseInsensitiveContains(value), "found forbidden active source: \(value)") }

        let menuSource = try String(contentsOf: root.appendingPathComponent("jOS-Tasks/Views/ExperienceReadMenuView.swift"), encoding: .utf8)
        XCTAssertTrue(menuSource.contains("ScrollView"))
        XCTAssertTrue(menuSource.contains(".focusable()"))
        XCTAssertTrue(menuSource.contains("frame(maxHeight: 480)"))
    }

    private func authJSON() -> String {
        """
        {"access_token":"access","refresh_token":"refresh","expires_in":3600,"user":{"id":"\(userID.uuidString)"}}
        """
    }

    private func sessionStore(expired: Bool = false) throws -> MemoryReadStore {
        let store = MemoryReadStore()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        store.values["supabase-session"] = try encoder.encode(ExperienceReadSession(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(expired ? -60 : 3600),
            userID: userID
        ))
        return store
    }

    private func legacyJWT(algorithm: String, role: String, expiration: Int) -> String {
        func encode(_ object: [String: Any]) -> String {
            let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            return data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let signature = Data(repeating: 7, count: 32).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "\(encode(["alg": algorithm, "typ": "JWT"])).\(encode(["role": role, "exp": expiration])).\(signature)"
    }

    private func snapshotJSON(plannedCount: Int, currentCategory: String?, truncated: Bool) -> String {
        let currentCategoryJSON = currentCategory.map { "\"\($0)\"" } ?? "null"
        let current = """
        {"experience_id":"65000000-0000-4000-8000-000000000010","actual_id":"65000000-0000-4000-8000-000000000011","title":"Current","description":null,"category_key":\(currentCategoryJSON),"project_id":null,"task_ids":[],"intended_starts_at":null,"intended_ends_at":null,"actual_starts_at":"2026-09-03T13:00:00Z"}
        """
        let planned = (0..<plannedCount).map { index in
            let suffix = String(format: "%012d", index + 100)
            return """
            {"experience_id":"65000000-0000-4000-8001-\(suffix)","actual_id":null,"title":"Plan \(index + 1)","description":null,"category_key":"work","project_id":null,"task_ids":[],"intended_starts_at":"2026-09-03T15:00:00Z","intended_ends_at":"2026-09-03T16:00:00Z","actual_starts_at":null}
            """
        }.joined(separator: ",")
        return """
        {"api_version":"mac_read_v1","workspace_id":"\(workspaceID.uuidString)","generated_at":"2026-09-03T14:00:00Z","window_starts_at":"2026-09-03T00:00:00Z","window_ends_at":"2026-09-04T00:00:00Z","current":\(current),"planned":[\(planned)],"planned_limit":24,"planned_truncated":\(truncated)}
        """
    }
}

@MainActor
final class ExperienceReadModelTests: XCTestCase {
    private let workspace = ReadableWorkspace(id: UUID(), name: "Personal", role: "owner")

    func testZeroOneAndSeveralWorkspaceStates() async {
        let empty = InMemoryExperienceReader()
        empty.hasSession = true
        let emptyModel = ExperienceReadModel(reader: empty)
        await emptyModel.start()
        XCTAssertEqual(emptyModel.state, .unauthorized("No authorized jOS workspace is available."))
        XCTAssertTrue(emptyModel.hasRetainedSession)

        let zero = readyReader(plannedCount: 0)
        let zeroModel = ExperienceReadModel(reader: zero)
        await zeroModel.start()
        guard case .synced = zeroModel.state else { return XCTFail("zero-row workspace did not load") }
        XCTAssertEqual(zeroModel.snapshot?.planned.count, 0)

        let one = readyReader(plannedCount: 1)
        let oneModel = ExperienceReadModel(reader: one)
        await oneModel.start()
        guard case .synced = oneModel.state else { return XCTFail("one workspace did not load") }
        XCTAssertEqual(oneModel.snapshot?.planned.count, 1)

        let several = readyReader(plannedCount: 0)
        several.workspaces.append(ReadableWorkspace(id: UUID(), name: "Other", role: "viewer"))
        let severalModel = ExperienceReadModel(reader: several)
        await severalModel.start()
        XCTAssertEqual(severalModel.state, .choosingWorkspace)
        XCTAssertNil(several.activeWorkspaceID)
    }

    func testOfflineReloadKeepsLastSnapshotAndRecoveryControls() async {
        let reader = readyReader(plannedCount: 1)
        let model = ExperienceReadModel(reader: reader)
        await model.start()
        reader.nextError = .offline("offline; session kept")
        await model.reload()
        XCTAssertEqual(model.state, .offline("offline; session kept"))
        XCTAssertNotNil(model.snapshot)
        XCTAssertTrue(model.hasRetainedSession)
        await model.recover()
        guard case .synced = model.state else { return XCTFail("reload did not recover") }
        XCTAssertEqual(reader.snapshotCalls, 3)
    }

    func testTwentyFourRowsOverflowInsideFixedMenuAndRemainScrollable() async throws {
        let reader = readyReader(plannedCount: 24, truncated: true)
        let model = ExperienceReadModel(reader: reader)
        await model.start()
        let host = NSHostingView(rootView: ExperienceReadMenuView(model: model))
        host.frame = NSRect(x: 0, y: 0, width: 380, height: 480)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        try await _Concurrency.Task.sleep(for: .milliseconds(50))
        host.layoutSubtreeIfNeeded()
        let scrollView = try XCTUnwrap(allSubviews(of: host).compactMap { $0 as? NSScrollView }.first)
        scrollView.layoutSubtreeIfNeeded()
        let documentHeight = scrollView.documentView?.bounds.height ?? 0
        XCTAssertGreaterThan(documentHeight, scrollView.contentView.bounds.height)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: max(0, documentHeight - scrollView.contentView.bounds.height)))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        XCTAssertGreaterThan(scrollView.contentView.bounds.origin.y, 0)
        XCTAssertEqual(model.snapshot?.planned.last?.title, "Plan 24")
        XCTAssertTrue(model.snapshot?.plannedTruncated == true)
    }

    private func allSubviews(of root: NSView) -> [NSView] {
        root.subviews + root.subviews.flatMap(allSubviews)
    }

    private func readyReader(plannedCount: Int, truncated: Bool = false) -> InMemoryExperienceReader {
        let reader = InMemoryExperienceReader()
        reader.hasSession = true
        reader.workspaces = [workspace]
        let now = Date()
        let planned = (0..<plannedCount).map { index in
            ReadableExperience(
                experienceID: UUID(), actualID: nil, title: "Plan \(index + 1)", description: nil,
                categoryKey: "work", projectID: nil, taskIDs: [],
                intendedStartsAt: now.addingTimeInterval(Double(index * 60)),
                intendedEndsAt: now.addingTimeInterval(Double(index * 60 + 1800)), actualStartsAt: nil
            )
        }
        reader.value = ExperienceReadSnapshot(
            apiVersion: "mac_read_v1", workspaceID: workspace.id, generatedAt: now,
            windowStartsAt: now, windowEndsAt: now.addingTimeInterval(86_400), current: nil,
            planned: planned, plannedLimit: 24, plannedTruncated: truncated
        )
        return reader
    }
}
