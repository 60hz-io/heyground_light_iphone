import SwiftUI

@main
struct HeygroundQRWatchApp: App {

    init() {
        // 아이폰이 보낸 토큰을 받으려면 앱이 뜨자마자 세션을 열어둬야 한다.
        TokenSync.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchQRView()
        }
    }
}
