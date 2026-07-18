// T6 · 지도 화면 — 마커 빌드(274핀·품목 필터 정확성)·최근접 리스트·센터 이동·주소 복사.
//
// 수기 대조값(test/data/nearest_service_test.dart 와 동일 근거):
//   pet @ 철산역 최근접 = 오리로854번길 10 무인회수기, 162.728m → '163m', 도보 3분
// 타일은 mapTileLayerProvider 오버라이드로 네트워크를 타지 않는다.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap/core/constants.dart';
import 'package:ecomap/core/theme/app_theme.dart';
import 'package:ecomap/data/bins_repository.dart';
import 'package:ecomap/data/models.dart';
import 'package:ecomap/data/providers.dart';
import 'package:ecomap/features/map/map_screen.dart';
import 'package:ecomap/shared/mapping_loader.dart';

// 위젯 테스트 본문은 FakeAsync 존이라 대용량 에셋 로드(isolate 디코드)가
// 완료되지 않는다 — setUpAll(실 async)에서 미리 로드해 프로바이더를 덮는다.
late List<BinRecord> bins;
late RecycleMapping mapping;

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      mapTileLayerProvider.overrideWithValue(const SizedBox.shrink()),
      binsProvider.overrideWith((ref) async => bins),
      mappingProvider.overrideWith((ref) async => mapping),
      ...overrides,
    ],
    child: MaterialApp(theme: buildAppTheme(), home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    bins = await BinsRepository().loadBins();
    mapping = await MappingLoader().loadMapping();
  });

  group('buildBinMarkers — 핀 데이터 정확성 (실데이터 274행)', () {
    test('카테고리 없음 → 전체 274핀', () {
      final markers = buildBinMarkers(bins: bins);
      expect(markers, hasLength(274));
    });

    test('pet 필터 → 해당 품목 Y 거점 63핀만 (독립 필터와 교차 검증)', () {
      final pet = mapping.byId('pet')!;
      final markers = buildBinMarkers(bins: bins, category: pet);
      final expected =
          bins.where((b) => b.acceptsAny(pet.csvFlags)).toList();
      expect(markers, hasLength(expected.length));
      expect(markers, hasLength(63));
    });

    test('8카테고리 전부: 핀 수 == acceptsAny 독립 필터 수 (0핀 카테고리 없음)', () {
      for (final cat in mapping.categories) {
        final markers = buildBinMarkers(bins: bins, category: cat);
        final expected = bins.where((b) => b.acceptsAny(cat.csvFlags)).length;
        expect(markers, hasLength(expected),
            reason: '${cat.id} 핀 수가 데이터 필터와 다름');
        expect(markers, isNotEmpty, reason: '${cat.id} 핀 0개');
      }
    });
  });

  group('표기 헬퍼', () {
    test('formatDistance — 1km 미만 m 반올림 / 이상 소수 1자리 km', () {
      expect(formatDistance(162.728), '163m');
      expect(formatDistance(999.4), '999m');
      expect(formatDistance(1000), '1.0km');
      expect(formatDistance(6403.615), '6.4km');
    });

    test('binTypeEmoji — 실데이터 전 타입에 전용 이모지 배정', () {
      expect(binTypeEmoji('무인회수기'), '🤖');
      expect(binTypeEmoji('재활용품 분리배출함'), '♻️');
      expect(binTypeEmoji('의류 수거함'), '👕');
      // 실데이터의 모든 타입이 기본값(📍) 아닌 전용 이모지를 받는다.
      for (final bin in bins) {
        expect(binTypeEmoji(bin.type), isNot('📍'),
            reason: '타입 "${bin.type}" 전용 이모지 없음');
      }
    });
  });

  group('MapScreen — 전체 지도 (/map)', () {
    testWidgets('274행 로드: 지도·내 위치 마커·attribution·최근접 5곳 리스트 렌더',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const MapScreen()));
      await tester.pumpAndSettle();

      expect(find.text('내 주변 수거함'), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(MyLocationMarker), findsOneWidget);
      expect(find.text('© OpenStreetMap © CARTO'), findsOneWidget);
      expect(find.text('전체 274곳'), findsOneWidget);
      expect(find.byType(BinListTile), findsNWidgets(5));
      // 뷰포트 안 핀은 렌더된다 (전체 274핀은 buildBinMarkers 단위 테스트가 보증).
      expect(find.byType(BinMarkerIcon), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('MapScreen — 품목 필터 (/map/pet)', () {
    testWidgets('앱바 "{라벨} 받는 곳" + 63곳 + 최근접 리스트 수기 대조(163m·도보 3분)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const MapScreen(categoryId: 'pet')));
      await tester.pumpAndSettle();

      final petLabel = mapping.byId('pet')!.label;
      expect(find.text('$petLabel 받는 곳'), findsOneWidget);
      expect(find.text('전체 63곳'), findsOneWidget);
      expect(find.byType(BinListTile), findsNWidgets(5));
      // 최근접 1위 수기 대조.
      expect(find.text('163m'), findsOneWidget);
      expect(find.text('도보 3분'), findsOneWidget);
      expect(find.textContaining('무인회수기'), findsWidgets);
      // NearbyResult — 리다이렉트 없이 지도 유지.
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('리스트 항목 탭 → 지도 센터가 해당 거점 좌표로 이동', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const MapScreen(categoryId: 'pet')));
      await tester.pumpAndSettle();

      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      final controller = map.mapController!;
      expect(controller.camera.center.latitude,
          closeTo(demoLocation.latitude, 1e-9));

      await tester.tap(find.byType(BinListTile).first);
      await tester.pumpAndSettle();

      // pet 최근접 거점 = 오리로854번길 10 무인회수기.
      final nearest = bins.firstWhere((b) =>
          b.addr == '경기도 광명시 오리로854번길 10' && b.name == '무인회수기');
      expect(controller.camera.center.latitude, closeTo(nearest.lat, 1e-6));
      expect(controller.camera.center.longitude, closeTo(nearest.lng, 1e-6));
    });

    testWidgets('주소 복사 버튼 → 클립보드 적재 + 스낵바', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(_wrap(const MapScreen(categoryId: 'pet')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.copy_rounded).first);
      await tester.pump();

      final copy =
          calls.where((c) => c.method == 'Clipboard.setData').toList();
      expect(copy, hasLength(1));
      expect((copy.single.arguments as Map)['text'],
          '경기도 광명시 오리로854번길 10');
      expect(find.text('주소를 복사했어요'), findsOneWidget);
    });
  });

  group('MapScreen — 알 수 없는 카테고리 graceful', () {
    testWidgets('mapping에 없는 id → 전체 지도로 폴백 (크래시 금지)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester
          .pumpWidget(_wrap(const MapScreen(categoryId: 'no-such-category')));
      await tester.pumpAndSettle();

      expect(find.text('내 주변 수거함'), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
