// services/events · InstallIdStore — 첫 실행 UUID 생성 + 재실행 동일값(SPEC T7-1).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecomap/services/events/install_id.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('첫 호출 — UUID v4 형식 값 생성', () async {
    final store = InstallIdStore();
    final id = await store.load();

    expect(id, isNotEmpty);
    // UUID v4 정규식: 8-4-4-4-12 하이픈 구분, 버전 nibble 4, variant 8/9/a/b.
    final v4Pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    expect(v4Pattern.hasMatch(id), isTrue, reason: 'got: $id');
  });

  test('SharedPreferences에 영속 저장됨', () async {
    final store = InstallIdStore();
    final id = await store.load();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(installIdPrefsKey), id);
  });

  test('재호출(같은 인스턴스) — 동일값 반환', () async {
    final store = InstallIdStore();
    final first = await store.load();
    final second = await store.load();

    expect(second, first);
  });

  test('재실행 시뮬레이션(새 인스턴스, 같은 저장소) — 동일값 반환', () async {
    final first = await InstallIdStore().load();
    // 앱 재실행을 흉내: 새 InstallIdStore 인스턴스가 저장된 SharedPreferences를
    // 다시 읽는다(mock 백엔드는 setMockInitialValues 재호출 전까지 유지됨).
    final second = await InstallIdStore().load();

    expect(second, first);
  });

  test('이미 저장된 install_id가 있으면 그대로 반환(재생성하지 않음)', () async {
    SharedPreferences.setMockInitialValues({
      installIdPrefsKey: 'existing-fixed-id',
    });

    final id = await InstallIdStore().load();

    expect(id, 'existing-fixed-id');
  });
}
