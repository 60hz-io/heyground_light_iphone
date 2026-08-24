import SwiftUI

struct RootView: View {
    @State private var isLoggedIn = KeychainStore.isLoggedIn

    var body: some View {
        ZStack {
            Theme.navy.ignoresSafeArea()
            if isLoggedIn {
                QRView(onLogout: { isLoggedIn = false })
            } else {
                LoginView(onLoggedIn: { isLoggedIn = true })
            }
        }
        .preferredColorScheme(.dark)
    }
}
