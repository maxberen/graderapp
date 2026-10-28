import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grader_app/features/tests/results_outbox.dart';
import 'package:grader_app/features/tests/results_sync_repository.dart';
import 'package:grader_app/features/tests/test_detail_repository.dart';

/// Servidor de mentira: guarda los POST y puede simular "sin señal".
class _FakeServer implements HttpClientAdapter {
  bool offline = false;
  int? failWithStatus;
  final List<dynamic> posts = [];
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'sin señal',
      );
    }
    if (failWithStatus != null) {
      return ResponseBody.fromString('{}', failWithStatus!);
    }
    paths.add(options.path);
    posts.add(jsonDecode(utf8.decode((await body!.expand((c) => c).toList()))));
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeServer server;
  late ResultsOutbox outbox;
  late ResultsSyncEngine engine;

  setUp(() {
    server = _FakeServer();
    outbox = ResultsOutbox();
    final dio = Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = server;
    engine = ResultsSyncEngine(
      outbox: outbox,
      repository: ResultsSyncRepository(dio),
      fetchDetail: (_) async => throw UnimplementedError(),
      backoff: (_) => const Duration(milliseconds: 300),
      uploadWhileGrading: true,
    );
  });

  tearDown(() => engine.dispose());

  void put(int tech, int student, TechniqueResultStatus s) => outbox.put(
    testId: 7,
    techniqueId: tech,
    studentId: student,
    testStudentId: student + 100,
    result: GradedResult(status: s),
  );

  Future<void> settle([int ms = 100]) =>
      Future.delayed(Duration(milliseconds: ms));

  test('sube lo pendiente y queda todo sincronizado', () async {
    put(1, 1, TechniqueResultStatus.pass);
    engine.kick();
    await settle();
    expect(server.posts, hasLength(1));
    expect(server.posts.single.single['TEST_STUDENT_ID'], 101);
    expect(server.posts.single.single['PASSED'], 1);
    expect(server.posts.single.single.containsKey('FAIL'), isFalse);
    expect(outbox.pendingCount(), 0);
    expect(engine.phase, SyncPhase.idle);
  });

  test('sin señal queda pendiente y reintenta solo al volver', () async {
    server.offline = true;
    put(1, 1, TechniqueResultStatus.pass);
    put(2, 1, TechniqueResultStatus.fail);
    engine.kick();
    await settle();
    expect(outbox.pendingCount(), 2);
    expect(engine.phase, SyncPhase.offline);
    expect(server.posts, isEmpty);

    server.offline = false;
    await settle(500); // espera el reintento automático
    expect(server.posts, hasLength(2));
    expect(outbox.pendingCount(), 0);
  });

  test('F manda FAIL=true; cambiarla a check manda FAIL=false', () async {
    put(1, 1, TechniqueResultStatus.totalFail);
    engine.kick();
    await settle();
    expect(server.posts.last.single['FAIL'], true);

    // El server no devuelve ID: el engine tendría que consultarlo. Simulamos
    // que ya se conoce.
    outbox.setResultId(outbox.get(7, 1, 1)!, 55);
    put(1, 1, TechniqueResultStatus.pass);
    engine.kick();
    await settle();
    expect(server.posts.last.single['FAIL'], false);
    expect(server.posts.last.single['ID'], 55);
  });

  test(
    'un check común no manda FAIL (no borra una F de otra técnica)',
    () async {
      put(1, 1, TechniqueResultStatus.totalFail);
      put(2, 1, TechniqueResultStatus.pass);
      engine.kick();
      await settle();
      expect(server.posts[1].single.containsKey('FAIL'), isFalse);
    },
  );

  test('un 401 pausa y conserva lo pendiente', () async {
    server.failWithStatus = 401;
    put(1, 1, TechniqueResultStatus.pass);
    engine.kick();
    await settle();
    expect(engine.phase, SyncPhase.authRequired);
    expect(outbox.pendingCount(), 1);
  });

  test('un 4xx rechaza solo ese resultado y sigue con los demás', () async {
    server.failWithStatus = 400;
    put(1, 1, TechniqueResultStatus.pass);
    engine.kick();
    await settle();
    expect(outbox.get(7, 1, 1)!.attempts, greaterThan(0));
    expect(engine.phase, SyncPhase.error);
    expect(outbox.lastErrorFor(7), 'Rejected (400)');
    expect(outbox.get(7, 1, 1)!.dirty, isTrue);
  });

  test(
    'si ya se había mandado sin confirmar, consulta el ID antes de reenviar',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://x'))
        ..httpClientAdapter = server;
      var fetched = 0;
      final e2 = ResultsSyncEngine(
        outbox: outbox,
        repository: ResultsSyncRepository(dio),
        fetchDetail: (_) async {
          fetched++;
          return TestDetail(
            id: 7,
            name: 't',
            status: 2,
            country: TestCountry(id: 1, name: 'c'),
            center: TestCenter(id: 1, name: 'c'),
            students: const [],
            techniques: const [],
            results: [
              ServerResult(
                techniqueId: 1,
                studentId: 1,
                resultId: 900,
                status: TechniqueResultStatus.pass,
              ),
            ],
          );
        },
        backoff: (_) => const Duration(milliseconds: 20),
        uploadWhileGrading: true,
      );
      put(1, 1, TechniqueResultStatus.fail);
      outbox.get(7, 1, 1)!.sent = true; // intento previo sin respuesta
      e2.kick();
      await settle();
      expect(fetched, 1);
      expect(server.posts.single.single['ID'], 900);
      e2.dispose();
    },
  );

  test('una edición durante el vuelo no se marca como sincronizada', () async {
    put(1, 1, TechniqueResultStatus.fail);
    final e = outbox.get(7, 1, 1)!;
    final v = e.version;
    put(1, 1, TechniqueResultStatus.pass);
    outbox.markSynced(e, v);
    expect(e.dirty, isTrue);
  });

  test(
    'cierre pedido sin señal: espera, y al volver sube resultados y cierra',
    () async {
      server.offline = true;
      put(1, 1, TechniqueResultStatus.pass);
      outbox.requestClose(7);
      engine.kick();
      await settle();
      expect(outbox.isCloseRequested(7), isTrue);
      expect(outbox.isClosed(7), isFalse);

      server.offline = false;
      await settle(500);
      expect(outbox.isClosed(7), isTrue);
      expect(outbox.isCloseRequested(7), isFalse);
      // Primero el resultado, después el cierre.
      expect(server.posts, hasLength(2));
      expect(server.posts.last, {'TestId': 7, 'lastRow': true});
      expect(server.paths, [
        '/api/sync/SyncStudentsResults',
        '/api/sync/SyncTestStatus',
      ]);
    },
  );

  test(
    'cancelar el cierre antes de que se sincronice evita mandarlo',
    () async {
      server.offline = true;
      outbox.requestClose(7);
      engine.kick();
      await settle();
      outbox.cancelClose(7);
      server.offline = false;
      await settle(500);
      expect(server.paths, isEmpty);
      expect(outbox.isClosed(7), isFalse);
    },
  );

  test('por defecto no sube nada mientras se califica; todo junto al cerrar',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = server;
    final e2 = ResultsSyncEngine(
      outbox: outbox,
      repository: ResultsSyncRepository(dio),
      fetchDetail: (_) async => throw UnimplementedError(),
      backoff: (_) => const Duration(milliseconds: 300),
    );
    put(1, 1, TechniqueResultStatus.pass);
    put(2, 1, TechniqueResultStatus.fail);
    put(3, 1, TechniqueResultStatus.pass);
    e2.kick();
    await settle();
    expect(server.paths, isEmpty, reason: 'sin End Test no se usa la red');
    expect(outbox.pendingCount(7), 3);

    outbox.requestClose(7);
    e2.kick();
    await settle(300);
    expect(server.paths.where((p) => p.endsWith('SyncStudentsResults')), hasLength(3));
    expect(server.paths.last, '/api/sync/SyncTestStatus');
    expect(outbox.isClosed(7), isTrue);
    e2.dispose();
  });
}
