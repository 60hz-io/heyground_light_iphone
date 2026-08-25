import SwiftUI
import WidgetKit

/// 오늘 보기(잠금화면에서 오른쪽 스와이프)와 홈 화면에 올리는 위젯.
///
/// 잠금화면 **위젯**(accessory 계열)은 vibrant 렌더링이라 QR 이 반투명 단색으로 뭉개져 스캔이
/// 안 된다. 반면 오늘 보기는 홈 화면과 같은 system 계열이라 **풀컬러**로 그려진다.
/// 그래서 잠금화면에서 스캔 가능한 QR 을 보여주려면 이쪽이어야 한다.
///
/// 다만 WidgetKit 갱신 예산(하루 40~70회, 실질 15~60분)이 QR 수명(9분 30초)보다 길어
/// **자동 갱신만으로는 만료된 QR 이 뜨는 시간이 길다.** 그래서 위젯 전체를 갱신 버튼으로 만든다.
struct TodayQRWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "io.60hz.heygroundqr.today", provider: QRTimelineProvider()) { entry in
            TodayQRView(entry: entry)
                .containerBackground(.white, for: .widget)
        }
        .configurationDisplayName("출입 QR")
        .description("헤이그라운드 출입 QR을 표시합니다. 탭하면 새 QR을 받아옵니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct QREntry: TimelineEntry {
    let date: Date
    let status: QRStatus
    let imageData: Data?
    let expiresAt: Date?
}

struct QRTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> QREntry {
        QREntry(date: Date(), status: .empty, imageData: nil, expiresAt: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (QREntry) -> Void) {
        let state = QRRepository.currentState()
        completion(
            QREntry(
                date: Date(),
                status: state.status,
                imageData: QRRepository.cachedImageData(),
                expiresAt: state.expiresAt
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QREntry>) -> Void) {
        Task {
            let state = await QRRepository.ensureFresh()
            let entry = QREntry(
                date: Date(),
                status: state.status,
                imageData: QRRepository.cachedImageData(),
                expiresAt: state.expiresAt
            )
            // 만료 직전에 다시 불러달라고 요청한다. 예산 때문에 그대로 지켜지진 않지만
            // 시스템이 가능한 범위에서 최대한 붙여준다.
            let next = state.expiresAt?.addingTimeInterval(-QRRepository.refreshLeadSec)
                ?? Date().addingTimeInterval(5 * 60)
            let reloadAt = max(next, Date().addingTimeInterval(60))
            completion(Timeline(entries: [entry], policy: .after(reloadAt)))
        }
    }
}

struct TodayQRView: View {
    let entry: QREntry

    private var isExpired: Bool {
        guard let expiresAt = entry.expiresAt else { return true }
        return expiresAt <= Date()
    }

    var body: some View {
        switch entry.status {
        case .needLogin:
            // 로그인 전에는 갱신할 수단이 없으니 기본 동작(탭하면 앱 열기)에 맡긴다.
            message("로그인 필요")
        case .ready, .stale, .empty:
            // 위젯 전체가 갱신 버튼이다. 앱을 열지 않고 그 자리에서 새 QR 을 받아온다.
            Button(intent: RefreshQRIntent()) {
                content
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let data = entry.imageData, let image = UIImage(data: data) {
            VStack(spacing: 4) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // 만료된 QR 은 흐리게 그려 "이건 못 쓴다"를 눈으로 알린다.
                    .opacity(isExpired ? 0.3 : 1)

                if isExpired {
                    Text("만료됨 · 탭하여 갱신")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.expired)
                } else if let expiresAt = entry.expiresAt {
                    Text(expiresAt, style: .timer)
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.navy.opacity(0.6))
                }
            }
        } else {
            message("탭하여 갱신")
        }
    }

    private func message(_ text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "qrcode")
                .font(.system(size: 40))
                .foregroundStyle(Theme.navy.opacity(0.3))
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.navy)
        }
    }
}
