import CryptoKit
import Foundation
import Security

struct ExperienceControlConfiguration: Equatable {
    let supabaseURL: URL
    let publishableKey: String
    let callbackURL = URL(string: "jos://auth/callback")!

    var projectNamespace: String { supabaseURL.host?.split(separator: ".").first.map(String.init) ?? "unknown-project" }

    static func bundled(bundle: Bundle = .main, environment: [String: String] = ProcessInfo.processInfo.environment) throws -> Self {
        let urlValue = environment["JOS_SUPABASE_URL"] ?? bundle.object(forInfoDictionaryKey: "JOSSupabaseURL") as? String ?? ""
        let keyValue = environment["JOS_SUPABASE_KEY"] ?? bundle.object(forInfoDictionaryKey: "JOSSupabaseKey") as? String ?? ""
        guard let url = URL(string: urlValue), url.scheme == "https" || url.host == "127.0.0.1" || url.host == "localhost" else {
            throw ExperienceControlError.configuration("A valid jOS Supabase URL is required.")
        }
        guard !keyValue.isEmpty, !keyValue.hasPrefix("sb_secret_"), Self.jwtRole(keyValue) != "service_role" else {
            throw ExperienceControlError.configuration("A public or publishable Supabase key is required.")
        }
        return Self(supabaseURL: url, publishableKey: keyValue)
    }

    private static func jwtRole(_ value: String) -> String? {
        let parts = value.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object["role"] as? String
    }
}

struct ExperienceControlSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userID: UUID
}

struct ExperienceWorkspace: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let role: String
}

struct ControlledExperience: Codable, Identifiable, Equatable {
    let experienceID: UUID
    let actualID: UUID?
    let title: String
    let description: String?
    let categoryKey: String
    let projectID: UUID?
    let taskIDs: [UUID]
    let intendedStartsAt: Date?
    let intendedEndsAt: Date?
    let actualStartsAt: Date?
    var id: UUID { experienceID }
    enum CodingKeys: String, CodingKey {
        case experienceID = "experience_id", actualID = "actual_id", title, description
        case categoryKey = "category_key", projectID = "project_id", taskIDs = "task_ids"
        case intendedStartsAt = "intended_starts_at", intendedEndsAt = "intended_ends_at", actualStartsAt = "actual_starts_at"
    }
}

struct ExperienceControlSnapshot: Codable, Equatable {
    let apiVersion: String
    let workspaceID: UUID
    let generatedAt: Date
    let windowStartsAt: Date
    let windowEndsAt: Date
    let current: ControlledExperience?
    let planned: [ControlledExperience]
    enum CodingKeys: String, CodingKey {
        case apiVersion = "api_version", workspaceID = "workspace_id", generatedAt = "generated_at"
        case windowStartsAt = "window_starts_at", windowEndsAt = "window_ends_at", current, planned
    }
}

struct ExperienceCommandResult: Codable, Equatable {
    let experienceID: UUID
    let actualID: UUID
    let eventID: UUID
    let source: String
    enum CodingKeys: String, CodingKey { case experienceID = "experience_id", actualID = "actual_id", eventID = "event_id", source }
}

enum ExperienceControlError: Error, Equatable, LocalizedError {
    case configuration(String), unauthorized(String), offline(String), stale(String), server(String), ambiguous(String)
    case invalidCallback

    var errorDescription: String? {
        switch self {
        case .configuration(let message), .unauthorized(let message), .offline(let message), .stale(let message), .server(let message), .ambiguous(let message): return message
        case .invalidCallback: return "The sign-in callback was not the exact jos://auth/callback URL."
        }
    }
}

protocol ExperienceControl: AnyObject {
    func restoreSession() async throws -> Bool
    func requestSignIn(email: String) async throws
    func completeSignIn(callbackURL: URL) async throws
    func writablePersonalWorkspaces() async throws -> [ExperienceWorkspace]
    func bind(workspaceID: UUID) async throws
    func snapshot(windowStart: Date, windowEnd: Date) async throws -> ExperienceControlSnapshot
    func start(experienceID: UUID, expectedOpenActualID: UUID?, at: Date, requestID: UUID) async throws -> ExperienceCommandResult
    func stop(experienceID: UUID, expectedActualID: UUID, at: Date, requestID: UUID) async throws -> ExperienceCommandResult
    func signOut() async throws
}

protocol ExperienceSecureStore {
    func read(account: String) throws -> Data?
    func save(_ data: Data, account: String) throws
    func delete(account: String) throws
}

final class NamespacedKeychainStore: ExperienceSecureStore {
    private let service: String
    init(bundleID: String = Bundle.main.bundleIdentifier ?? "jta.jos.tasks.macos", projectNamespace: String) {
        service = "\(bundleID).\(projectNamespace).experience-control-v1"
    }
    func read(account: String) throws -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw ExperienceControlError.server("Keychain read failed (\(status)).") }
        return data
    }
    func save(_ data: Data, account: String) throws {
        let identity: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        let attributes: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status: OSStatus
        if try read(account: account) == nil { status = SecItemAdd(identity.merging(attributes) { _, new in new } as CFDictionary, nil) }
        else { status = SecItemUpdate(identity as CFDictionary, attributes as CFDictionary) }
        guard status == errSecSuccess else { throw ExperienceControlError.server("Keychain write failed (\(status)).") }
    }
    func delete(account: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw ExperienceControlError.server("Keychain delete failed (\(status)).") }
    }
}

protocol ExperienceHTTPTransport { func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) }

final class URLSessionExperienceTransport: ExperienceHTTPTransport {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ExperienceControlError.ambiguous("jOS returned no HTTP response.") }
            return (data, http)
        } catch let error as URLError where [.notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost].contains(error.code) {
            throw ExperienceControlError.offline("jOS is offline. Nothing was queued.")
        } catch let error as ExperienceControlError { throw error }
        catch { throw ExperienceControlError.ambiguous("The result is uncertain. Reload authoritative state before a deliberate retry.") }
    }
}

final class SupabaseExperienceControl: ExperienceControl {
    private let configuration: ExperienceControlConfiguration
    private let secureStore: ExperienceSecureStore
    private let transport: ExperienceHTTPTransport
    private var session: ExperienceControlSession?
    private var workspaceID: UUID?
    private let encoder = JSONEncoder()
    private let decoder: JSONDecoder
    private let sessionAccount = "supabase-session"
    private let pkceAccount = "pkce-verifier"

    init(configuration: ExperienceControlConfiguration, secureStore: ExperienceSecureStore? = nil, transport: ExperienceHTTPTransport = URLSessionExperienceTransport()) {
        self.configuration = configuration
        self.secureStore = secureStore ?? NamespacedKeychainStore(projectNamespace: configuration.projectNamespace)
        self.transport = transport
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.fractional.date(from: value) ?? ISO8601DateFormatter.standard.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date")
        }
        encoder.dateEncodingStrategy = .iso8601
    }

    func restoreSession() async throws -> Bool {
        guard let data = try secureStore.read(account: sessionAccount) else { return false }
        var restored = try decoder.decode(ExperienceControlSession.self, from: data)
        if restored.expiresAt <= Date().addingTimeInterval(30) { restored = try await refresh(restored) }
        session = restored
        return true
    }

    func requestSignIn(email: String) async throws {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.contains("@") else { throw ExperienceControlError.server("Enter a valid email address.") }
        let verifier = Self.pkceVerifier()
        try secureStore.save(Data(verifier.utf8), account: pkceAccount)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
        var request = try makeRequest(path: "/auth/v1/otp", method: "POST", authenticated: false)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": normalized, "create_user": false, "email_redirect_to": configuration.callbackURL.absoluteString, "code_challenge": challenge, "code_challenge_method": "s256"])
        _ = try await send(request, expected: 200..<300)
    }

    func completeSignIn(callbackURL: URL) async throws {
        guard callbackURL.scheme == "jos", callbackURL.host == "auth", callbackURL.path == "/callback", callbackURL.user == nil, callbackURL.password == nil, callbackURL.port == nil,
              let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value,
              let verifierData = try secureStore.read(account: pkceAccount), let verifier = String(data: verifierData, encoding: .utf8) else { throw ExperienceControlError.invalidCallback }
        var request = try makeRequest(path: "/auth/v1/token?grant_type=pkce", method: "POST", authenticated: false)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["auth_code": code, "code_verifier": verifier])
        session = try persistAuthResponse(try await send(request, expected: 200..<300))
        try secureStore.delete(account: pkceAccount)
    }

    func writablePersonalWorkspaces() async throws -> [ExperienceWorkspace] {
        let active = try await activeSession()
        let query = "/rest/v1/workspace_memberships?select=workspace_id,role,workspaces(id,name,created_by)&user_id=eq.\(active.userID.uuidString.lowercased())"
        let data = try await send(try makeRequest(path: query, method: "GET"), expected: 200..<300)
        struct Row: Decodable {
            let workspaceID: UUID; let role: String; let workspaces: WorkspaceRow
            enum CodingKeys: String, CodingKey { case workspaceID = "workspace_id", role, workspaces }
        }
        struct WorkspaceRow: Decodable {
            let id: UUID; let name: String; let createdBy: UUID
            enum CodingKeys: String, CodingKey { case id, name, createdBy = "created_by" }
        }
        return try decoder.decode([Row].self, from: data)
            .filter { ["owner", "editor"].contains($0.role) && $0.workspaces.createdBy == active.userID }
            .map { ExperienceWorkspace(id: $0.workspaceID, name: $0.workspaces.name, role: $0.role) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func bind(workspaceID: UUID) async throws {
        guard try await writablePersonalWorkspaces().contains(where: { $0.id == workspaceID }) else { throw ExperienceControlError.unauthorized("That workspace is not a writable personal workspace.") }
        self.workspaceID = workspaceID
    }

    func snapshot(windowStart: Date, windowEnd: Date) async throws -> ExperienceControlSnapshot {
        try await rpc("experience_control_snapshot_v1", body: ["p_workspace_id": try boundWorkspace().uuidString.lowercased(), "p_window_starts_at": windowStart.iso8601, "p_window_ends_at": windowEnd.iso8601], as: ExperienceControlSnapshot.self)
    }

    func start(experienceID: UUID, expectedOpenActualID: UUID?, at: Date, requestID: UUID) async throws -> ExperienceCommandResult {
        var body: [String: Any] = ["p_workspace_id": try boundWorkspace().uuidString.lowercased(), "p_experience_id": experienceID.uuidString.lowercased(), "p_started_at": at.iso8601, "p_request_id": requestID.uuidString.lowercased()]
        body["p_expected_open_actual_id"] = expectedOpenActualID?.uuidString.lowercased() ?? NSNull()
        return try await rpc("start_planned_experience_v1", body: body, as: ExperienceCommandResult.self)
    }

    func stop(experienceID: UUID, expectedActualID: UUID, at: Date, requestID: UUID) async throws -> ExperienceCommandResult {
        try await rpc("stop_current_experience_v1", body: ["p_workspace_id": try boundWorkspace().uuidString.lowercased(), "p_experience_id": experienceID.uuidString.lowercased(), "p_expected_actual_id": expectedActualID.uuidString.lowercased(), "p_stopped_at": at.iso8601, "p_request_id": requestID.uuidString.lowercased()], as: ExperienceCommandResult.self)
    }

    func signOut() async throws {
        var revocationFailed = false
        if session != nil { do { _ = try await send(try makeRequest(path: "/auth/v1/logout?scope=local", method: "POST"), expected: 200..<300) } catch { revocationFailed = true } }
        session = nil; workspaceID = nil
        try secureStore.delete(account: sessionAccount); try? secureStore.delete(account: pkceAccount)
        if revocationFailed { throw ExperienceControlError.server("Signed out locally; server revocation failed.") }
    }

    private func rpc<T: Decodable>(_ name: String, body: [String: Any], as type: T.Type) async throws -> T {
        var request = try makeRequest(path: "/rest/v1/rpc/\(name)", method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let data = try await send(request, expected: 200..<300)
        do { return try decoder.decode(type, from: data) } catch { throw ExperienceControlError.server("jOS returned an invalid \(name) response.") }
    }

    private func makeRequest(path: String, method: String, authenticated: Bool = true) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: configuration.supabaseURL) else { throw ExperienceControlError.configuration("Invalid jOS endpoint.") }
        var request = URLRequest(url: url); request.httpMethod = method
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey"); request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated {
            guard let token = session?.accessToken else { throw ExperienceControlError.unauthorized("Sign in to jOS.") }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send(_ request: URLRequest, expected: Range<Int>) async throws -> Data {
        let (data, response) = try await transport.data(for: request)
        guard expected.contains(response.statusCode) else {
            let payload = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let code = payload["code"] as? String, message = payload["message"] as? String ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
            if response.statusCode == 401 || response.statusCode == 403 || code == "42501" { throw ExperienceControlError.unauthorized(message) }
            if response.statusCode == 409 || code == "40001" { throw ExperienceControlError.stale(message) }
            throw ExperienceControlError.server(message)
        }
        return data
    }

    private func activeSession() async throws -> ExperienceControlSession {
        guard var active = session else { throw ExperienceControlError.unauthorized("Sign in to jOS.") }
        if active.expiresAt <= Date().addingTimeInterval(30) { active = try await refresh(active); session = active }
        return active
    }
    private func refresh(_ current: ExperienceControlSession) async throws -> ExperienceControlSession {
        var request = try makeRequest(path: "/auth/v1/token?grant_type=refresh_token", method: "POST", authenticated: false)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": current.refreshToken])
        do { return try persistAuthResponse(try await send(request, expected: 200..<300)) }
        catch { try? secureStore.delete(account: sessionAccount); session = nil; throw ExperienceControlError.unauthorized("The jOS session expired. Sign in again.") }
    }
    private func persistAuthResponse(_ data: Data) throws -> ExperienceControlSession {
        struct Response: Decodable {
            let accessToken: String; let refreshToken: String; let expiresIn: Double; let user: User
            struct User: Decodable { let id: UUID }
            enum CodingKeys: String, CodingKey { case accessToken = "access_token", refreshToken = "refresh_token", expiresIn = "expires_in", user }
        }
        let response = try decoder.decode(Response.self, from: data)
        let value = ExperienceControlSession(accessToken: response.accessToken, refreshToken: response.refreshToken, expiresAt: Date().addingTimeInterval(response.expiresIn), userID: response.user.id)
        try secureStore.save(try encoder.encode(value), account: sessionAccount)
        return value
    }
    private func boundWorkspace() throws -> UUID {
        guard session != nil else { throw ExperienceControlError.unauthorized("Sign in to jOS.") }
        guard let workspaceID else { throw ExperienceControlError.unauthorized("Choose a writable personal workspace.") }
        return workspaceID
    }
    private static func pkceVerifier() -> String { var bytes = [UInt8](repeating: 0, count: 32); _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes); return Data(bytes).base64URLEncodedString() }
}

final class InMemoryExperienceControl: ExperienceControl {
    var hasSession = false, workspaces: [ExperienceWorkspace] = []
    var activeWorkspaceID: UUID?, value: ExperienceControlSnapshot?, nextError: ExperienceControlError?
    var requests: [(kind: String, requestID: UUID)] = []
    func restoreSession() async throws -> Bool { hasSession }
    func requestSignIn(email: String) async throws { requests.append(("sign-in", UUID())) }
    func completeSignIn(callbackURL: URL) async throws { hasSession = true }
    func writablePersonalWorkspaces() async throws -> [ExperienceWorkspace] { workspaces }
    func bind(workspaceID: UUID) async throws { activeWorkspaceID = workspaceID }
    func snapshot(windowStart: Date, windowEnd: Date) async throws -> ExperienceControlSnapshot { if let nextError { self.nextError = nil; throw nextError }; guard let value else { throw ExperienceControlError.server("No in-memory snapshot.") }; return value }
    func start(experienceID: UUID, expectedOpenActualID: UUID?, at: Date, requestID: UUID) async throws -> ExperienceCommandResult { requests.append(("start", requestID)); if let nextError { self.nextError = nil; throw nextError }; return ExperienceCommandResult(experienceID: experienceID, actualID: UUID(), eventID: UUID(), source: "jos.mac.menu.v1") }
    func stop(experienceID: UUID, expectedActualID: UUID, at: Date, requestID: UUID) async throws -> ExperienceCommandResult { requests.append(("stop", requestID)); if let nextError { self.nextError = nil; throw nextError }; return ExperienceCommandResult(experienceID: experienceID, actualID: expectedActualID, eventID: UUID(), source: "jos.mac.menu.v1") }
    func signOut() async throws { hasSession = false; activeWorkspaceID = nil }
}

private extension Data { func base64URLEncodedString() -> String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") } }
private extension ISO8601DateFormatter {
    static let standard: ISO8601DateFormatter = { ISO8601DateFormatter() }()
    static let fractional: ISO8601DateFormatter = { let value = ISO8601DateFormatter(); value.formatOptions.insert(.withFractionalSeconds); return value }()
}
private extension Date { var iso8601: String { ISO8601DateFormatter.fractional.string(from: self) } }
