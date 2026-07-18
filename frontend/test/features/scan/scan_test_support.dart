// T5 스캔 위젯 테스트 공용 헬퍼.
//
// FakeAsync(위젯 테스트) 환경에서 rootBundle 에셋 로드는 두 번째 테스트부터
// 완료되지 않아 pumpAndSettle이 무한 대기한다. 데이터 레이어가 이를 위해
// 노출한 [assetBundleProvider] 오버라이드 지점에 동기 파일 번들을 주입한다.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:ecomap/shared/mapping_loader.dart';

/// 동기 파일 읽기 에셋 번들 — 마이크로태스크만으로 완료돼 FakeAsync 안전.
///
/// `flutter test`의 cwd는 패키지 루트(frontend/)라 에셋 키가 곧 상대 경로다.
class SyncFileAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

/// 동기화된 실제 매핑 에셋 로드 (단일 소스 — 기대값도 mapping.json에서).
RecycleMapping loadMappingFromDisk() => RecycleMapping.fromJson(
      jsonDecode(File('assets/data/mapping.json').readAsStringSync())
          as Map<String, dynamic>,
    );
