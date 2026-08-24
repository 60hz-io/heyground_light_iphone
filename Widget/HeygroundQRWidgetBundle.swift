import SwiftUI
import WidgetKit

@main
struct HeygroundQRWidgetBundle: WidgetBundle {

    var body: some Widget {
        TodayQRWidget()
        if #available(iOS 18.0, *) {
            HeygroundControl()
        }
    }
}
