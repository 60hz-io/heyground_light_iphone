import AppIntents
import SwiftUI
import WidgetKit

/// 잠금화면 하단의 '출입' 버튼 (iOS 18+).
///
/// 손전등/카메라 자리에 배치하거나 제어센터·액션 버튼에 넣을 수 있다.
/// 탭 → Face ID → QR 화면이 바로 뜨므로, 지금의 "잠금해제 → 앱 찾기 → 실행 → 출입증" 과정을
/// 두 동작으로 줄인다.
@available(iOS 18.0, *)
struct HeygroundControl: ControlWidget {

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "io.60hz.heygroundqr.control") {
            ControlWidgetButton(action: OpenQRIntent()) {
                Label("출입", systemImage: "qrcode")
            }
        }
        .displayName("출입 QR")
        .description("잠금화면에서 바로 출입 QR을 엽니다.")
    }
}
