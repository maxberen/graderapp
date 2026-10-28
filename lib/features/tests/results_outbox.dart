import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/network/api_client.dart';
import 'results_sync_repository.dart';
import 'test_detail_repository.dart';

/// Un resultado (alumno + técnica) tal como está en el teléfono, y si el
/// servidor ya lo tiene.
class OutboxEntry {
  OutboxEntry({
    required this.testId,
    required this.techniqueId,
    required this.studentId,
    required this.testStudentId,
    required this.result,
    this.resultId,
    this.dirty = true,
    this.sent = false,
    this.attempts = 0,
    this.lastError,
    this.touchesHardFail = false,
    this.version = 1,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final int testId;
  final int techniqueId;
  final int studentId;
  final int testStudentId;
  GradedResult result;

  /// ID del resultado en el servidor, si se conoce (para actualizar en vez de
  /// insertar).
  int? resultId;

  /// Hay cambios locales que el servidor todavía no confirmó.
  bool dirty;

  /// Ya se intentó mandar alguna vez. Si no hay [resultId], puede que el
  /// servidor igual lo haya insertado (el pedido pudo llegar y perderse la
  /// respuesta) — antes de reenviar hay que averiguarlo.
  bool sent;

  int attempts;
  String? lastError;

  /// Este cambio toca una F: al subirlo hay que mandar la bandera FAIL del
  /// alumno (ver ResultsSyncRepository).
  bool touchesHardFail;

  /// Se incrementa en cada edición local, para no marcar como sincronizada
  /// una edición que ocurrió mientras el pedido anterior estaba en vuelo.
  int version;
  DateTime updatedAt;

  String get key => ResultsOutbox.keyOf(testId, techniqueId, studentId);

  Map<String, dynamic> toJson() => {
    'testId': testId,
    'techniqueId': techniqueId,
    'studentId': studentId,
    'testStudentId': testStudentId,
    'result': result.toJson(),
    'resultId': resultId,
    'dirty': dirty,
    'sent': sent,
    'attempts': attempts,
    'lastError': lastError,
    'touchesHardFail': touchesHardFail,
    'version': version,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory OutboxEntry.fromJson(Map<String, dynamic> json) => OutboxEntry(
    testId: json['testId'] as int,
    techniqueId: json['techniqueId'] as int,
    studentId: json['studentId'] as int,
    testStudentId: json['testStudentId'] as int,
    result: GradedResult.fromJson(json['result'] as Map<String, dynamic>),
    resultId: json['resultId'] as int?,
    dirty: json['dirty'] as bool? ?? true,
    sent: json['sent'] as bool? ?? false,
    attempts: json['attempts'] as int? ?? 0,
    lastError: json['lastError'] as String?,
    touchesHardFail: json['touchesHardFail'] as bool? ?? false,
    version: json['version'] as int? ?? 1,
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
  );
}

/// Resultados calificados, guardados primero en el teléfono (archivo JSON,
/// escritura atómica) y subidos al servidor en segundo plano por
/// [ResultsSyncEngine]. Es la fuente de verdad de la pantalla de calificación:
/// sin señal se sigue calificando, y lo pendiente sobrevive a cerrar la app.
class ResultsOutbox extends ChangeNotifier {
  /// [file] nulo = solo en memoria (pruebas).
  ResultsOutbox({File? file}) : _file = file;

  static final ResultsOutbox instance = ResultsOutbox();

  File? _file;
  final Map<String, OutboxEntry> _entries = {};

  /// Tests cuyo cierre (End Test) fue pedido y todavía no lo confirmó el
  /// servidor, y tests ya cerrados. Se guardan junto con los resultados.
  final Set<int> _closeRequested = {};
  final Set<int> _closed = {};
  Future<void> _writing = Future.value();

  static String keyOf(int testId, int techniqueId, int studentId) =>
      '$testId:$techniqueId:$studentId';

  /// Carga el archivo en disco (si no se pasó uno en el constructor, usa el
  /// directorio de soporte de la app). Se llama una vez al arrancar.
  Future<void> load() async {
    try {
      _file ??= File(
        p.join(
          (await getApplicationSupportDirectory()).path,
          'results_outbox.json',
        ),
      );
      if (!await _file!.exists()) return;
      final raw = jsonDecode(await _file!.readAsString());
      _closeRequested.addAll(
        (raw['closeRequested'] as List? ?? const []).cast<int>(),
      );
      _closed.addAll((raw['closed'] as List? ?? const []).cast<int>());
      for (final item in (raw['entries'] as List? ?? const [])) {
        final e = OutboxEntry.fromJson(item as Map<String, dynamic>);
        _entries[e.key] = e;
      }
      _pruneSynced();
      notifyListeners();
    } catch (e) {
      debugPrint('ResultsOutbox.load: $e');
    }
  }

  OutboxEntry? get(int testId, int techniqueId, int studentId) =>
      _entries[keyOf(testId, techniqueId, studentId)];

  Iterable<OutboxEntry> forTest(int testId) =>
      _entries.values.where((e) => e.testId == testId);

  int pendingCount([int? testId]) => _entries.values
      .where((e) => e.dirty && (testId == null || e.testId == testId))
      .length;

  bool isCloseRequested(int testId) => _closeRequested.contains(testId);
  bool isClosed(int testId) => _closed.contains(testId);
  Set<int> get closeRequests => Set.of(_closeRequested);

  /// Pide cerrar el test: el motor lo manda al servidor apenas no quede nada
  /// pendiente de ese test, reintentando hasta que confirme. Mientras tanto
  /// el test no se puede seguir calificando.
  void requestClose(int testId) {
    if (_closed.contains(testId)) return;
    _closeRequested.add(testId);
    _changed();
  }

  /// Cancela un cierre que el servidor todavía no confirmó.
  void cancelClose(int testId) {
    if (_closeRequested.remove(testId)) _changed();
  }

  void markClosed(int testId) {
    _closeRequested.remove(testId);
    _closed.add(testId);
    _changed();
  }

  /// ¿El alumno tiene alguna F en este test?
  bool hasTotalFail(int testId, int studentId) => _entries.values.any(
    (e) =>
        e.testId == testId &&
        e.studentId == studentId &&
        e.result.status == TechniqueResultStatus.totalFail,
  );

  /// Siguiente entrada pendiente (la más vieja primero), salteando [skip].
  OutboxEntry? nextDirty({Set<String> skip = const {}}) {
    OutboxEntry? best;
    for (final e in _entries.values) {
      if (!e.dirty || skip.contains(e.key)) continue;
      if (best == null || e.updatedAt.isBefore(best.updatedAt)) best = e;
    }
    return best;
  }

  /// Registra una calificación local. Queda pendiente de subir.
  void put({
    required int testId,
    required int techniqueId,
    required int studentId,
    required int testStudentId,
    required GradedResult result,
  }) {
    final existing = get(testId, techniqueId, studentId);
    final touchesF =
        existing?.result.status == TechniqueResultStatus.totalFail ||
        result.status == TechniqueResultStatus.totalFail;
    if (existing == null) {
      final e = OutboxEntry(
        testId: testId,
        techniqueId: techniqueId,
        studentId: studentId,
        testStudentId: testStudentId,
        result: result,
        touchesHardFail: touchesF,
      );
      _entries[e.key] = e;
    } else {
      existing
        ..result = result
        ..dirty = true
        ..attempts = 0
        ..lastError = null
        ..touchesHardFail = existing.touchesHardFail || touchesF
        ..version += 1
        ..updatedAt = DateTime.now();
    }
    _changed();
  }

  /// Incorpora lo que ya tiene el servidor. No pisa cambios locales pendientes.
  void seedFromServer(
    int testId,
    List<ServerResult> results,
    Map<int, int> testStudentIds,
  ) {
    var changed = false;
    for (final r in results) {
      final key = keyOf(testId, r.techniqueId, r.studentId);
      final existing = _entries[key];
      if (existing != null && existing.dirty) {
        if (existing.resultId == null && r.resultId != null) {
          existing.resultId = r.resultId;
          changed = true;
        }
        continue;
      }
      _entries[key] = OutboxEntry(
        testId: testId,
        techniqueId: r.techniqueId,
        studentId: r.studentId,
        testStudentId: testStudentIds[r.studentId] ?? r.studentId,
        result: GradedResult(
          status: r.status,
          mistakeId: r.mistakeId,
          freeText: r.freeText,
        ),
        resultId: r.resultId,
        dirty: false,
        sent: r.resultId != null,
      );
      changed = true;
    }
    if (changed) _changed();
  }

  void markSending(OutboxEntry e) {
    if (e.sent) return;
    e.sent = true;
    _changed(notify: false);
  }

  void setResultId(OutboxEntry e, int id) {
    e.resultId = id;
    _changed(notify: false);
  }

  /// El servidor confirmó [version]. Si mientras tanto se editó, sigue
  /// pendiente con lo nuevo.
  void markSynced(OutboxEntry e, int version) {
    if (e.version == version) {
      e.dirty = false;
      e.attempts = 0;
      e.lastError = null;
      e.touchesHardFail = false;
    }
    _changed();
  }

  void markFailed(OutboxEntry e, String error, {required bool countAttempt}) {
    if (countAttempt) e.attempts += 1;
    e.lastError = error;
    _changed();
  }

  void _pruneSynced() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    _entries.removeWhere((_, e) => !e.dirty && e.updatedAt.isBefore(cutoff));
  }

  void _changed({bool notify = true}) {
    _persist();
    if (notify) notifyListeners();
  }

  void _persist() {
    final file = _file;
    if (file == null) return;
    final payload = jsonEncode({
      'entries': _entries.values.map((e) => e.toJson()).toList(),
      'closeRequested': _closeRequested.toList(),
      'closed': _closed.toList(),
    });
    _writing = _writing.then((_) async {
      try {
        final tmp = File('${file.path}.tmp');
        await file.parent.create(recursive: true);
        await tmp.writeAsString(payload, flush: true);
        await tmp.rename(file.path);
      } catch (e) {
        debugPrint('ResultsOutbox.persist: $e');
      }
    });
  }

  /// Para pruebas: espera a que terminen las escrituras a disco.
  @visibleForTesting
  Future<void> flushWrites() => _writing;
}

enum SyncPhase { idle, syncing, offline, authRequired }

/// Sube en segundo plano lo pendiente de [ResultsOutbox]. Se dispara al
/// calificar, al abrir/volver a la app y por reintentos con espera creciente.
/// No usa un plugin de conectividad: intentar y fallar por red ES la señal, y
/// el reintento periódico más el aviso de "app en primer plano" cubren la
/// vuelta de la señal.
class ResultsSyncEngine extends ChangeNotifier with WidgetsBindingObserver {
  ResultsSyncEngine({
    required this.outbox,
    required this.repository,
    required this.fetchDetail,
    this.backoff = defaultBackoff,
  });

  static final ResultsSyncEngine instance = ResultsSyncEngine(
    outbox: ResultsOutbox.instance,
    repository: ResultsSyncRepository(ApiClient.instance.dio),
    fetchDetail: TestDetailRepository(ApiClient.instance.dio).fetchTestDetail,
  );

  final ResultsOutbox outbox;
  final ResultsSyncRepository repository;
  final Future<TestDetail> Function(int testId) fetchDetail;
  final Duration Function(int failures) backoff;

  /// 5s, 10s, 20s, 40s, luego 60s.
  static Duration defaultBackoff(int failures) {
    final seconds = 5 * (1 << (failures - 1).clamp(0, 4));
    return Duration(seconds: seconds > 60 ? 60 : seconds);
  }

  SyncPhase _phase = SyncPhase.idle;
  SyncPhase get phase => _phase;

  bool _running = false;
  bool _again = false;
  bool _started = false;
  int _failures = 0;
  Timer? _timer;

  /// Carga la cola del disco y arranca. Llamar una vez desde main().
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await outbox.load();
    WidgetsBinding.instance.addObserver(this);
    kick();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) kick();
  }

  /// Pide una pasada de sincronización ya (cancela la espera de reintento).
  void kick() {
    _timer?.cancel();
    if (_running) {
      _again = true;
      return;
    }
    unawaited(_run());
  }

  void _setPhase(SyncPhase p) {
    if (_phase == p) return;
    _phase = p;
    notifyListeners();
  }

  Future<void> _run() async {
    _running = true;
    try {
      do {
        _again = false;
        final ok = await _drain();
        if (!ok) return;
      } while (_again);
      if (outbox.pendingCount() > 0 || outbox.closeRequests.isNotEmpty) {
        _scheduleRetry();
      } else {
        _failures = 0;
        _setPhase(SyncPhase.idle);
      }
    } finally {
      _running = false;
    }
  }

  /// Devuelve false si hay que cortar (sin red / sin sesión); ya dejó
  /// programado el reintento.
  Future<bool> _drain() async {
    final skip = <String>{};
    final knownIds = <int, Map<String, int>>{};
    while (true) {
      final e = outbox.nextDirty(skip: skip);
      if (e == null) return _sendCloses();
      _setPhase(SyncPhase.syncing);
      final version = e.version;
      final wasSent = e.sent;
      try {
        await _upload(e, knownIds);
        outbox.markSynced(e, version);
        _failures = 0;
      } on DioException catch (d) {
        final status = d.response?.statusCode;
        // Si ni siquiera se pudo conectar, el servidor no recibió nada: no
        // hace falta averiguar después si quedó insertado.
        if (d.type == DioExceptionType.connectionError) e.sent = wasSent;
        if (status == 401) {
          outbox.markFailed(e, 'Session expired', countAttempt: false);
          _setPhase(SyncPhase.authRequired);
          _scheduleRetry();
          return false;
        }
        if (status == null || status == 408 || status == 429 || status >= 500) {
          // Sin señal, timeout o servidor caído: se corta y se reintenta.
          // Con 5xx igual se cuenta como error del servidor, no de red, pero
          // el tratamiento es el mismo: no tiene sentido seguir con el resto.
          outbox.markFailed(
            e,
            status == null ? 'No connection' : 'Server error ($status)',
            countAttempt: status != null,
          );
          _setPhase(status == null ? SyncPhase.offline : SyncPhase.syncing);
          _scheduleRetry();
          return false;
        }
        // 4xx: el servidor rechazó ESTE resultado; se sigue con los demás.
        outbox.markFailed(e, 'Rejected ($status)', countAttempt: true);
        skip.add(e.key);
      } catch (err) {
        outbox.markFailed(e, '$err', countAttempt: true);
        skip.add(e.key);
      }
    }
  }

  /// Manda el cierre de los tests que lo pidieron y ya no tienen nada
  /// pendiente. Mismo criterio de errores que los resultados. Devuelve false
  /// si hay que cortar (ya quedó programado el reintento).
  Future<bool> _sendCloses() async {
    for (final testId in outbox.closeRequests) {
      // Con resultados rechazados todavía en cola no se cierra: el servidor
      // lo marcaría finalizado con resultados incompletos.
      if (outbox.pendingCount(testId) > 0) continue;
      _setPhase(SyncPhase.syncing);
      try {
        await repository.finishTest(testId);
        outbox.markClosed(testId);
        _failures = 0;
      } on DioException catch (d) {
        final status = d.response?.statusCode;
        if (status == 401) {
          _setPhase(SyncPhase.authRequired);
          _scheduleRetry();
          return false;
        }
        if (status == null || status == 408 || status == 429 || status >= 500) {
          _setPhase(status == null ? SyncPhase.offline : SyncPhase.syncing);
          _scheduleRetry();
          return false;
        }
        // 4xx: el servidor rechazó el cierre; queda pedido y se reintenta
        // con espera creciente (la pasada termina con reintento programado).
      } catch (_) {}
    }
    return true;
  }

  Future<void> _upload(
    OutboxEntry e,
    Map<int, Map<String, int>> knownIds,
  ) async {
    var resultId = e.resultId;
    if (resultId == null && e.sent) {
      // Ya se intentó antes sin confirmación: puede estar insertado. El
      // servidor no devuelve el ID al insertar, así que se pregunta una vez
      // por pasada y por test.
      final ids = knownIds[e.testId] ??= await _fetchIds(e.testId);
      resultId = ids[e.key];
      if (resultId != null) outbox.setResultId(e, resultId);
    }
    outbox.markSending(e);
    await repository.saveResult(
      testId: e.testId,
      testStudentId: e.testStudentId,
      techniqueId: e.techniqueId,
      result: e.result,
      resultId: resultId,
      studentHardFail: e.touchesHardFail
          ? outbox.hasTotalFail(e.testId, e.studentId)
          : null,
    );
    // El ID del insert recién hecho no se conoce hasta la próxima consulta:
    // si se vuelve a editar, `sent` sin `resultId` dispara esa consulta.
    knownIds.remove(e.testId);
  }

  Future<Map<String, int>> _fetchIds(int testId) async {
    final detail = await fetchDetail(testId);
    return {
      for (final r in detail.results)
        if (r.resultId != null)
          ResultsOutbox.keyOf(testId, r.techniqueId, r.studentId): r.resultId!,
    };
  }

  void _scheduleRetry() {
    _failures += 1;
    _timer?.cancel();
    _timer = Timer(backoff(_failures), kick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
