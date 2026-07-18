/// 익명 설치 식별자(install_id) — SPEC T7.
///
/// "앱 첫 실행 시 UUID 생성·영속 저장, 모든 RECOG_EVENTS에 첨부." 최초 호출 시
/// UUID v4를 생성해 [SharedPreferences]에 저장하고, 이후 호출(재실행 포함)은
/// 저장된 값을 그대로 반환한다 — 기기당 1개, 앱 재실행에도 불변.
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// SharedPreferences 저장 키.
const String installIdPrefsKey = 'ecomap.install_id';

/// install_id 로더.
class InstallIdStore {
  InstallIdStore({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  /// 저장된 install_id를 반환하거나, 없으면 UUID v4를 생성해 저장 후 반환.
  ///
  /// 같은 기기에서 여러 번 호출해도(앱 재실행 포함) 항상 같은 값을 반환한다.
  Future<String> load() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(installIdPrefsKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final generated = _uuid.v4();
    await prefs.setString(installIdPrefsKey, generated);
    return generated;
  }
}
