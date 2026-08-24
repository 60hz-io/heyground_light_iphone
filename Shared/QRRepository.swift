import Foundation

enum QRStatus {
    /// refresh_token 이 없거나 거부됨 → 재로그인 필요
    case needLogin
    /// 유효한 QR 캐시 있음
    case ready
    /// 만료됐는데 갱신 실패 → 마지막 QR 을 흐리게 보여준다
    case stale
    /// 그릴 이미지가 아예 없음
    case empty
}

struct QRState {
    let status: QRStatus
    var expiresAt: Date?
    var message: String?
}

/// "필요하면 갱신, 아니면 캐시" 단일 진입점. 앱·위젯·인텐트가 모두 이 경로를 탄다.
enum QRRepository {

    /// 만료 몇 초 전부터 새로 받을지. 안드로이드 버전과 동일하게 30초.
    static let refreshLeadSec: TimeInterval = 30

    private static var qrFileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent("qr.png")
    }

    private static var qrExpiresAt: Date? {
        get {
            let ts = AppGroup.defaults?.double(forKey: "qr_expires_at") ?? 0
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }
        set {
            AppGroup.defaults?.set(newValue?.timeIntervalSince1970 ?? 0, forKey: "qr_expires_at")
        }
    }

    static var lastError: String? {
        get { AppGroup.defaults?.string(forKey: "last_error") }
        set { AppGroup.defaults?.set(newValue, forKey: "last_error") }
    }

    /// 네트워크 없이 지금 그려야 할 상태만 판정한다(위젯 렌더 경로).
    static func currentState() -> QRState {
        guard KeychainStore.isLoggedIn else { return QRState(status: .needLogin) }
        guard let url = qrFileURL, FileManager.default.fileExists(atPath: url.path) else {
            return QRState(status: .empty, message: lastError)
        }
        if let expiresAt = qrExpiresAt, expiresAt > Date() {
            return QRState(status: .ready, expiresAt: expiresAt)
        }
        return QRState(status: .stale, expiresAt: qrExpiresAt, message: lastError)
    }

    static func cachedImageData() -> Data? {
        guard let url = qrFileURL else { return nil }
        return try? Data(contentsOf: url)
    }

    /// 최초 로그인. 성공하면 refresh_token 을 저장하고 QR 을 즉시 한 번 받아온다.
    @discardableResult
    static func login(email: String, password: String) async throws -> QRState {
        let token = try await HeygroundAPI.login(email: email, password: password)
        guard let refresh = token.refresh else {
            throw HeygroundAPI.APIError(message: "서버가 refresh_token 을 주지 않았습니다")
        }
        KeychainStore.refreshToken = refresh
        save(accessToken: token)
        return await ensureFresh(force: true)
    }

    static func logout() {
        KeychainStore.clearAll()
        clearCachedImage()
        lastError = nil
    }

    /// 캐시를 보고 필요할 때만 네트워크를 탄다.
    /// - Parameter force: 만료 전이라도 무조건 새로 받는다(수동 갱신).
    @discardableResult
    static func ensureFresh(force: Bool = false) async -> QRState {
        guard KeychainStore.isLoggedIn else { return QRState(status: .needLogin) }

        if !force,
           let expiresAt = qrExpiresAt,
           let url = qrFileURL,
           FileManager.default.fileExists(atPath: url.path),
           expiresAt.timeIntervalSinceNow > refreshLeadSec {
            return QRState(status: .ready, expiresAt: expiresAt)
        }

        do {
            let expiresAt = try await fetchAndStore()
            lastError = nil
            return QRState(status: .ready, expiresAt: expiresAt)
        } catch is HeygroundAPI.AuthError {
            // 세션이 끊긴 경우 자격증명과 캐시를 함께 지운다(잠금화면에 남기지 않는다).
            KeychainStore.clearAll()
            clearCachedImage()
            let message = "세션이 만료되었습니다. 다시 로그인하세요."
            lastError = message
            return QRState(status: .needLogin, message: message)
        } catch {
            KeychainStore.accessToken = nil
            lastError = error.localizedDescription
            var state = currentState()
            state.message = error.localizedDescription
            return state
        }
    }

    // MARK: -

    /// - Returns: 새 QR 의 만료 시각
    private static func fetchAndStore() async throws -> Date {
        var access = try await validAccessToken()
        let info: HeygroundAPI.QrInfo
        do {
            info = try await HeygroundAPI.fetchQrInfo(accessToken: access)
        } catch is HeygroundAPI.AuthError {
            // access_token 이 서버에서 먼저 만료된 경우 → 한 번만 강제 갱신 후 재시도
            access = try await renewAccessToken()
            info = try await HeygroundAPI.fetchQrInfo(accessToken: access)
        }

        let data = try await HeygroundAPI.downloadImage(info.imageURL)
        try writeAtomically(data)

        let expiresAt = parseExpiry(info.expiryText)
        qrExpiresAt = expiresAt
        return expiresAt
    }

    private static func validAccessToken() async throws -> String {
        if let token = KeychainStore.accessToken,
           KeychainStore.accessTokenExpiresAt - Date().timeIntervalSince1970 > 30 {
            return token
        }
        return try await renewAccessToken()
    }

    private static func renewAccessToken() async throws -> String {
        guard let refresh = KeychainStore.refreshToken else {
            throw HeygroundAPI.AuthError(message: "로그인이 필요합니다")
        }
        let token = try await HeygroundAPI.refresh(refreshToken: refresh)
        save(accessToken: token)
        return token.access
    }

    private static func save(accessToken token: HeygroundAPI.Token) {
        KeychainStore.accessToken = token.access
        KeychainStore.accessTokenExpiresAt =
            Date().timeIntervalSince1970 + Double(token.expiresInSec)
        // refresh 그랜트가 새 refresh_token 을 주지 않는 경우가 있으니 기존 값을 지우지 않는다.
        if let refresh = token.refresh { KeychainStore.refreshToken = refresh }
    }

    private static func writeAtomically(_ data: Data) throws {
        guard let url = qrFileURL else {
            throw HeygroundAPI.APIError(message: "App Group 컨테이너를 찾지 못했습니다")
        }
        try data.write(to: url, options: [.atomic])
        try? FileManager.default.setAttributes(
            [.protectionKey: AppGroup.fileProtection], ofItemAtPath: url.path
        )
    }

    private static func clearCachedImage() {
        if let url = qrFileURL { try? FileManager.default.removeItem(at: url) }
        qrExpiresAt = nil
    }

    /// "yyyy-MM-dd HH:mm" (기기 로컬시간) → Date. 파싱 실패 시 보수적으로 9분.
    private static func parseExpiry(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = .current
        return formatter.date(from: text.trimmingCharacters(in: .whitespaces))
            ?? Date().addingTimeInterval(9 * 60)
    }
}
