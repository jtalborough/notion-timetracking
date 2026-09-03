import CryptoKit
import Foundation
import Security

struct ExperienceReadConfiguration: Equatable {
    let supabaseURL: URL
    let publishableKey: String
    let trustedCredentialSHA256: String
    let callbackURL = URL(string: "jos://auth/callback")!

    var projectNamespace: String {
        supabaseURL.host?.split(separator: ".").first.map(String.init) ?? "unknown-project"
    }

    init(
        supabaseURL: URL,
        publishableKey: String,
        trustedCredentialSHA256: String,
        now: Date = Date()
    ) throws {
        guard Self.isAllowedURL(supabaseURL) else {
            throw ExperienceReadError.configuration("A valid jOS Supabase URL is required.")
        }
        let normalizedFingerprint = trustedCredentialSHA256.lowercased()
        guard normalizedFingerprint.count == 64,
              normalizedFingerprint.allSatisfy(\.isHexDigit),
              Self.sha256(publishableKey) == normalizedFingerprint,
              Self.isStructurallyPublicCredential(publishableKey, now: now) else {
            throw ExperienceReadError.configuration("The jOS public credential is not trusted.")
        }
        self.supabaseURL = supabaseURL
        self.publishableKey = publishableKey
        self.trustedCredentialSHA256 = normalizedFingerprint
    }

    static func bundled(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> Self {
        let urlValue = environment["JOS_SUPABASE_URL"]
            ?? bundle.object(forInfoDictionaryKey: "JOSSupabaseURL") as? String
            ?? ""
        let keyValue = environment["JOS_SUPABASE_KEY"]
            ?? bundle.object(forInfoDictionaryKey: "JOSSupabaseKey") as? String
            ?? ""
        let fingerprint = environment["JOS_SUPABASE_KEY_SHA256"]
            ?? bundle.object(forInfoDictionaryKey: "JOSSupabaseKeySHA256") as? String
            ?? ""
        guard let url = URL(string: urlValue) else {
            throw ExperienceReadError.configuration("A valid jOS Supabase URL is required.")
        }
        return try Self(
            supabaseURL: url,
            publishableKey: keyValue,
            trustedCredentialSHA256: fingerprint
        )
    }

    static func fingerprint(for credential: String) -> String { sha256(credential) }

    private static func isAllowedURL(_ value: URL) -> Bool {
        guard value.user == nil, value.password == nil, value.query == nil, value.fragment == nil,
              value.path.isEmpty || value.path == "/" else { return false }
        if value.scheme == "https", value.port == nil,
           let host = value.host, host.hasSuffix(".supabase.co"), host.split(separator: ".").count == 3 {
            return true
        }
        return value.scheme == "http" && (value.host == "127.0.0.1" || value.host == "localhost")
    }

    private static func isStructurallyPublicCredential(_ value: String, now: Date) -> Bool {
        if value.hasPrefix("sb_publishable_") {
            let suffix = value.dropFirst("sb_publishable_".count)
            return suffix.count >= 24 && suffix.count <= 256
                && suffix.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        }

        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let header = decodedJSONObject(String(parts[0])),
              let payload = decodedJSONObject(String(parts[1])),
              header["alg"] as? String == "HS256",
              payload["role"] as? String == "anon",
              let expiration = (payload["exp"] as? NSNumber)?.doubleValue,
              expiration > now.timeIntervalSince1970,
              let signature = decodedBase64URL(String(parts[2])),
              signature.count >= 32 else { return false }
        return true
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func decodedJSONObject(_ value: String) -> [String: Any]? {
        guard let data = decodedBase64URL(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func decodedBase64URL(_ value: String) -> Data? {
        guard !value.isEmpty,
              value.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else { return nil }
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return Data(base64Encoded: base64)
    }
}

struct ExperienceReadSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userID: UUID
}

struct ReadableWorkspace: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let role: String
}

struct ReadableExperience: Codable, Identifiable, Equatable {
    let experienceID: UUID
    let actualID: UUID?
    let title: String
    let description: String?
    let categoryKey: String?
    let projectID: UUID?
    let taskIDs: [UUID]
    let intendedStartsAt: Date?
    let intendedEndsAt: Date?
    let actualStartsAt: Date?

    var id: UUID { experienceID }

    enum CodingKeys: String, CodingKey {
        case experienceID = "experience_id"
        case actualID = "actual_id"
        case title, description
        case categoryKey = "category_key"
        case projectID = "project_id"
        case taskIDs = "task_ids"
        case intendedStartsAt = "intended_starts_at"
        case intendedEndsAt = "intended_ends_at"
        case actualStartsAt = "actual_starts_at"
    }
}

struct ExperienceReadSnapshot: Codable, Equatable {
    let apiVersion: String
    let workspaceID: UUID
    let generatedAt: Date
    let windowStartsAt: Date
    let windowEndsAt: Date
    let current: ReadableExperience?
    let planned: [ReadableExperience]
    let plannedLimit: Int
    let plannedTruncated: Bool

    enum CodingKeys: String, CodingKey {
        case apiVersion = "api_version"
        case workspaceID = "workspace_id"
        case generatedAt = "generated_at"
        case windowStartsAt = "window_starts_at"
        case windowEndsAt = "window_ends_at"
        case current, planned
        case plannedLimit = "planned_limit"
        case plannedTruncated = "planned_truncated"
    }
}

enum ExperienceReadError: Error, Equatable, LocalizedError {
    case configuration(String)
    case unauthorized(String)
    case offline(String)
    case server(String)
    case malformedLocalSession
    case invalidCallback

    var errorDescription: String? {
        switch self {
        case .configuration(let message), .unauthorized(let message), .offline(let message), .server(let message):
            return message
        case .malformedLocalSession:
            return "The saved jOS session was invalid and was cleared. Sign in again."
        case .invalidCallback:
            return "The sign-in callback was not exactly jos://auth/callback?code=<one value>."
        }
    }
}

protocol ExperienceReading: AnyObject {
    func hasStoredSession() -> Bool
    func restoreSession() async throws -> Bool
    func requestSignIn(email: String) async throws
    func completeSignIn(callbackURL: URL) async throws
    func authorizedWorkspaces() async throws -> [ReadableWorkspace]
    func bind(workspaceID: UUID) async throws
    func snapshot(windowStart: Date, windowEnd: Date) async throws -> ExperienceReadSnapshot
    func signOut() async throws
}

protocol ExperienceReadSecureStore {
    func read(account: String) throws -> Data?
    func save(_ data: Data, account: String) throws
    func delete(account: String) throws
}

final class NamespacedExperienceReadKeychain: ExperienceReadSecureStore {
    private let service: String

    init(bundleID: String = Bundle.main.bundleIdentifier ?? "jta.jos.tasks.macos", projectNamespace: String) {
        service = "\(bundleID).\(projectNamespace).experience-read-v1"
    }

    func read(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw ExperienceReadError.server("Keychain read failed (\(status)).")
        }
        return data
    }

    func save(_ data: Data, account: String) throws {
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status: OSStatus
        if try read(account: account) == nil {
            status = SecItemAdd(identity.merging(attributes) { _, new in new } as CFDictionary, nil)
        } else {
            status = SecItemUpdate(identity as CFDictionary, attributes as CFDictionary)
        }
        guard status == errSecSuccess else {
            throw ExperienceReadError.server("Keychain write failed (\(status)).")
        }
    }

    func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ExperienceReadError.server("Keychain delete failed (\(status)).")
        }
    }
}

protocol ExperienceReadHTTPTransport {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

final class URLSessionExperienceReadTransport: ExperienceReadHTTPTransport {
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw ExperienceReadError.server("jOS returned no HTTP response; the saved session was kept.")
            }
            return (data, response)
        } catch let error as URLError {
            throw ExperienceReadError.offline(Self.offlineMessage(for: error.code))
        } catch let error as ExperienceReadError {
            throw error
        } catch {
            throw ExperienceReadError.server("jOS could not be reached; the saved session was kept.")
        }
    }

    private static func offlineMessage(for code: URLError.Code) -> String {
        switch code {
        case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost:
            return "jOS is offline. Your saved session was kept; reload after reconnecting."
        default:
            return "The jOS connection was interrupted. Your saved session was kept; reload to try again."
        }
    }
}

final class SupabaseExperienceReader: ExperienceReading {
    static let allowedEndpointSignatures: Set<String> = [
        "POST /auth/v1/otp",
        "POST /auth/v1/token?grant_type=pkce",
        "POST /auth/v1/token?grant_type=refresh_token",
        "POST /auth/v1/logout?scope=local",
        "GET /rest/v1/workspace_memberships",
        "POST /rest/v1/rpc/mac_read_snapshot_v1"
    ]

    private enum Endpoint {
        case otp
        case pkceToken
        case refreshToken
        case logout
        case memberships(userID: UUID)
        case snapshot

        var method: String {
            switch self {
            case .memberships: return "GET"
            default: return "POST"
            }
        }

        var path: String {
            switch self {
            case .otp: return "/auth/v1/otp"
            case .pkceToken: return "/auth/v1/token?grant_type=pkce"
            case .refreshToken: return "/auth/v1/token?grant_type=refresh_token"
            case .logout: return "/auth/v1/logout?scope=local"
            case .memberships(let userID):
                return "/rest/v1/workspace_memberships?select=workspace_id,role,workspaces(id,name)&user_id=eq.\(userID.uuidString.lowercased())"
            case .snapshot: return "/rest/v1/rpc/mac_read_snapshot_v1"
            }
        }

        var authenticated: Bool {
            switch self {
            case .otp, .pkceToken, .refreshToken: return false
            default: return true
            }
        }
    }

    private let configuration: ExperienceReadConfiguration
    private let secureStore: ExperienceReadSecureStore
    private let transport: ExperienceReadHTTPTransport
    private let now: () -> Date
    private var session: ExperienceReadSession?
    private var workspaceID: UUID?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let sessionAccount = "supabase-session"
    private let pkceAccount = "pkce-verifier"

    init(
        configuration: ExperienceReadConfiguration,
        secureStore: ExperienceReadSecureStore? = nil,
        transport: ExperienceReadHTTPTransport = URLSessionExperienceReadTransport(),
        now: @escaping () -> Date = Date.init
    ) {
        self.configuration = configuration
        self.secureStore = secureStore ?? NamespacedExperienceReadKeychain(projectNamespace: configuration.projectNamespace)
        self.transport = transport
        self.now = now
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.fractional.date(from: value)
                ?? ISO8601DateFormatter.standard.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date")
        }
    }

    func hasStoredSession() -> Bool { (try? secureStore.read(account: sessionAccount)) != nil }

    func restoreSession() async throws -> Bool {
        guard let data = try secureStore.read(account: sessionAccount) else { return false }
        let restored: ExperienceReadSession
        do {
            restored = try decoder.decode(ExperienceReadSession.self, from: data)
            guard !restored.accessToken.isEmpty, !restored.refreshToken.isEmpty else { throw ExperienceReadError.malformedLocalSession }
        } catch {
            try secureStore.delete(account: sessionAccount)
            session = nil
            workspaceID = nil
            throw ExperienceReadError.malformedLocalSession
        }
        session = restored
        if restored.expiresAt <= now().addingTimeInterval(30) {
            session = try await refresh(restored)
        }
        return true
    }

    func requestSignIn(email: String) async throws {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.contains("@") else { throw ExperienceReadError.server("Enter a valid email address.") }
        let verifier = Self.pkceVerifier()
        try secureStore.save(Data(verifier.utf8), account: pkceAccount)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
        var request = try makeRequest(.otp, extraQuery: [URLQueryItem(name: "redirect_to", value: configuration.callbackURL.absoluteString)])
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": normalized,
            "create_user": false,
            "code_challenge": challenge,
            "code_challenge_method": "s256"
        ])
        _ = try await send(request, expected: 200..<300, authenticated: false)
    }

    func completeSignIn(callbackURL: URL) async throws {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              components.scheme == "jos",
              components.host == "auth",
              components.path == "/callback",
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.fragment == nil,
              let items = components.queryItems,
              items.count == 1,
              items[0].name == "code",
              let code = items[0].value,
              !code.isEmpty,
              code == code.trimmingCharacters(in: .whitespacesAndNewlines),
              let verifierData = try secureStore.read(account: pkceAccount),
              let verifier = String(data: verifierData, encoding: .utf8),
              !verifier.isEmpty else { throw ExperienceReadError.invalidCallback }

        var request = try makeRequest(.pkceToken)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["auth_code": code, "code_verifier": verifier])
        let data = try await send(request, expected: 200..<300, authenticated: false)
        session = try persistAuthResponse(data)
        try secureStore.delete(account: pkceAccount)
    }

    func authorizedWorkspaces() async throws -> [ReadableWorkspace] {
        let active = try await activeSession()
        let data = try await send(try makeRequest(.memberships(userID: active.userID)), expected: 200..<300, authenticated: true)
        struct Row: Decodable {
            let workspaceID: UUID
            let role: String
            let workspaces: WorkspaceRow
            enum CodingKeys: String, CodingKey { case workspaceID = "workspace_id", role, workspaces }
        }
        struct WorkspaceRow: Decodable { let id: UUID; let name: String }
        let allowedRoles = Set(["owner", "editor", "viewer"])
        return try decoder.decode([Row].self, from: data)
            .filter { allowedRoles.contains($0.role) && $0.workspaceID == $0.workspaces.id }
            .map { ReadableWorkspace(id: $0.workspaceID, name: $0.workspaces.name, role: $0.role) }
            .sorted {
                let order = $0.name.localizedCaseInsensitiveCompare($1.name)
                return order == .orderedSame ? $0.id.uuidString < $1.id.uuidString : order == .orderedAscending
            }
    }

    func bind(workspaceID: UUID) async throws {
        guard try await authorizedWorkspaces().contains(where: { $0.id == workspaceID }) else {
            throw ExperienceReadError.unauthorized("That workspace is not authorized for this account.")
        }
        self.workspaceID = workspaceID
    }

    func snapshot(windowStart: Date, windowEnd: Date) async throws -> ExperienceReadSnapshot {
        let workspaceID = try boundWorkspace()
        var request = try makeRequest(.snapshot)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "p_workspace_id": workspaceID.uuidString.lowercased(),
            "p_window_starts_at": windowStart.iso8601,
            "p_window_ends_at": windowEnd.iso8601
        ], options: [.sortedKeys])
        let data = try await send(request, expected: 200..<300, authenticated: true)
        do {
            let value = try decoder.decode(ExperienceReadSnapshot.self, from: data)
            guard value.apiVersion == "mac_read_v1",
                  value.workspaceID == workspaceID,
                  value.plannedLimit == 24,
                  value.planned.count <= value.plannedLimit else {
                throw ExperienceReadError.server("jOS returned an invalid bounded snapshot; the saved session was kept.")
            }
            return value
        } catch let error as ExperienceReadError {
            throw error
        } catch {
            throw ExperienceReadError.server("jOS returned a malformed snapshot; the saved session was kept.")
        }
    }

    func signOut() async throws {
        var remoteFailure: Error?
        if session != nil {
            do { _ = try await send(try makeRequest(.logout), expected: 200..<300, authenticated: true) }
            catch { remoteFailure = error }
        }
        session = nil
        workspaceID = nil
        try secureStore.delete(account: sessionAccount)
        try? secureStore.delete(account: pkceAccount)
        if remoteFailure != nil {
            throw ExperienceReadError.server("Signed out locally; server revocation was unavailable.")
        }
    }

    private func makeRequest(_ endpoint: Endpoint, extraQuery: [URLQueryItem] = []) throws -> URLRequest {
        guard let relative = URL(string: endpoint.path, relativeTo: configuration.supabaseURL),
              var components = URLComponents(url: relative, resolvingAgainstBaseURL: true) else {
            throw ExperienceReadError.configuration("Invalid jOS endpoint.")
        }
        if !extraQuery.isEmpty { components.queryItems = (components.queryItems ?? []) + extraQuery }
        guard let url = components.url else { throw ExperienceReadError.configuration("Invalid jOS endpoint.") }
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if endpoint.authenticated {
            guard let token = session?.accessToken else { throw ExperienceReadError.unauthorized("Sign in to jOS.") }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send(_ request: URLRequest, expected: Range<Int>, authenticated: Bool) async throws -> Data {
        let (data, response) = try await transport.data(for: request)
        guard expected.contains(response.statusCode) else {
            let payload = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let message = payload["message"] as? String ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
            if authenticated && response.statusCode == 401 {
                try? secureStore.delete(account: sessionAccount)
                session = nil
                workspaceID = nil
                throw ExperienceReadError.unauthorized("The jOS session is no longer valid. Sign in again.")
            }
            if response.statusCode == 401 || response.statusCode == 403 {
                throw ExperienceReadError.unauthorized(message)
            }
            throw ExperienceReadError.server("jOS is temporarily unavailable (\(response.statusCode)); the saved session was kept.")
        }
        return data
    }

    private func activeSession() async throws -> ExperienceReadSession {
        guard var active = session else { throw ExperienceReadError.unauthorized("Sign in to jOS.") }
        if active.expiresAt <= now().addingTimeInterval(30) {
            active = try await refresh(active)
            session = active
        }
        return active
    }

    private func refresh(_ current: ExperienceReadSession) async throws -> ExperienceReadSession {
        var request = try makeRequest(.refreshToken)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": current.refreshToken])
        let (data, response) = try await transport.data(for: request)
        if response.statusCode == 400 || response.statusCode == 401 {
            try secureStore.delete(account: sessionAccount)
            session = nil
            workspaceID = nil
            throw ExperienceReadError.unauthorized("The jOS session expired. Sign in again.")
        }
        guard (200..<300).contains(response.statusCode) else {
            throw ExperienceReadError.server("Session refresh is temporarily unavailable; the saved session was kept.")
        }
        do { return try persistAuthResponse(data) }
        catch {
            throw ExperienceReadError.server("Session refresh returned an invalid response; the saved session was kept.")
        }
    }

    private func persistAuthResponse(_ data: Data) throws -> ExperienceReadSession {
        struct Response: Decodable {
            let accessToken: String
            let refreshToken: String
            let expiresIn: Double
            let user: User
            struct User: Decodable { let id: UUID }
            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
                case expiresIn = "expires_in"
                case user
            }
        }
        let response = try decoder.decode(Response.self, from: data)
        guard !response.accessToken.isEmpty, !response.refreshToken.isEmpty, response.expiresIn > 0 else {
            throw ExperienceReadError.server("jOS returned invalid session material.")
        }
        let value = ExperienceReadSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: now().addingTimeInterval(response.expiresIn),
            userID: response.user.id
        )
        try secureStore.save(try encoder.encode(value), account: sessionAccount)
        return value
    }

    private func boundWorkspace() throws -> UUID {
        guard session != nil else { throw ExperienceReadError.unauthorized("Sign in to jOS.") }
        guard let workspaceID else { throw ExperienceReadError.unauthorized("Choose an authorized jOS workspace.") }
        return workspaceID
    }

    private static func pkceVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "") + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        return Data(bytes).base64URLEncodedString()
    }
}

final class InMemoryExperienceReader: ExperienceReading {
    var hasSession = false
    var workspaces: [ReadableWorkspace] = []
    var activeWorkspaceID: UUID?
    var value: ExperienceReadSnapshot?
    var nextError: ExperienceReadError?
    var workspaceError: ExperienceReadError?
    private(set) var snapshotCalls = 0

    func hasStoredSession() -> Bool { hasSession }
    func restoreSession() async throws -> Bool { hasSession }
    func requestSignIn(email: String) async throws {}
    func completeSignIn(callbackURL: URL) async throws { hasSession = true }
    func authorizedWorkspaces() async throws -> [ReadableWorkspace] {
        if let workspaceError { throw workspaceError }
        return workspaces
    }
    func bind(workspaceID: UUID) async throws { activeWorkspaceID = workspaceID }
    func snapshot(windowStart: Date, windowEnd: Date) async throws -> ExperienceReadSnapshot {
        snapshotCalls += 1
        if let nextError { self.nextError = nil; throw nextError }
        guard let value else { throw ExperienceReadError.server("No in-memory snapshot.") }
        return value
    }
    func signOut() async throws { hasSession = false; activeWorkspaceID = nil }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension ISO8601DateFormatter {
    static let standard: ISO8601DateFormatter = { ISO8601DateFormatter() }()
    static let fractional: ISO8601DateFormatter = {
        let value = ISO8601DateFormatter()
        value.formatOptions.insert(.withFractionalSeconds)
        return value
    }()
}

private extension Date {
    var iso8601: String { ISO8601DateFormatter.fractional.string(from: self) }
}
