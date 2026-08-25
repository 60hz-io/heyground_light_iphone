import AppIntents
import WidgetKit

/// 위젯 안의 갱신 버튼(iOS 17+).
///
/// 앱을 열지 않고 백그라운드에서 실행되므로 **잠금 해제 없이** QR 을 새로 받아올 수 있다.
/// 이게 동작해야 "오늘 보기 → 탭 → 새 QR" 흐름이 성립한다.
/// (토큰은 Keychain 접근성 AfterFirstUnlock, 캐시는 파일 보호 완화로 잠금 중에도 읽힌다.)
struct RefreshQRIntent: AppIntent {
    static var title: LocalizedStringResource = "QR 갱신"
    static var description = IntentDescription("출입 QR을 새로 받아옵니다.")
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        // 연타로 서버를 두드리지 않도록 쿨다운을 둔다.
        guard QRThrottle.canRefresh() else { return .result() }
        await QRRepository.ensureFresh(force: true)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// 잠금화면 Control 이 누르는 인텐트. 앱을 열어 QR 화면을 띄운다(Face ID 를 거친다).
///
/// 이 타입은 앱 타깃에도 컴파일되어야 한다. 위젯 확장에만 있으면 시스템이 앱을 띄우면서
/// 인텐트를 이어받지 못해 버튼을 눌러도 아무 일도 일어나지 않는다.
struct OpenQRIntent: AppIntent {
    static var title: LocalizedStringResource = "출입 QR 열기"
    static var description = IntentDescription("출입 QR 화면을 바로 엽니다.")
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}
