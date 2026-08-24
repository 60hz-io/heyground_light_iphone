import UIKit

/// 지오펜스 이벤트로 앱이 백그라운드에서 되살아날 때를 받는다.
///
/// SwiftUI 의 `App` 만으로는 이 시점에 진입할 훅이 없다. 위치 이벤트로 실행되면
/// 여기서 LocationManager 를 다시 세워야 `didEnterRegion` 콜백이 온다.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        LocationManager.shared.start()
        return true
    }
}
