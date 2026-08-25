# 헤이그라운드 QR (iOS)

안드로이드 버전([heyground_light](https://github.com/60hz-io/heyground_light))의 iOS 버전

---

## What

1. **잠금화면 '출입' 버튼** (iOS 18+) — 손전등/카메라 자리에 배치하거나 제어센터·액션 버튼에 넣습니다. 탭 → Face ID → QR 화면을 띄울 수 있습니다.
2. **오늘 보기 위젯** — 오늘 보기 화면에서 QR위젯을 띄울 수 있고, 터치해 갱신할 수 있습니다.

## 빌드

프로젝트 파일 생성 도구를 설치합니다.

```
brew install xcodegen
```

`project.yml`에서 Xcode 프로젝트를 생성합니다.

```
xcodegen generate
```

Xcode로 엽니다. 두 타깃(HeygroundQR, HeygroundQRWidget) 모두 서명 팀을 지정해야 합니다.

```
open HeygroundQR.xcodeproj
```

`xcodebuild`를 쓰려면 Xcode를 활성 개발자 디렉토리로 지정합니다. (한 번만 하면 됩니다)

```
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

시뮬레이터용으로 빌드합니다.

```
xcodebuild -scheme HeygroundQR -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- build
```

실행 중인 시뮬레이터에 설치합니다.

```
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/HeygroundQR.app
```

앱을 실행합니다.

```
xcrun simctl launch booted io.60hz.heygroundqr
```
