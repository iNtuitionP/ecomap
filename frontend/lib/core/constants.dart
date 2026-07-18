/// 앱 전역 상수 — 데모 기준 위치·도보 환산·사각지대 판정 반경.
///
/// 데모는 GPS 플러그인 없이 위치를 **철산역으로 고정**한다(데모 통제성 —
/// 심사장 네트워크·권한 변수 제거). 실위치 연동은 8월 범위(TODOS).
library;

import 'package:latlong2/latlong.dart';

/// 데모 기본 위치 — 철산역.
const LatLng demoLocation = LatLng(37.4757, 126.8677);

/// 도보 속도 (m/분). 도보 소요 = ceil(거리m ÷ 이 값).
const double walkSpeedMetersPerMinute = 67;

/// 사각지대(tooFar) 판정 반경 (m) — 최근접 거점이 이 반경을 넘으면
/// "근처 없음" 안내 + 시(市) 알리기 UX로 분기한다 (SPEC T6).
const double gapRadiusMeters = 1500;
