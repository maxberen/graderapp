import 'package:flutter/material.dart';

import 'results_outbox.dart';
import 'results_screen.dart';
import 'results_sync_repository.dart';
import 'technique_video_player.dart';
import 'test_detail_repository.dart';
import 'test_session_timer.dart';

/// Porteado de jz (main.js:41065+) y el modal km-result-picker (cz,
/// main.js:38433-38613): wizard que muestra UNA técnica a la vez con el
/// contador "N/Total", código, puntaje y descripción; lista de alumnos
/// presentes debajo; tocar un alumno abre un selector con 3 botones
/// (check / X / F).
///
/// Sin botón SAVE general:
///  - Check: se guarda al toque.
///  - X o F: muestra los errores predeterminados de la técnica; tocar uno lo
///    guarda al toque. También hay un campo de texto libre, que es lo único
///    con botón SAVE. X y F se comportan igual en este selector; la
///    diferencia es que F además marca al alumno con reprobación total del
///    examen (ver ResultsSyncRepository).
///
/// "Guardar" es local primero, igual que el original: cada selección va a la
/// cola persistente [ResultsOutbox] y [ResultsSyncEngine] la sube al servidor
/// en segundo plano, reintentando solo si no hay señal. La pantalla siempre
/// muestra lo que hay en la cola, así que funciona sin conexión.
///
/// Pendiente (no portado todavía): grabación/reproducción de video de la
/// técnica, foto por resultado, y el cierre del test (SyncTestStatus y envío
/// de emails a los alumnos).
class TestGradingScreen extends StatefulWidget {
  const TestGradingScreen({
    super.key,
    required this.test,
    this.outbox,
    this.engine,
  });

  final TestDetail test;

  /// Inyectables para pruebas. Por defecto, los de la app.
  final ResultsOutbox? outbox;
  final ResultsSyncEngine? engine;

  @override
  State<TestGradingScreen> createState() => _TestGradingScreenState();
}

class _TestGradingScreenState extends State<TestGradingScreen> {
  late final List<TestStudent> _presentStudents;
  late final ResultsOutbox _outbox;
  late final ResultsSyncEngine _engine;
  int _techniqueIndex = 0;
  bool _showTimer = false;

  @override
  void initState() {
    super.initState();
    _presentStudents = widget.test.students.where((s) => s.present).toList();
    _outbox = widget.outbox ?? ResultsOutbox.instance;
    _engine = widget.engine ?? ResultsSyncEngine.instance;
    _outbox.seedFromServer(widget.test.id, widget.test.results, {
      for (final s in widget.test.students) s.id: s.testStudentId,
    });
    _outbox.addListener(_onChanged);
    _engine.addListener(_onChanged);
  }

  @override
  void dispose() {
    _outbox.removeListener(_onChanged);
    _engine.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  TestTechnique get _technique => widget.test.techniques[_techniqueIndex];

  OutboxEntry? _entryFor(int studentId) =>
      _outbox.get(widget.test.id, _technique.techniqueId, studentId);

  GradedResult? _resultFor(int studentId) => _entryFor(studentId)?.result;

  Future<void> _openResultPicker(TestStudent student) async {
    if (_outbox.isCloseRequested(widget.test.id) ||
        _outbox.isClosed(widget.test.id)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'End Test was requested, grading is locked. '
              'Open Results and tap Cancel to keep grading.',
            ),
          ),
        );
      return;
    }
    final technique = _technique;
    final result = await showModalBottomSheet<GradedResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ResultPickerSheet(
        student: student,
        technique: technique,
        initial: _outbox
            .get(widget.test.id, technique.techniqueId, student.id)
            ?.result,
      ),
    );
    if (result == null) return;
    _outbox.put(
      testId: widget.test.id,
      techniqueId: technique.techniqueId,
      studentId: student.id,
      testStudentId: student.testStudentId,
      result: result,
    );
    // No se sube nada ahora: todo se envía junto al tocar End Test.
  }

  void _next() {
    final missing = _presentStudents
        .where((s) => _resultFor(s.id) == null)
        .isNotEmpty;
    if (missing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all student's results first!"),
        ),
      );
      return;
    }
    if (_isLastTechnique) {
      _showResults();
    } else {
      setState(() => _techniqueIndex++);
    }
  }

  bool get _isLastTechnique =>
      _techniqueIndex >= widget.test.techniques.length - 1;

  void _previous() {
    if (_techniqueIndex > 0) setState(() => _techniqueIndex--);
  }

  Future<void> _showResults() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ResultsScreen(test: widget.test)));
  }

  @override
  Widget build(BuildContext context) {
    final technique = _technique;
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              color: const Color(0xFF030200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.test.name,
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Stack(
            children: [
              TechniqueVideoPlayer(techniqueCode: technique.code),
              Positioned(
                left: 12,
                top: 8,
                child: Text(
                  '${_techniqueIndex + 1}/${widget.test.techniques.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 8,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              technique.code,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${technique.score}%',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          technique.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_showTimer)
            TestSessionTimer(onClose: () => setState(() => _showTimer = false)),
          Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _showResults,
                    child: const Text('Results'),
                  ),
                  const SizedBox(width: 12),
                  _SyncStatus(
                    pending: _outbox.pendingCount(widget.test.id),
                    closing: _outbox.isCloseRequested(widget.test.id),
                    phase: _engine.phase,
                    error: _outbox.lastErrorFor(widget.test.id),
                    onRetry: _engine.kick,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.timer_outlined),
                    onPressed: () => setState(() => _showTimer = !_showTimer),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _presentStudents.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final student = _presentStudents[index];
                final result = _resultFor(student.id);
                return ListTile(
                  key: ValueKey('student-${student.id}'),
                  leading: CircleAvatar(
                    backgroundColor: _colorFor(result?.status),
                    child: Text(
                      student.num.toString().padLeft(2, '0'),
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ),
                  title: Text(student.fullName),
                  subtitle: Text(student.levelCode),
                  trailing: _trailingFor(student, result),
                  onTap: () => _openResultPicker(student),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _techniqueIndex == 0 ? null : _previous,
                      child: const Text('PREVIOUS'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('next-or-results'),
                      onPressed: _next,
                      child: Text(_isLastTechnique ? 'RESULTS' : 'NEXT'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trailingFor(TestStudent student, GradedResult? result) {
    final entry = _entryFor(student.id);
    final icon = _resultIconFor(result?.status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (entry != null && entry.dirty)
          Tooltip(
            message: entry.lastError ?? 'Waiting to upload',
            child: Icon(
              entry.lastError == null
                  ? Icons.cloud_upload_outlined
                  : Icons.sync_problem,
              size: 18,
              color: entry.lastError == null ? Colors.grey : Colors.orange,
            ),
          ),
        if (icon != null) ...[const SizedBox(width: 8), icon],
      ],
    );
  }

  Color _colorFor(TechniqueResultStatus? status) {
    switch (status) {
      case TechniqueResultStatus.pass:
        return const Color(0xFF13B72E);
      case TechniqueResultStatus.fail:
      case TechniqueResultStatus.totalFail:
        return const Color(0xFFB61317);
      case null:
        return const Color(0xFFECECEC);
    }
  }

  Widget? _resultIconFor(TechniqueResultStatus? status) {
    switch (status) {
      case TechniqueResultStatus.pass:
        return const Icon(Icons.check, color: Color(0xFF13B72E));
      case TechniqueResultStatus.fail:
        return const Icon(Icons.close, color: Color(0xFFB61317));
      case TechniqueResultStatus.totalFail:
        return const Text(
          'F',
          style: TextStyle(
            color: Color(0xFFB61317),
            fontWeight: FontWeight.bold,
          ),
        );
      case null:
        return null;
    }
  }
}

/// Selector de resultado de un alumno en una técnica (porteo del modal
/// km-result-picker, cz, main.js:38433-38613) con el flujo nuevo, sin SAVE
/// general: devuelve el [GradedResult] apenas hay algo que guardar.
class _ResultPickerSheet extends StatefulWidget {
  const _ResultPickerSheet({
    required this.student,
    required this.technique,
    required this.initial,
  });

  final TestStudent student;
  final TestTechnique technique;
  final GradedResult? initial;

  @override
  State<_ResultPickerSheet> createState() => _ResultPickerSheetState();
}

class _ResultPickerSheetState extends State<_ResultPickerSheet> {
  late TechniqueResultStatus? _status = widget.initial?.status;
  late final int? _initialMistakeId =
      (widget.initial == null || widget.initial!.isPass)
      ? null
      : widget.initial!.mistakeId;
  late final TextEditingController _text = TextEditingController(
    text: (widget.initial == null || widget.initial!.isPass)
        ? ''
        : widget.initial!.freeText,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// X y F muestran lo mismo: los errores predeterminados y el texto libre.
  bool get _showDetail =>
      _status == TechniqueResultStatus.fail ||
      _status == TechniqueResultStatus.totalFail;

  bool get _hasMistakes => widget.technique.mistakes.isNotEmpty;

  /// Con errores predeterminados disponibles, el texto libre solo se puede
  /// guardar si tiene contenido (si no, hay que tocar un error). Sin errores
  /// configurados, es la única forma de registrar la falla, así que puede
  /// guardarse vacío.
  bool get _canSaveText => _text.text.trim().isNotEmpty || !_hasMistakes;

  void _finish(GradedResult result) => Navigator.of(context).pop(result);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.student.num.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.student.levelCode,
                    style: const TextStyle(
                      color: Color(0xFFE3A34C),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.student.fullName,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ChoiceButton(
                      key: const Key('result-pass'),
                      color: const Color(0xFF13B72E),
                      selected: _status == TechniqueResultStatus.pass,
                      child: const Icon(Icons.check, color: Colors.white),
                      onTap: () => _finish(
                        const GradedResult(status: TechniqueResultStatus.pass),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ChoiceButton(
                      key: const Key('result-fail'),
                      color: const Color(0xFFB61317),
                      selected: _status == TechniqueResultStatus.fail,
                      child: const Icon(Icons.close, color: Colors.white),
                      onTap: () =>
                          setState(() => _status = TechniqueResultStatus.fail),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ChoiceButton(
                      key: const Key('result-total-fail'),
                      color: const Color(0xFFB61317),
                      selected: _status == TechniqueResultStatus.totalFail,
                      child: const Text(
                        'F',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      onTap: () => setState(
                        () => _status = TechniqueResultStatus.totalFail,
                      ),
                    ),
                  ),
                ],
              ),
              if (_showDetail) ...[
                const SizedBox(height: 16),
                if (_hasMistakes) ...[
                  const Text('Choose mistake:', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.technique.mistakes.map((m) {
                      return ChoiceChip(
                        key: Key('mistake-${m.id}'),
                        label: Text(m.name),
                        selected: _initialMistakeId == m.id,
                        // Un toque y se guarda: sin botón SAVE.
                        onSelected: (_) => _finish(
                          GradedResult(
                            status: _status!,
                            mistakeId: m.id,
                            freeText: _text.text.trim(),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ] else
                  const Text(
                    'This technique has no mistakes configured.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('free-text'),
                  controller: _text,
                  minLines: 1,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Free text',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    key: const Key('free-text-save'),
                    onPressed: _canSaveText
                        ? () => _finish(
                            GradedResult(
                              status: _status!,
                              mistakeId: _initialMistakeId,
                              freeText: _text.text.trim(),
                            ),
                          )
                        : null,
                    child: const Text('SAVE'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    super.key,
    required this.color,
    required this.selected,
    required this.child,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 47,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(5),
          border: selected
              ? Border.all(color: Colors.orange, width: 1.5)
              : null,
        ),
        child: child,
      ),
    );
  }
}

/// Estado de la subida al servidor del test abierto.
class _SyncStatus extends StatelessWidget {
  const _SyncStatus({
    required this.pending,
    required this.closing,
    required this.phase,
    required this.error,
    required this.onRetry,
  });

  final int pending;
  final bool closing;
  final SyncPhase phase;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final String text;
    final IconData icon;
    final Color color;
    if (pending == 0) {
      text = 'All saved';
      icon = Icons.cloud_done_outlined;
      color = Colors.grey;
    } else if (!closing) {
      // Durante la prueba no se sube nada: se envía al tocar End Test.
      text = '$pending saved on this phone';
      icon = Icons.save_outlined;
      color = Colors.grey;
    } else if (phase == SyncPhase.authRequired) {
      text = '$pending not uploaded: log in again';
      icon = Icons.lock_outline;
      color = Colors.orange;
    } else if (phase == SyncPhase.offline) {
      text = '$pending not uploaded: no connection';
      icon = Icons.cloud_off_outlined;
      color = Colors.orange;
    } else if (phase == SyncPhase.error) {
      text = '$pending not uploaded: ${error ?? 'server error'} — retrying';
      icon = Icons.sync_problem;
      color = Colors.orange;
    } else {
      text = 'Uploading $pending…';
      icon = Icons.cloud_upload_outlined;
      color = Colors.grey;
    }
    return InkWell(
      key: const Key('sync-status'),
      onTap: pending == 0 || !closing ? null : onRetry,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
