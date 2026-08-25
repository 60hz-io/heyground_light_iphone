import Foundation
import WatchConnectivity

/// 아이폰 ↔ 워치 토큰 동기화.
///
/// 워치에서 이메일·비밀번호를 입력시키지 않으려면 아이폰이 로그인하고 refresh 토큰만 넘겨야 한다.
/// `updateApplicationContext` 는 최신 값 하나만 유지하며, 상대 앱이 꺼져 있어도 시스템이 전달한다.
///
/// 워치는 토큰을 받은 뒤 **자기 네트워크로 직접 QR 을 받아온다.** 게이트 앞에서 폰이 깨어 있을
/// 필요가 없어야 하므로, 폰에 QR 을 물어보는 구조로 만들지 않는다.
final class TokenSync: NSObject, WCSessionDelegate {

    static let shared = TokenSync()

    private static let tokenKey = "refresh_token"
    private static let loggedOutKey = "logged_out"

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// 아이폰에서 호출: 로그인 직후 토큰을 워치로 밀어준다.
    func pushToken(_ token: String?) {
        guard let session, session.activationState == .activated else { return }
        let context: [String: Any] = token.map { [Self.tokenKey: $0] } ?? [Self.loggedOutKey: true]
        try? session.updateApplicationContext(context)
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        apply(context)
    }

    /// 받는 쪽(워치)에서 호출: 토큰을 자기 Keychain 에 저장하거나, 로그아웃이면 지운다.
    private func apply(_ context: [String: Any]) {
        if context[Self.loggedOutKey] as? Bool == true {
            QRRepository.logout()
            return
        }
        guard let token = context[Self.tokenKey] as? String, !token.isEmpty else { return }
        guard token != KeychainStore.refreshToken else { return }
        KeychainStore.refreshToken = token
        // 새 계정으로 바뀐 것일 수 있으니 이전 access 토큰은 버린다.
        KeychainStore.accessToken = nil
        KeychainStore.accessTokenExpiresAt = 0
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
