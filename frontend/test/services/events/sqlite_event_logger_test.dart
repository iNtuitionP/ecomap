// services/events · SqliteEventLogger — RECOG_EVENTS/POINT_LOGS 스키마 생성·적재
// (SPEC T7-2, T7-3). sqflite_common_ffi(in-memory)로 실 SQLite 검증.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ecomap/data/events_api.dart';
import 'package:ecomap/services/events/sqlite_event_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<SqliteEventLogger> openInMemory() =>
      SqliteEventLogger.open(path: inMemoryDatabasePath);

  test('open() — RECOG_EVENTS/POINT_LOGS/CIVIC_REPORTS 테이블 생성', () async {
    final logger = await openInMemory();

    final tables = await logger.database.query(
      'sqlite_master',
      where: 'type = ?',
      whereArgs: ['table'],
      columns: ['name'],
    );
    final names = tables.map((r) => r['name']).toSet();

    expect(names, containsAll([recogEventsTable, pointLogsTable, civicReportsTable]));
  });

  test('logRecognition — RECOG_EVENTS 행 1건 적재, 스키마 컬럼 전부 존재', () async {
    final logger = await openInMemory();

    await logger.logRecognition(
      category: 'pet',
      csvFlag: '무색페트병',
      confidence: 0.92,
      manualFallback: false,
      lat: 37.4757,
      lng: 126.8677,
      dong: '철산동',
      installId: 'install-1',
      sessionId: 'session-1',
    );

    final rows = await logger.database.query(recogEventsTable);
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row['category'], 'pet');
    expect(row['csv_flag'], '무색페트병');
    expect(row['confidence'], 0.92);
    expect(row['manual_fallback'], 0);
    expect(row['lat'], 37.4757);
    expect(row['lng'], 126.8677);
    expect(row['dong'], '철산동');
    expect(row['install_id'], 'install-1');
    expect(row['session_id'], 'session-1');
    expect(row['ts'], isNotNull);
    expect(row['id'], isNotNull);
  });

  test('logRecognition — manual_fallback=true는 1로 저장', () async {
    final logger = await openInMemory();

    await logger.logRecognition(
      category: 'etc',
      csvFlag: '플라스틱',
      confidence: 0.41,
      manualFallback: true,
      lat: 0,
      lng: 0,
      dong: '철산동',
      installId: 'install-1',
      sessionId: 'session-2',
    );

    final rows = await logger.database.query(recogEventsTable);
    expect(rows.single['manual_fallback'], 1);
  });

  test('logRecognition — manual_fallback=false는 0으로 저장', () async {
    final logger = await openInMemory();

    await logger.logRecognition(
      category: 'pet',
      csvFlag: '무색페트병',
      confidence: 0.95,
      manualFallback: false,
      lat: 0,
      lng: 0,
      dong: '철산동',
      installId: 'install-1',
      sessionId: 'session-3',
    );

    final rows = await logger.database.query(recogEventsTable);
    expect(rows.single['manual_fallback'], 0);
  });

  test('logRecognition 여러 건 — 누적 적재', () async {
    final logger = await openInMemory();
    for (var i = 0; i < 3; i++) {
      await logger.logRecognition(
        category: 'pet',
        csvFlag: '무색페트병',
        confidence: 0.9,
        manualFallback: false,
        lat: 0,
        lng: 0,
        dong: '철산동',
        installId: 'install-1',
        sessionId: 'session-$i',
      );
    }

    final rows = await logger.database.query(recogEventsTable);
    expect(rows, hasLength(3));
  });

  test('logCivicReport — dong/item 적재', () async {
    final logger = await openInMemory();

    await logger.logCivicReport(dong: '옥길동', item: '스티로폼');

    final rows = await logger.database.query(civicReportsTable);
    expect(rows, hasLength(1));
    expect(rows.single['dong'], '옥길동');
    expect(rows.single['item'], '스티로폼');
  });

  test('POINT_LOGS 테이블 — 생성만 되고 로거 호출로는 절대 채워지지 않음(적립 로직 없음, T7-3)',
      () async {
    final logger = await openInMemory();
    await logger.logRecognition(
      category: 'pet',
      csvFlag: '무색페트병',
      confidence: 0.9,
      manualFallback: false,
      lat: 0,
      lng: 0,
      dong: '철산동',
      installId: 'install-1',
      sessionId: 'session-1',
    );
    await logger.logCivicReport(dong: '철산동', item: '스티로폼');

    final rows = await logger.database.query(pointLogsTable);
    expect(rows, isEmpty);
  });

  test('POINT_LOGS 스키마 — id/install_id/points/reason/ts 컬럼으로 직접 insert 가능',
      () async {
    final logger = await openInMemory();

    final rowId = await logger.database.insert(pointLogsTable, {
      'install_id': 'install-1',
      'points': 10,
      'reason': 'recognition',
      'ts': DateTime.now().toIso8601String(),
    });

    final rows = await logger.database.query(pointLogsTable);
    expect(rows, hasLength(1));
    expect(rows.single['id'], rowId);
    expect(rows.single['install_id'], 'install-1');
    expect(rows.single['points'], 10);
    expect(rows.single['reason'], 'recognition');
  });

  test('EventLogger 인터페이스로 다형 사용 가능', () async {
    final EventLogger logger = await openInMemory();
    expect(logger, isA<EventLogger>());
  });

  test('createEventLogger() — 비웹 환경(테스트 VM)에서는 SqliteEventLogger 반환', () async {
    final logger = await createEventLogger(path: inMemoryDatabasePath);
    expect(logger, isA<SqliteEventLogger>());
    if (logger is SqliteEventLogger) {
      await logger.close();
    }
  });
}
