import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import 'results_outbox.dart';
import 'results_repository.dart';
import 'test_detail_repository.dart';

/// Porteado de mS (main.js:37409+) — layout real confirmado contra una
/// captura de producción y el endpoint real `GET /api/getTestResults/{id}`
/// (probado en vivo con el test 10344, misma data que mostró el usuario):
/// "Results Higlights" con 3 cajas (Passed/Failed/Under Conditions) +
/// botón "End Test" (antes Sync Test), luego "Students Results" con sort "By Score" y la
/// lista de alumnos (puntaje, cantidad de mistakes).
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.test,
    this.engine,
    this.outbox,
  });

  final TestDetail test;
  final ResultsSyncEngine? engine;
  final ResultsOutbox? outbox;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _repository = ResultsRepository(ApiClient.instance.dio);
  TestResults? _results;
  String? _error;
  bool _byScore = false;
  ResultsSyncEngine get _engine => widget.engine ?? ResultsSyncEngine.instance;
  ResultsOutbox get _outbox => widget.outbox ?? ResultsOutbox.instance;
  bool _wasClosed = false;

  @override
  void initState() {
    super.initState();
    _wasClosed = _outbox.isClosed(widget.test.id);
    _outbox.addListener(_onSyncChanged);
    _engine.addListener(_onSyncChanged);
    _load();
  }

  @override
  void dispose() {
    _outbox.removeListener(_onSyncChanged);
    _engine.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() {
    if (!mounted) return;
    final closed = _outbox.isClosed(widget.test.id);
    if (closed && !_wasClosed) {
      _wasClosed = true;
      _load(); // el servidor ya cerró el test: refresca los resultados
    }
    setState(() {});
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await _repository.fetchTestResults(widget.test.id);
      setState(() => _results = results);
    } catch (e) {
      setState(() => _error = 'Could not load the results.');
    }
  }

  /// Pide cerrar el test. No espera al servidor: queda guardado en el
  /// teléfono y el motor de sincronización sube los resultados pendientes y
  /// después manda SyncTestStatus (lastRow=true), reintentando solo si no
  /// hay señal. Hasta que el servidor confirme se puede cancelar.
  Future<void> _endTest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Test'),
        content: const Text(
          'The results will be sent to the server and the test will be '
          'marked as finished. If there is no connection it will be sent '
          'automatically later, and grading will be locked until then. '
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            key: const Key('finish-test-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('END TEST'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    _outbox.requestClose(widget.test.id);
    _engine.kick();
  }

  void _cancelEnd() => _outbox.cancelClose(widget.test.id);

  String get _endStatusText {
    if (_outbox.pendingCount(widget.test.id) > 0) {
      return 'Uploading ${_outbox.pendingCount(widget.test.id)} results…';
    }
    return _engine.phase == SyncPhase.offline
        ? 'Waiting for connection…'
        : 'Ending test…';
  }

  Widget _endTestControl() {
    final id = widget.test.id;
    if (_outbox.isClosed(id) || widget.test.status == 3) {
      return const Text('Test ended', style: TextStyle(color: Colors.grey));
    }
    if (_outbox.isCloseRequested(id)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_endStatusText, style: const TextStyle(fontSize: 12)),
          TextButton(
            key: const Key('cancel-end-test'),
            onPressed: _cancelEnd,
            child: const Text('Cancel'),
          ),
        ],
      );
    }
    return FilledButton(
      key: const Key('finish-test'),
      onPressed: _endTest,
      child: const Text('End Test'),
    );
  }

  /// Todas las técnicas del test con el resultado del alumno en cada una.
  /// Sale de la cola local (que incluye lo ya guardado en el servidor y lo
  /// que todavía está por subir).
  List<Widget> _techniqueRows(int studentId) {
    final outbox = _outbox;
    return widget.test.techniques.map((t) {
      final r = outbox.get(widget.test.id, t.techniqueId, studentId)?.result;
      final String label;
      final Color color;
      switch (r?.status) {
        case TechniqueResultStatus.pass:
          label = 'Pass';
          color = const Color(0xFF13B72E);
        case TechniqueResultStatus.fail:
          label = 'Fail';
          color = const Color(0xFFB61317);
        case TechniqueResultStatus.totalFail:
          label = 'F';
          color = const Color(0xFFB61317);
        case null:
          label = 'Not graded';
          color = Colors.grey;
      }
      final mistake = r?.mistakeId == null
          ? null
          : t.mistakes.where((m) => m.id == r!.mistakeId).firstOrNull?.name;
      final detail = [
        if (mistake != null) mistake,
        if (r != null && r.freeText.isNotEmpty) r.freeText,
      ].join(' · ');
      return ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 56, right: 16),
        title: Text(
          '${t.code}  ${t.name}',
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: detail.isEmpty ? null : Text(detail),
        trailing: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.test.name)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    final results = _results;
    if (results == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final students = List.of(results.students);
    if (_byScore) {
      students.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    } else {
      students.sort((a, b) => a.shirtNum.compareTo(b.shirtNum));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          Container(
            color: Theme.of(context).colorScheme.primaryContainer,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.test.id} | ${DateFormat('dd MMM yyyy').format(DateTime.now())} | ${widget.test.country.name}',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  'Results Higlights',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                _endTestControl(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _StatBox(
                    value: results.totalPassed,
                    label: 'Passed',
                    color: const Color(0xFF13B72E),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(
                    value: results.totalFailed,
                    label: 'Failed',
                    color: const Color(0xFFB61317),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(
                    value: results.totalCondition,
                    label: 'Under Conditions',
                    color: const Color(0xFFE3A34C),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              children: [
                Text(
                  'Students Results',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => setState(() => _byScore = !_byScore),
                  child: const Text('By Score'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (students.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No results for this test.')),
            )
          else
            ...students.map(
              (student) => ExpansionTile(
                key: ValueKey('student-result-${student.studentId}'),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: Text(student.shirtNum.toString()),
                title: Row(
                  children: [
                    Text(
                      student.levelCode,
                      style: const TextStyle(color: Color(0xFFE3A34C)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(student.fullName)),
                  ],
                ),
                subtitle: Text('(${student.mistakeCount} Mistakes)'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      student.totalPoints.toStringAsFixed(0),
                      style: const TextStyle(
                        color: Color(0xFF13B72E),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.add),
                  ],
                ),
                children: _techniqueRows(student.studentId),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
