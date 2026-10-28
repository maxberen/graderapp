import 'package:flutter/material.dart';

import 'results_screen.dart';
import 'technique_video_player.dart';
import 'test_detail_repository.dart';
import 'test_session_timer.dart';

/// Porteado de jz (main.js:41065+) y el modal km-result-picker (cz,
/// main.js:38433-38613) — confirmado contra una captura real de producción
/// 2026-10-25: wizard que muestra UNA técnica a la vez con el contador
/// "N/Total", código, puntaje y descripción; lista de alumnos presentes
/// debajo; tocar un alumno abre un modal con 3 botones (Pass verde /
/// Mistake rojo / Total Fail "F" rojo) y, si no es Pass, un selector de
/// "mistake" real del curriculum antes de poder guardar.
///
/// Pendiente (no portado todavía, documentado para no fingir que está
/// completo): grabación/reproducción de video de la técnica, foto por
/// resultado, y sincronización de los resultados al servidor — todo queda
/// en memoria local de esta pantalla por ahora.
class TestGradingScreen extends StatefulWidget {
  const TestGradingScreen({super.key, required this.test});

  final TestDetail test;

  @override
  State<TestGradingScreen> createState() => _TestGradingScreenState();
}

class _TestGradingScreenState extends State<TestGradingScreen> {
  late final List<TestStudent> _presentStudents;
  int _techniqueIndex = 0;
  bool _showTimer = false;

  /// techniqueId -> studentId -> resultado elegido en esta sesión.
  final Map<int, Map<int, TechniqueResultStatus>> _results = {};

  @override
  void initState() {
    super.initState();
    _presentStudents = widget.test.students.where((s) => s.present).toList();
  }

  TestTechnique get _technique => widget.test.techniques[_techniqueIndex];

  TechniqueResultStatus? _resultFor(int studentId) =>
      _results[_technique.techniqueId]?[studentId];

  void _setResult(int studentId, TechniqueResultStatus status) {
    setState(() {
      _results.putIfAbsent(_technique.techniqueId, () => {})[studentId] =
          status;
    });
  }

  Future<void> _openResultPicker(TestStudent student) async {
    final current = _resultFor(student.id);
    final result = await showModalBottomSheet<TechniqueResultStatus>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ResultPickerSheet(
        student: student,
        technique: _technique,
        initial: current,
      ),
    );
    if (result != null) _setResult(student.id, result);
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
    if (_techniqueIndex < widget.test.techniques.length - 1) {
      setState(() => _techniqueIndex++);
    }
  }

  void _previous() {
    if (_techniqueIndex > 0) setState(() => _techniqueIndex--);
  }

  Future<void> _showResults() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResultsScreen(test: widget.test)),
    );
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
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
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
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                        Text(
                          technique.name,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_showTimer) TestSessionTimer(onClose: () => setState(() => _showTimer = false)),
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
                  leading: CircleAvatar(
                    backgroundColor: _colorFor(result),
                    child: Text(
                      student.num.toString().padLeft(2, '0'),
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ),
                  title: Text(student.fullName),
                  subtitle: Text(student.levelCode),
                  trailing: _resultIconFor(result),
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
                      child: const Text('ANTERIOR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _next,
                      child: const Text('SIGUIENTE'),
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
        return const Text('F', style: TextStyle(color: Color(0xFFB61317), fontWeight: FontWeight.bold));
      case null:
        return null;
    }
  }
}

/// Porteado del modal km-result-picker (cz, main.js:38433-38613).
class _ResultPickerSheet extends StatefulWidget {
  const _ResultPickerSheet({
    required this.student,
    required this.technique,
    required this.initial,
  });

  final TestStudent student;
  final TestTechnique technique;
  final TechniqueResultStatus? initial;

  @override
  State<_ResultPickerSheet> createState() => _ResultPickerSheetState();
}

class _ResultPickerSheetState extends State<_ResultPickerSheet> {
  late TechniqueResultStatus _status =
      widget.initial ?? TechniqueResultStatus.pass;
  int? _selectedMistakeId;

  @override
  void initState() {
    super.initState();
    if (widget.technique.mistakes.isNotEmpty) {
      _selectedMistakeId = widget.technique.mistakes.first.id;
    }
  }

  bool get _needsMistake => _status != TechniqueResultStatus.pass;

  bool get _canSave =>
      !_needsMistake ||
      widget.technique.mistakes.isEmpty ||
      _selectedMistakeId != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.student.num.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.student.levelCode,
                    style: const TextStyle(color: Color(0xFFE3A34C), fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.student.fullName, style: const TextStyle(fontSize: 16)),
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
                      color: const Color(0xFF13B72E),
                      selected: _status == TechniqueResultStatus.pass,
                      child: const Icon(Icons.check, color: Colors.white),
                      onTap: () => setState(() => _status = TechniqueResultStatus.pass),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ChoiceButton(
                      color: const Color(0xFFB61317),
                      selected: _status == TechniqueResultStatus.fail,
                      child: const Icon(Icons.close, color: Colors.white),
                      onTap: () => setState(() => _status = TechniqueResultStatus.fail),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ChoiceButton(
                      color: const Color(0xFFB61317),
                      selected: _status == TechniqueResultStatus.totalFail,
                      child: const Text('F', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                      onTap: () => setState(() => _status = TechniqueResultStatus.totalFail),
                    ),
                  ),
                ],
              ),
              if (_needsMistake) ...[
                const SizedBox(height: 16),
                const Text('Choose mistake:', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                if (widget.technique.mistakes.isEmpty)
                  const Text(
                    'Este test no tiene mistakes configurados para esta técnica.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.technique.mistakes.map((m) {
                      return ChoiceChip(
                        label: Text(m.name),
                        selected: _selectedMistakeId == m.id,
                        onSelected: (_) => setState(() => _selectedMistakeId = m.id),
                      );
                    }).toList(),
                  ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSave
                      ? () => Navigator.of(context).pop(_status)
                      : null,
                  child: const Text('SAVE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
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
          border: selected ? Border.all(color: Colors.orange, width: 1.5) : null,
        ),
        child: child,
      ),
    );
  }
}
