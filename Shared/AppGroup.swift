import Foundation

/// 앱과 위젯 확장이 QR 캐시를 함께 보는 지점.
///
/// 위젯은 별도 프로세스라 앱의 샌드박스를 못 읽는다. App Group 컨테이너에 두어야
/// "앱이 받아온 QR 을 위젯이 그리는" 구조가 성립한다.
enum AppGroup {

    static let identifier = "group.io.60hz.heygroundqr"

    /// 잠금 상태에서도 읽어야 하므로 파일 보호 수준을 첫 잠금해제 이후로 낮춘다.
    /// (기본값 `.complete` 이면 잠긴 화면에서 위젯이 캐시를 못 열어 빈 위젯이 된다.)
    static let fileProtection: FileProtectionType = .completeUntilFirstUserAuthentication

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }
}
