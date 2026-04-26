# Auris 🌿
> 이명 관리 앱 · com.kdh.auris

## Firebase 설정
1. Firebase Console → 새 프로젝트 `auris-app` 생성
2. Android 앱 추가: `com.kdh.auris`
3. `google-services.json` → `android/app/` 복사
4. iOS 앱 추가: `com.kdh.auris`
5. `GoogleService-Info.plist` → `ios/Runner/` 복사

## 시작
```bash
flutter pub get
flutter run
```

## 개발 로드맵
- [x] 1단계: 프로젝트 구조 + 테마 + 모델
- [ ] 2단계: 사운드 레이어 믹서
- [ ] 3단계: 신경 디싱크 사운드 엔진
- [ ] 4단계: 햅틱 바이모달 세션
- [ ] 5단계: 기록 + 분석 + Firestore
- [ ] 6단계: 이완 모듈 + AI 대화
