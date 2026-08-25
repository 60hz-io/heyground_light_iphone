# 잠금화면 QR 위젯 계획 — 타당성 검토

원안(Silent Push + 잠금화면 위젯) 검토 결과와 수정 설계.
독자는 개발자 기준으로 작성했다.

## 결론

원안의 **구조(App Group 공유 + 인터랙티브 위젯 갱신)는 타당하나, 전제 두 개가 틀렸다.**

1. `.systemSmall/.systemMedium` 위젯은 잠금화면에 뜨지 않는다. 문서 제목의 "잠금화면 위젯"이
   기술적으로 성립하지 않는다.
2. 인증이 빠져 있다. 헤이그라운드 QR은 사용자별이라 무인증 `GET /qr` 전제가 성립하지 않고,
   서버가 대신 받아오려면 자격증명을 서버가 보관해야 한다.

Silent Push는 갱신 수단으로 신뢰할 수 없어 1차 범위에서 제외를 권한다.

---

## 1. 치명적 문제

### 1.1 잠금화면 위젯에는 QR을 그릴 수 없다

잠금화면 위젯은 accessory 계열(`accessoryCircular` / `accessoryRectangular` / `accessoryInline`)
뿐이고, 이 계열은 vibrant 렌더링으로만 그려진다. 흑백 QR이 배경이 비치는 반투명 단색이 되어
스캔되지 않는다. 크기도 최대 160×72pt라 밀도 높은 QR은 모듈이 뭉개진다.
`.containerBackground(.black, for: .widget)`도 accessory 계열에서는 무시된다.

원안이 지정한 `.systemSmall/.systemMedium`은 홈 화면과 **오늘 보기**(잠금화면 오른쪽 스와이프)
전용이다. 오늘 보기는 잠금 해제 없이 열리고 풀컬러로 렌더링되므로, 잠금화면에서 스캔 가능한
QR을 보여줄 수 있는 유일한 경로다.

→ 문서 전제를 "잠금화면 위젯"에서 "오늘 보기 위젯 + iOS 18 잠금화면 Control"로 바꾼다.

**근거 (Apple 공식 문서 원문)**

[WidgetRenderingMode](https://developer.apple.com/documentation/widgetkit/widgetrenderingmode) — Overview

> The system can modify the appearance of accessory family widgets. For example, it renders
> widgets on the Lock Screen on iPhone using the vibrant mode, while it renders widget-based
> complications in watchOS using either the fullColor or accented modes, depending on the watch
> face and the user's settings.

[WidgetRenderingMode.vibrant](https://developer.apple.com/documentation/widgetkit/widgetrenderingmode/vibrant)

> The system desaturates the widget, making a monochrome version that it uses to create an
> adaptive, vibrant effect.

[Creating accessory widgets and watch complications](https://developer.apple.com/documentation/widgetkit/creating-accessory-widgets-and-watch-complications)

> Support accessory widgets that appear on the Lock Screen and as complications on Apple Watch.
>
> WidgetKit allows you to extend the reach of your app to the Lock Screen on iPhone and iPad,
> and to the Smart Stack on Apple Watch as accessory widgets.

`fullColor`는 watchOS 문맥에서만 언급되고 iPhone 잠금화면에는 해당되지 않는다.
[WidgetFamily](https://developer.apple.com/documentation/widgetkit/widgetfamily)의 `systemSmall`
등 system 계열 설명에는 잠금화면 언급이 없다.

Apple이 "system 계열은 잠금화면에 못 쓴다"고 부정문으로 명시하진 않는다. 근거는 "잠금화면에
놓이는 위젯은 accessory 계열"이라는 긍정 서술과, 그 계열이 vibrant로 렌더링된다는 서술이다.

### 1.2 인증 설계가 없다

`QRAPI.fetchQR()`이 무인증 `GET /qr`을 호출한다. 실제 QR은 heyground OAuth 토큰이 있어야
발급되므로 둘 중 하나를 골라야 한다.

- 클라이언트 인증: 앱이 로그인하고 refresh token을 기기 Keychain에 보관한다.
  안드로이드·웹 버전과 동일하고 서버가 필요 없다.
- 서버 인증: 서버가 사용자 자격증명을 보관하고 QR을 대신 받아온다.
  Silent Push를 쓰려면 이 방식이 강제된다.

원안은 후자를 전제하면서 그 사실을 명시하지 않았다. 사내 출입 자격증명을 서버가 들고 있게
되는 변경이라 보안 검토가 필요하다.

### 1.3 Silent Push 10분 주기는 보장되지 않는다

`content-available` 알림은 시스템이 지연·병합·폐기할 수 있고, `apns-priority: 5`는 그 지연을
명시적으로 허용하는 값이다. 사용자가 앱을 강제 종료했으면 아예 수신되지 않고, 저전력 모드에서는
백그라운드 처리가 중단된다. 원안의 "Wi-Fi + 배터리 50% 이상에서 80~90% 도달"은 근거가 없다.

사용자당 하루 144회는 스로틀링 대상이 되기 쉽다. 게이트 앞에서 만료된 QR을 보게 될 확률이
높아 1차 범위에서 제외한다.

### 1.4 App Intent 배치 위치

`RefreshQRIntent`가 Main App 타깃에만 있으면 위젯 확장에서 `Button(intent:)`으로 참조할 수
없어 빌드가 되지 않는다. 인텐트와 저장소 코드는 Shared로 옮겨 두 타깃에 모두 컴파일한다.

---

## 2. 코드 수준 결함

| 위치 | 문제 | 수정 |
|---|---|---|
| `QRAPI.fetchQR()` | 응답은 `{"image": base64}` JSON인데 raw `Data`를 그대로 PNG로 저장 | base64 디코딩 단계 추가, 또는 서버가 `image/png` 직접 반환 |
| `QRThrottle` | `static var`는 확장 프로세스가 매번 새로 뜨면 유지되지 않음 | App Group `UserDefaults`에 타임스탬프 저장 |
| `formattedRemaining()` | 렌더 시점 1회 계산이라 카운트다운이 멈춤 | `Text(expiresAt, style: .timer)` |
| `policy: .never` | push 실패 시 만료된 QR이 무기한 남음 | `.after(expiresAt)`을 하한으로 설정 |
| Keychain(추가 시) | 기본 접근성 `WhenUnlocked`는 잠금 상태에서 읽기 실패 | `AfterFirstUnlock` 지정 |
| Edge case 표 | iOS 16 대응 항목이 있으나 deployment target은 17.0 | 항목 삭제 |

파일 기본 보호 수준은 `CompleteUntilFirstUserAuthentication`이라 QR 이미지 자체는 잠금
상태에서도 읽힌다. 다만 의도를 드러내기 위해 명시적으로 지정하는 편이 낫다.

---

## 3. 유지할 부분

- App Group 컨테이너에 이미지 + 메타데이터를 두고 앱·위젯이 공유하는 구조
- `Button(intent:)` 수동 갱신 (iOS 17+)
- 연타 방지 쿨다운
- `interpolation(.none)`
- Edge case 표와 테스트 체크리스트 — 항목 자체는 그대로 쓸 만하다

---

## 4. 수정 설계

```
진입 경로 1: 잠금화면 Control(iOS 18) → Face ID → QR 화면 → 즉시 갱신
진입 경로 2: 잠금화면 오른쪽 스와이프 → 오늘 보기 위젯 → (만료 시) 갱신 버튼 탭

준비 트리거:  회사 300m 지오펜스 진입 → 백그라운드 실행 → 토큰 갱신 + QR prefetch
갱신 방식:    사용자 탭 + 위젯 타임라인(가능한 범위) — Silent Push 없음
인증:         앱이 직접 로그인, refresh token은 기기 Keychain (서버 없음)
```

Silent Push를 뺀 대신 지오펜스가 "회사 도착 시 준비" 역할을 맡는다. 도착 시점 한 번만
울리므로 QR 자체는 문 앞에서 만료될 수 있지만, 토큰이 살아 있어 호출 한 번으로 끝난다.

---

## 5. 현재 리포 구현 현황

원안의 P0~P4 상당 부분이 이 리포에 이미 있다.

| 원안 Phase | 상태 | 대응 파일 |
|---|---|---|
| P0 App Group + API + 위젯 렌더 | 구현됨 | `Shared/AppGroup.swift`, `Shared/HeygroundAPI.swift`, `Widget/TodayQRWidget.swift` |
| P1 App Intent 갱신 | 구현됨 | `Widget/Intents.swift` |
| P2 Silent Push | **제외** | — |
| P3 만료 표시·placeholder·error | 구현됨 | `Shared/QRRepository.swift`, `Widget/TodayQRWidget.swift` |
| P4 UI polish | 구현됨 | `App/QRView.swift` |
| P5 기기 테스트 | 미착수 | Xcode 설치 후 |
| P6 배포 | 미착수 | TestFlight |

원안에 있으나 아직 없는 것: 없음 (연타 쿨다운 반영 완료).
원안에 없으나 구현된 것: 로그인 화면, 지오펜스 prefetch, 잠금화면 Control.

---

## 6. 남은 작업

1. Xcode 설치 후 컴파일 검증 (현재까지 문법 파싱만 통과)
2. 개발자 계정에 App Group `group.io.60hz.heygroundqr`, Keychain Sharing `io.60hz.heygroundqr` 등록
3. ~~오늘 보기 위젯의 갱신 버튼 동작 확인~~ — **2026-08-25 시뮬레이터에서 검증 완료.**
   오늘 보기에 풀컬러 QR 이 뜨고 탭 갱신도 동작한다. 잠금 상태에서의 동작만 실기기 확인이 남았다
4. 연타 쿨다운, 만료 카운트다운 추가
5. TestFlight 배포 (빌드 90일 만료, 사외 테스터는 베타 심사 1회)

배포는 App Store가 아니라 TestFlight를 쓴다. 사내 출입용 앱이라 공개 심사에 올릴 이유가 없다.
