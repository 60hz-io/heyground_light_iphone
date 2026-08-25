import Foundation

/// 위젯 갱신 버튼 연타 방지.
///
/// 위젯 확장은 탭마다 새 프로세스로 뜰 수 있어 정적 변수로는 상태가 남지 않는다.
/// App Group 에 마지막 갱신 시각을 적어 프로세스가 바뀌어도 쿨다운이 유지되게 한다.
enum QRThrottle {

    private static let key = "last_manual_refresh_at"
    private static let cooldown: TimeInterval = 5

    static func canRefresh() -> Bool {
        let now = Date().timeIntervalSince1970
        let last = AppGroup.defaults?.double(forKey: key) ?? 0
        guard now - last >= cooldown else { return false }
        AppGroup.defaults?.set(now, forKey: key)
        return true
    }
}
