import Foundation

/// 토큰 저장소. 비밀번호는 저장하지 않고 refresh_token 만 남긴다(안드로이드 버전과 동일 정책).
///
/// 위젯 확장에서도 갱신을 돌려야 해서 keychain-access-groups 로 앱과 공유한다.
/// 접근성은 `AfterFirstUnlock` — 잠금화면 위젯이 잠긴 상태에서 토큰을 읽어야 하기 때문이다.
enum KeychainStore {

    private static let service = "io.60hz.heygroundqr"

    static var refreshToken: String? {
        get { read(key: "refresh_token") }
        set { write(key: "refresh_token", value: newValue) }
    }

    static var accessToken: String? {
        get { read(key: "access_token") }
        set { write(key: "access_token", value: newValue) }
    }

    /// access_token 만료 시각(epoch 초). 토큰 자체가 아니라 메타데이터라 App Group 에 둔다.
    static var accessTokenExpiresAt: Double {
        get { AppGroup.defaults?.double(forKey: "access_expires_at") ?? 0 }
        set { AppGroup.defaults?.set(newValue, forKey: "access_expires_at") }
    }

    static var isLoggedIn: Bool { !(refreshToken ?? "").isEmpty }

    static func clearAll() {
        refreshToken = nil
        accessToken = nil
        accessTokenExpiresAt = 0
    }

    // MARK: - Keychain

    private static func baseQuery(key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }

    private static func read(key: String) -> String? {
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(key: String, value: String?) {
        let query = baseQuery(key: key)
        SecItemDelete(query as CFDictionary)

        guard let value, let data = value.data(using: .utf8) else { return }
        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(insert as CFDictionary, nil)
    }
}
