# 헤이그라운드 QR (iOS)

헤이그라운드 출입 QR을 잠금화면에서 가장 빠르게 꺼내는 iOS 앱입니다.
안드로이드 버전([heyground_light](https://github.com/60hz-io/heyground_light))의 iOS 대응판입니다.

---

## What

두 가지 경로로 출입 QR에 접근합니다.

1. **잠금화면 '출입' 버튼** (iOS 18+) — 손전등/카메라 자리에 배치하거나 제어센터·액션 버튼에 넣습니다.
   탭 → Face ID → QR 화면이 바로 뜹니다.
2. **오늘 보기 위젯** — 잠금화면에서 오른쪽으로 스와이프하면 나오는 위젯 화면입니다.
   잠금 해제 없이 QR을 보고, 만료됐으면 위젯의 갱신 버튼을 눌러 그 자리에서 새로 받습니다.

회사(왕십리로 115) 반경 300m에 들어오면 iOS가 앱을 백그라운드로 깨워 토큰과 QR을 미리 받아둡니다.
문 앞에서 꺼낼 때 이미 준비돼 있게 하려는 용도이고, 위치로 QR을 가리지는 않습니다.

## Why

안드로이드는 잠금화면 위젯에 QR을 상시 띄울 수 있지만 iOS는 불가능합니다.
잠금화면 위젯(accessory 계열)은 반투명 단색(vibrant)으로만 렌더링돼 QR이 스캔되지 않고,
WidgetKit 갱신 예산(하루 40~70회, 실질 15~60분)이 QR 수명(9분 30초)을 따라가지 못합니다.

그래서 iOS에서는 **"항상 떠 있는 QR"이 아니라 "가장 빠르게 꺼내는 QR"** 로 목표를 바꿨습니다.
오늘 보기는 홈 화면과 같은 system 계열이라 풀컬러로 그려지므로, 잠금화면에서 스캔 가능한 QR을
보여줄 수 있는 유일한 경로입니다.

## 구조

```
Shared/          앱과 위젯이 함께 쓰는 코드
  HeygroundAPI     OAuth + QR 조회 (안드로이드 Api.kt 와 동일 계약)
  QRRepository     캐시 유효하면 그대로, 만료면 재수신 (단일 진입점)
  KeychainStore    refresh_token 보관 (AfterFirstUnlock, 위젯과 공유)
  AppGroup         QR 이미지 캐시를 앱↔위젯이 공유하는 지점

App/
  QRView           앱의 첫 화면이자 사실상 유일한 화면
  LocationManager  회사 300m 지오펜스 → 백그라운드 prefetch

Widget/
  TodayQRWidget    오늘 보기 위젯 + 갱신 버튼
  HeygroundControl 잠금화면 '출입' 버튼 (iOS 18+)
  Intents          RefreshQRIntent / OpenQRIntent
```

비밀번호는 저장하지 않고 refresh_token만 기기 Keychain에 남깁니다. 서버는 쓰지 않습니다.

## 빌드

Xcode가 필요합니다. 프로젝트 파일은 [XcodeGen](https://github.com/yonaskolb/XcodeGen)으로
`project.yml`에서 생성하며, 편의를 위해 생성 결과(`HeygroundQR.xcodeproj`)도 함께 커밋해 두었습니다.

```
open HeygroundQR.xcodeproj
```

`project.yml`을 고쳤다면 `brew install xcodegen` 후 `xcodegen generate`로 다시 만듭니다.

Xcode에서 두 타깃(`HeygroundQR`, `HeygroundQRWidget`) 모두 서명 팀을 지정해야 하고,
개발자 계정에 아래 두 가지가 등록돼 있어야 합니다.

- App Group `group.io.60hz.heygroundqr`
- Keychain Sharing `io.60hz.heygroundqr`

배포는 TestFlight를 씁니다. 빌드가 90일마다 만료되므로 주기적으로 재업로드가 필요하고,
사외 테스터를 추가하면 베타 심사를 한 번 거칩니다.

## 검증이 필요한 부분

오늘 보기 위젯의 갱신 버튼이 **잠금 상태에서도 실행되는지**는 실기기 확인이 필요합니다.
Live Activity의 버튼은 잠금 중에도 동작하지만 오늘 보기 위젯은 문서화가 약합니다.
동작하지 않더라도 잠금화면 '출입' 버튼 경로는 그대로 쓸 수 있습니다.

잠금 중 접근을 위해 Keychain은 `AfterFirstUnlock`, QR 캐시 파일은
`completeUntilFirstUserAuthentication`으로 보호 수준을 낮춰 두었습니다.
사용자가 설정에서 "잠금 상태에서 오늘 보기"를 꺼두면 위젯 경로 자체가 막힙니다.

## Who

- 이혁준 (hj.lee0608@60hz.io)
