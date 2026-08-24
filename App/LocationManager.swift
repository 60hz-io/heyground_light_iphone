import CoreLocation
import WidgetKit

/// 회사 반경 지오펜스. 역할은 "QR 게이팅"이 아니라 **준비 트리거**다.
///
/// 회사 300m 안에 들어오면 iOS 가 앱을 백그라운드로 깨워주는데(앱이 종료돼 있어도),
/// 그 짧은 순간에 토큰을 갱신하고 QR 을 미리 받아둔다. 문 앞에서 앱을 열면
/// 캐시가 살아 있어 바로 뜨고, 만료됐더라도 토큰이 유효해 호출 한 번으로 끝난다.
///
/// 깨어난 뒤 주어지는 시간이 10초 남짓이라 여기서 재시도까지 욕심내지 않는다.
final class LocationManager: NSObject, CLLocationManagerDelegate {

    static let shared = LocationManager()

    /// 회사: 서울 성동구 왕십리로 115 (헤이그라운드 서울숲점)
    private static let company = CLLocationCoordinate2D(latitude: 37.54792, longitude: 127.04420)
    private static let radius: CLLocationDistance = 300
    private static let regionID = "company"

    private let manager = CLLocationManager()

    override private init() {
        super.init()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = false
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    /// 위젯은 앱이 닫힌 상태에서도 갱신돼야 하므로 '항상 허용'까지 필요하다.
    /// iOS 는 '사용 중 허용'을 먼저 받아야 '항상 허용'을 물어볼 수 있어 두 단계로 요청한다.
    func requestAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func start() {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        guard manager.authorizationStatus == .authorizedAlways else { return }

        let region = CLCircularRegion(
            center: Self.company, radius: Self.radius, identifier: Self.regionID
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false
        manager.startMonitoring(for: region)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        start()
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == Self.regionID else { return }
        Task {
            await QRRepository.ensureFresh(force: true)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
