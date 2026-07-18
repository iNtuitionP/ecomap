// 분리배출 가이드 화면 — 실제 rules.json 에셋으로 렌더 검증 (목업 ③).
//
// 검증: 단계 수 == rules.json steps 길이 · 팁 배너 · 출처 캡션 · CTA ·
// 8카테고리 전부 하드코딩 없이 동작.

import 'dart:convert' show utf8;

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap/core/theme/app_theme.dart';
import 'package:ecomap/core/widgets/widgets.dart';
import 'package:ecomap/data/providers.dart';
import 'package:ecomap/features/guide/guide_screen.dart';
import 'package:ecomap/shared/mapping_loader.dart';

/// 실제 에셋 내용을 setUpAll 에서 미리 읽어 동기 제공하는 번들 —
/// testWidgets 의 FakeAsync 존에서는 rootBundle 실 I/O 가 완료되지 않아
/// providers.dart 가 문서화한 assetBundleProvider 오버라이드 지점을 쓴다.
class _MemoryAssetBundle extends CachingAssetBundle {
  _MemoryAssetBundle(this._strings);

  final Map<String, String> _strings;

  @override
  Future<ByteData> load(String key) {
    final value = _strings[key];
    if (value == null) {
      return Future<ByteData>.error(FlutterError('asset 없음: $key'));
    }
    return SynchronousFuture(ByteData.sublistView(utf8.encode(value)));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    final value = _strings[key];
    if (value == null) {
      return Future<String>.error(FlutterError('asset 없음: $key'));
    }
    return SynchronousFuture(value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryAssetBundle bundle;
  late Map<String, DisposalRule> rules;
  late List<String> categoryIds;

  setUpAll(() async {
    // 실데이터 정본을 그대로 사용 — 테스트에도 카테고리·단계 하드코딩 없음.
    bundle = _MemoryAssetBundle({
      mappingAssetPath: await rootBundle.loadString(mappingAssetPath),
      rulesAssetPath: await rootBundle.loadString(rulesAssetPath),
    });
    final loader = MappingLoader(bundle: bundle);
    rules = await loader.loadRules();
    categoryIds =
        (await loader.loadMapping()).categories.map((c) => c.id).toList();
  });

  Widget buildScreen(String categoryId) {
    return ProviderScope(
      overrides: [assetBundleProvider.overrideWithValue(bundle)],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: GuideScreen(categoryId: categoryId),
      ),
    );
  }

  group('GuideScreen', () {
    testWidgets('첫 카테고리 가이드 — 앱바 라벨 + 단계 수 == rules.json steps 길이',
        (tester) async {
      final id = categoryIds.first;
      final rule = rules[id]!;

      await tester.pumpWidget(buildScreen(id));
      await tester.pumpAndSettle();

      // 앱바: '{label} 버리는 법'
      expect(find.text('${rule.label} 버리는 법'), findsOneWidget);

      // 단계 원 개수가 rules.json steps 길이와 일치.
      expect(find.byType(StepCircle), findsNWidgets(rule.steps.length));

      // 수거함 찾기 CTA 존재.
      expect(find.text('수거함 찾기'), findsOneWidget);
    });

    testWidgets('styrofoam 가이드 렌더 — 단계 수 일치 + 팁 배너', (tester) async {
      const id = 'styrofoam';
      final rule = rules[id]!;

      await tester.pumpWidget(buildScreen(id));
      await tester.pumpAndSettle();

      expect(find.text('${rule.label} 버리는 법'), findsOneWidget);
      expect(find.byType(StepCircle), findsNWidgets(rule.steps.length));

      // caution 팁 배너 노출.
      expect(find.textContaining(rule.caution), findsOneWidget);
    });

    testWidgets('출처 캡션 — rules.json source 필드 표기 (B2G 신뢰성)', (tester) async {
      final id = categoryIds.first;
      final rule = rules[id]!;

      await tester.pumpWidget(buildScreen(id));
      await tester.pumpAndSettle();

      expect(rule.source, isNotEmpty);
      expect(find.textContaining(rule.source), findsOneWidget);
    });

    testWidgets('8카테고리 전부 렌더 — 단계 수·라벨·출처 모두 rules.json 소비',
        (tester) async {
      expect(categoryIds, hasLength(8));

      for (final id in categoryIds) {
        final rule = rules[id]!;

        await tester.pumpWidget(buildScreen(id));
        await tester.pumpAndSettle();

        expect(find.text('${rule.label} 버리는 법'), findsOneWidget,
            reason: '[$id] 앱바 라벨');
        expect(find.byType(StepCircle), findsNWidgets(rule.steps.length),
            reason: '[$id] 단계 수');
        expect(find.textContaining(rule.caution), findsOneWidget,
            reason: '[$id] 팁 배너');
        expect(find.textContaining(rule.source), findsOneWidget,
            reason: '[$id] 출처 캡션');

        // 다음 카테고리 렌더 전 초기화.
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('없는 카테고리 id — 크래시 없이 안내 문구', (tester) async {
      await tester.pumpWidget(buildScreen('unknown-category'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(StepCircle), findsNothing);
      expect(find.textContaining('가이드를 찾지 못했어요'), findsOneWidget);
    });
  });
}
