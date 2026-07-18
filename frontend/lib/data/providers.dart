/// 데이터 레이어 Riverpod 프로바이더 — 화면 레이어는 이 파일만 임포트하면 됨.
///
/// 모든 에셋 접근은 [assetBundleProvider] 를 거친다 — 위젯 테스트에서
/// `ProviderScope(overrides: [assetBundleProvider.overrideWithValue(...)])`
/// 로 목킹 가능. 기본값은 실제 rootBundle(동기화된 assets/data/).
library;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../services/events/install_id.dart';
import '../shared/mapping_loader.dart';
import 'bins_repository.dart';
import 'events_api.dart';
import 'models.dart';
import 'nearest_service.dart';
import 'policy_repository.dart';

/// 에셋 번들 (테스트 오버라이드 지점).
final assetBundleProvider = Provider<AssetBundle>((ref) => rootBundle);

/// 수거 거점 저장소.
final binsRepositoryProvider = Provider<BinsRepository>(
  (ref) => BinsRepository(bundle: ref.watch(assetBundleProvider)),
);

/// 수거 거점 274행 (bins.geocoded.json).
final binsProvider = FutureProvider<List<BinRecord>>(
  (ref) => ref.watch(binsRepositoryProvider).loadBins(),
);

/// 매핑·룰 로더 (T4 단일 소스).
final mappingLoaderProvider = Provider<MappingLoader>(
  (ref) => MappingLoader(bundle: ref.watch(assetBundleProvider)),
);

/// 8카테고리 ↔ CSV 플래그 매핑 + confidence_threshold.
final mappingProvider = FutureProvider<RecycleMapping>(
  (ref) => ref.watch(mappingLoaderProvider).loadMapping(),
);

/// 카테고리별 배출 단계 룰.
final rulesProvider = FutureProvider<Map<String, DisposalRule>>(
  (ref) => ref.watch(mappingLoaderProvider).loadRules(),
);

/// 정책카드 저장소.
final policyRepositoryProvider = Provider<PolicyRepository>(
  (ref) => PolicyRepository(bundle: ref.watch(assetBundleProvider)),
);

/// 공백분석 정책카드 문서 (cards = severity_score 내림차순).
final policyCardsProvider = FutureProvider<PolicyCardsDocument>(
  (ref) => ref.watch(policyRepositoryProvider).load(),
);

/// 최근접 수거함 서비스 (매핑 로드 후 생성).
final nearestServiceProvider = FutureProvider<NearestService>(
  (ref) async =>
      NearestService(mapping: await ref.watch(mappingProvider.future)),
);

/// 이벤트 로거 — 기본 InMemory (8월 SQLite/FastAPI 구현으로 교체 지점).
///
/// **네이티브(모바일/데스크톱) 빌드 오버라이드 방법** — `main()`에서 `runApp`
/// 전에 비동기로 실제 로거를 만들고 `ProviderScope.overrides`로 주입한다
/// (플랫폼별 분기는 `services/events/sqlite_event_logger.dart`의
/// `createEventLogger()`가 `kIsWeb`으로 내부 처리하므로 호출부는 분기 불필요):
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   final eventLogger = await createEventLogger(); // kIsWeb → InMemory 폴백
///   runApp(ProviderScope(
///     overrides: [eventLoggerProvider.overrideWithValue(eventLogger)],
///     child: const EcoMapApp(),
///   ));
/// }
/// ```
/// 오버라이드하지 않으면(현재 `main.dart`) 웹·네이티브 공통으로 InMemory가
/// 유지된다 — 데모 안전 기본값.
final eventLoggerProvider = Provider<EventLogger>(
  (ref) => InMemoryEventLogger(),
);

/// 설치 식별자(install_id) — 앱 첫 실행 시 UUID 생성, 이후 재실행에도 불변
/// (SPEC T7-1). [InstallIdStore]가 SharedPreferences에 영속시킨다.
final installIdProvider = FutureProvider<String>(
  (ref) => InstallIdStore().load(),
);

/// 세션 식별자(session_id) — 앱 실행마다 새 UUID.
///
/// `Provider`는 컨테이너 생존 기간 동안 최초 1회만 평가되므로, 앱 프로세스
/// 1회 실행 = 값 1개가 보장된다(SPEC T7 "session_id는 앱 실행마다 uuid").
final sessionIdProvider = Provider<String>((ref) => const Uuid().v4());
