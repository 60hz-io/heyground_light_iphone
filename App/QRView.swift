import SwiftUI
import WidgetKit

/// 앱의 첫 화면이자 사실상 유일한 화면. 잠금화면 Control 로 진입하면 바로 여기가 뜬다.
///
/// 캐시가 유효하면 즉시 그리고, 뒤에서 신선도를 확인한다(만료면 새로 받는다).
struct QRView: View {
    let onLogout: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var state = QRRepository.currentState()
    @State private var imageData = QRRepository.cachedImageData()
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: logout) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Theme.logout)
                        .padding(10)
                }
                .accessibilityLabel("로그아웃")
            }

            Spacer()

            qrCard
                .onTapGesture { refresh(force: true) }

            statusText
                .padding(.top, 14)

            Spacer()
        }
        .padding(.horizontal, 24)
        .task { refresh(force: false) }
        .onChange(of: scenePhase) { _, phase in
            // 잠금화면 Control → Face ID → 앱 복귀 시점에도 최신 QR 을 확인한다.
            if phase == .active { refresh(force: false) }
        }
    }

    private var qrCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)

            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(14)
                    // 만료된 QR 은 흐리게 그려 "이건 못 쓴다"를 눈으로 알린다.
                    .opacity(state.status == .stale ? 0.35 : 1)
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 90))
                    .foregroundStyle(Theme.navy.opacity(0.25))
            }
        }
        .frame(width: 280, height: 280)
    }

    @ViewBuilder
    private var statusText: some View {
        if isRefreshing {
            Text("갱신 중…").foregroundStyle(.white.opacity(0.75))
        } else {
            switch state.status {
            case .ready:
                Text(" ").foregroundStyle(.clear)
            case .stale:
                Text("만료됨 · 탭하여 갱신").foregroundStyle(Theme.expired)
            case .empty:
                Text(state.message ?? "탭하여 갱신").foregroundStyle(Theme.expired)
            case .needLogin:
                Text("로그인이 필요합니다.").foregroundStyle(Theme.expired)
            }
        }
    }

    private func refresh(force: Bool) {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            let next = await QRRepository.ensureFresh(force: force)
            state = next
            imageData = QRRepository.cachedImageData()
            isRefreshing = false
            WidgetCenter.shared.reloadAllTimelines()
            if next.status == .needLogin { onLogout() }
        }
    }

    private func logout() {
        QRRepository.logout()
        WidgetCenter.shared.reloadAllTimelines()
        onLogout()
    }
}
