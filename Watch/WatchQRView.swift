import SwiftUI

/// 워치 앱의 유일한 화면. 실행하면 바로 QR 이 뜨는 것이 목적이라 다른 UI 를 두지 않는다.
///
/// 캐시가 유효하면 즉시 그리고, 만료됐을 때만 새로 받는다.
struct WatchQRView: View {

    @State private var state = QRRepository.currentState()
    @State private var imageData = QRRepository.cachedImageData()
    @State private var isRefreshing = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(4)
                    .opacity(state.status == .stale ? 0.3 : 1)
                    .overlay {
                        if state.status == .stale && !isRefreshing {
                            Text("탭하여 갱신")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.navy)
                        }
                    }
            } else {
                message
            }
        }
        .onTapGesture { refresh(force: true) }
        .task { refresh(force: false) }
    }

    @ViewBuilder
    private var message: some View {
        VStack(spacing: 6) {
            Image(systemName: "qrcode")
                .font(.system(size: 28))
                .foregroundStyle(Theme.navy.opacity(0.3))
            Text(label)
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.navy)
        }
        .padding(8)
    }

    private var label: String {
        if isRefreshing { return "갱신 중…" }
        switch state.status {
        case .needLogin: return "아이폰 앱에서\n먼저 로그인하세요"
        default: return state.message ?? "탭하여 갱신"
        }
    }

    private func refresh(force: Bool) {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            state = await QRRepository.ensureFresh(force: force)
            imageData = QRRepository.cachedImageData()
            isRefreshing = false
        }
    }
}
