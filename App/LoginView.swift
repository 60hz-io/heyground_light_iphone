import SwiftUI
import WidgetKit

struct LoginView: View {
    let onLoggedIn: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isBusy = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 6) {
                Text("HEYGROUND")
                    .font(.system(size: 34, weight: .heavy))
                    .kerning(2)
                Text("×")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
                Text("60Hertz")
                    .font(.system(size: 22, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.bottom, 48)

            TextField("", text: $email, prompt: placeholder("이메일"))
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .underlined()

            SecureField("", text: $password, prompt: placeholder("비밀번호"))
                .textContentType(.password)
                .underlined()
                .padding(.top, 14)

            Button(action: submit) {
                Text(isBusy ? "로그인 중…" : "로그인")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white, in: Capsule())
                    .foregroundStyle(Theme.navy)
            }
            .disabled(isBusy || email.isEmpty || password.isEmpty)
            .opacity(isBusy || email.isEmpty || password.isEmpty ? 0.5 : 1)
            .padding(.top, 28)

            if let error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.expired)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private func placeholder(_ text: String) -> Text {
        Text(text).foregroundStyle(.white.opacity(0.55))
    }

    private func submit() {
        isBusy = true
        error = nil
        Task {
            do {
                try await QRRepository.login(
                    email: email.trimmingCharacters(in: .whitespaces), password: password
                )
                password = ""
                WidgetCenter.shared.reloadAllTimelines()
                TokenSync.shared.pushToken(KeychainStore.refreshToken)
                LocationManager.shared.requestAuthorization()
                onLoggedIn()
            } catch {
                self.error = error.localizedDescription
            }
            isBusy = false
        }
    }
}

private extension View {
    /// 안드로이드 버전과 같은 흰 언더라인 입력 필드.
    func underlined() -> some View {
        self
            .foregroundStyle(.white)
            .font(.system(size: 16))
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.white.opacity(0.42))
                    .frame(height: 1.5)
            }
    }
}
