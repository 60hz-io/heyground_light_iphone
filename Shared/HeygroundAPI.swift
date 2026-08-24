import Foundation

/// heyground.com OAuth + QR 조회. 안드로이드 `Api.kt` 와 같은 계약을 그대로 옮긴 것이다.
///
/// Basic 자격증명은 member.heyground.com 공개 SPA 에 하드코딩되어 있는 값이다(비밀이 아니다).
enum HeygroundAPI {

    private static let base = "https://api.heyground.com"
    private static let basicAuth = "Basic aGV5Z3JvdW5kLXdlYjpmb28="

    /// 자격증명/refresh_token 이 거부된 경우. 재시도해도 소용없고 재로그인이 필요하다.
    struct AuthError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    struct Token {
        let access: String
        let refresh: String?
        let expiresInSec: Int
    }

    struct QrInfo {
        let imageURL: String
        /// "yyyy-MM-dd HH:mm" (기기 로컬시간, 초 없음)
        let expiryText: String
    }

    static func login(email: String, password: String) async throws -> Token {
        try await requestToken(
            form: "grant_type=password&username=\(enc(email))&password=\(enc(password))"
        )
    }

    static func refresh(refreshToken: String) async throws -> Token {
        try await requestToken(
            form: "grant_type=refresh_token&refresh_token=\(enc(refreshToken))"
        )
    }

    /// GET /api/members/me/qrcode — 이미지 URL 과 만료시각 문자열을 준다.
    static func fetchQrInfo(accessToken: String) async throws -> QrInfo {
        var request = URLRequest(url: URL(string: "\(base)/api/members/me/qrcode")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 400 || code == 401 {
            throw AuthError(message: "QR 조회 인증 실패 (HTTP \(code))")
        }
        guard (200..<300).contains(code) else {
            throw APIError(message: "QR 조회 실패 (HTTP \(code))")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let url = json?["qrcode"] as? String, !url.isEmpty,
              let expiry = json?["expiryDate"] as? String, !expiry.isEmpty
        else {
            throw APIError(message: "QR 응답에 qrcode/expiryDate 가 없습니다")
        }
        return QrInfo(imageURL: url, expiryText: expiry)
    }

    /// QR 이미지(400x400 JPEG). 인증 헤더가 필요 없는 공개 URL 이다.
    static func downloadImage(_ imageURL: String) async throws -> Data {
        guard let url = URL(string: imageURL) else {
            throw APIError(message: "QR 이미지 URL 이 올바르지 않습니다")
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw APIError(message: "QR 이미지 다운로드 실패 (HTTP \(code))")
        }
        guard !data.isEmpty else {
            throw APIError(message: "QR 이미지가 비어 있습니다")
        }
        return data
    }

    // MARK: -

    private static func requestToken(form: String) async throws -> Token {
        var request = URLRequest(url: URL(string: "\(base)/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue(basicAuth, forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = form.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 400 || code == 401 {
            throw AuthError(message: "이메일 또는 비밀번호가 올바르지 않습니다")
        }
        guard (200..<300).contains(code) else {
            throw APIError(message: "토큰 발급 실패 (HTTP \(code))")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let access = json?["access_token"] as? String, !access.isEmpty else {
            throw APIError(message: "access_token 이 없습니다")
        }
        let refresh = (json?["refresh_token"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let expiresIn = json?["expires_in"] as? Int ?? 1800
        return Token(access: access, refresh: refresh, expiresInSec: expiresIn)
    }

    private static func enc(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
