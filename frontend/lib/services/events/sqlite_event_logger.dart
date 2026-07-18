/// SQLite 기반 [EventLogger] — SPEC T7 DB 스키마(RECOG_EVENTS, POINT_LOGS).
///
/// 데모 = 앱 로컬 SQLite. 8월 FastAPI/PostGIS 이관 시 이 파일만 교체하면
/// 호출부(`EventLogger` 인터페이스)는 그대로 유지된다.
///
/// **POINT_LOGS는 테이블 생성만** 한다 — 적립 로직·UI는 SPEC T7-3 측정 게이트
/// 통과 후 별도 작업. 이 파일에서 POINT_LOGS에 값을 쓰지 않는다.
///
/// 웹(kIsWeb)에는 sqflite 플러그인이 없으므로 [createEventLogger] 팩토리가
/// 자동으로 [InMemoryEventLogger]로 폴백한다.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../data/events_api.dart';

/// RECOG_EVENTS 테이블명.
const String recogEventsTable = 'RECOG_EVENTS';

/// POINT_LOGS 테이블명(생성만 — 적립 로직 없음, SPEC T7-3 측정 게이트).
const String pointLogsTable = 'POINT_LOGS';

/// CIVIC_REPORTS 테이블명 — "이 사각지대를 광명시에 알리기"(T6) 이벤트.
/// SPEC 본문 DB 스키마 블록에는 없지만 [EventLogger.logCivicReport] 구현을
/// 위해 필요한 최소 보조 테이블(적립·집계 로직 없음).
const String civicReportsTable = 'CIVIC_REPORTS';

const String _createRecogEventsSql = '''
CREATE TABLE $recogEventsTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT NOT NULL,
  lat REAL NOT NULL,
  lng REAL NOT NULL,
  dong TEXT NOT NULL,
  category TEXT NOT NULL,
  csv_flag TEXT NOT NULL,
  confidence REAL NOT NULL,
  manual_fallback INTEGER NOT NULL,
  install_id TEXT NOT NULL,
  session_id TEXT NOT NULL
)
''';

const String _createPointLogsSql = '''
CREATE TABLE $pointLogsTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  install_id TEXT NOT NULL,
  points INTEGER NOT NULL,
  reason TEXT NOT NULL,
  ts TEXT NOT NULL
)
''';

const String _createCivicReportsSql = '''
CREATE TABLE $civicReportsTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT NOT NULL,
  dong TEXT NOT NULL,
  item TEXT NOT NULL
)
''';

/// 앱 로컬 DB 파일명.
const String eventsDbFileName = 'ecomap_events.db';

class SqliteEventLogger implements EventLogger {
  SqliteEventLogger._(this._db);

  final Database _db;

  /// 내부 [Database] 핸들 — 테스트에서 스키마·적재 결과를 직접 조회할 때 사용.
  /// 앱 호출부는 [EventLogger] 인터페이스 메서드만 사용해야 한다.
  Database get database => _db;

  /// DB를 열고(없으면 생성) 스키마를 만든다.
  ///
  /// [path]를 지정하지 않으면 플랫폼 기본 앱 DB 경로
  /// (`getDatabasesPath()/$eventsDbFileName`)를 사용한다. 테스트에서는
  /// `inMemoryDatabasePath`(sqflite_common_ffi)를 넘겨 인메모리로 검증한다.
  ///
  /// `singleInstance: false`로 연다 — sqflite는 기본적으로 같은 경로 문자열의
  /// DB를 캐시해 재사용하는데, `inMemoryDatabasePath`(`:memory:`)로 여는
  /// 테스트마다 이 캐시를 공유하면 이전 테스트가 적재한 행이 새 로거에
  /// 그대로 보이는 상태 누수가 생긴다. 이 팩토리는 앱 생애주기에서 1회만
  /// 호출되므로 캐시를 포기해도 프로덕션 동작에는 영향이 없다.
  static Future<SqliteEventLogger> open({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), eventsDbFileName);
    final db = await openDatabase(
      dbPath,
      version: 1,
      singleInstance: false,
      onCreate: (db, version) async {
        await db.execute(_createRecogEventsSql);
        await db.execute(_createPointLogsSql);
        await db.execute(_createCivicReportsSql);
      },
    );
    return SqliteEventLogger._(db);
  }

  @override
  Future<void> logRecognition({
    required String category,
    required String csvFlag,
    required double confidence,
    required bool manualFallback,
    required double lat,
    required double lng,
    required String dong,
    required String installId,
    required String sessionId,
  }) async {
    await _db.insert(recogEventsTable, {
      'ts': DateTime.now().toIso8601String(),
      'lat': lat,
      'lng': lng,
      'dong': dong,
      'category': category,
      'csv_flag': csvFlag,
      'confidence': confidence,
      'manual_fallback': manualFallback ? 1 : 0,
      'install_id': installId,
      'session_id': sessionId,
    });
  }

  @override
  Future<void> logCivicReport({
    required String dong,
    required String item,
  }) async {
    await _db.insert(civicReportsTable, {
      'ts': DateTime.now().toIso8601String(),
      'dong': dong,
      'item': item,
    });
  }

  /// 테스트/앱 종료 시 정리.
  Future<void> close() => _db.close();
}

/// 플랫폼별 [EventLogger] 팩토리.
///
/// 웹(kIsWeb)에는 sqflite 플러그인이 없으므로 [InMemoryEventLogger]로
/// 폴백한다. 그 외(모바일/데스크톱)는 [SqliteEventLogger]를 연다.
///
/// [path]는 테스트에서 `inMemoryDatabasePath`(sqflite_common_ffi)를 넘기기
/// 위한 훅 — 앱 호출부는 생략해 플랫폼 기본 DB 경로를 사용한다.
Future<EventLogger> createEventLogger({String? path}) async {
  if (kIsWeb) {
    return InMemoryEventLogger();
  }
  return SqliteEventLogger.open(path: path);
}
