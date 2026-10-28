import 'package:flutter/material.dart';

import '../../core/widgets/compact_toolbar_style.dart';
import 'groups_list_screen.dart';
import 'qr_scan_screen.dart';
import 'test_detail_repository.dart';
import 'test_grading_screen.dart';

/// Porteado de CU (main.js:45407-45689) — pantalla "Students" que se abre
/// para un test Opened (status 1): marcar presentes/ausentes antes de
/// arrancar a calificar. Header con foto de fondo, "Test ID {id}  |
/// {centro}, {país}", toolbar (By Alphabet / Add Group / Add Student; Add Student escanea QR por defecto),
/// lista de alumnos con check verde si están presentes, o el estado vacío
/// real ("No Students Here...") cuando no hay alumnos cargados — igual al
/// que mostró el usuario en una captura real de producción.
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key, required this.test});

  final TestDetail test;

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  late List<TestStudent> _students;
  bool _byAlphabet = false;

  @override
  void initState() {
    super.initState();
    _students = List.of(widget.test.students);
  }

  int get _participants => _students.where((s) => s.present).length;

  void _toggleSort(bool byAlphabet) {
    setState(() {
      _byAlphabet = byAlphabet;
      if (byAlphabet) {
        _students.sort(
          (a, b) => a.firstName.toLowerCase() == b.firstName.toLowerCase()
              ? a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase())
              : a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase()),
        );
      } else {
        _students.sort((a, b) => a.id.compareTo(b.id));
      }
    });
  }

  Future<void> _addGroup() async {
    final added = await Navigator.of(context).push<List<TestStudent>>(
      MaterialPageRoute(
        builder: (_) => GroupsListScreen(
          startNum: _students.length + 1,
          // La pantalla real de Students manda `{ groupId }` (camelCase)
          // al borrar un grupo — distinto de Attendance, ver
          // groups_repository.dart.
          deleteUsesCamelCaseKey: true,
        ),
      ),
    );
    if (added != null && added.isNotEmpty) {
      setState(() => _students.addAll(added));
    }
  }

  /// Add Student: por defecto escanea el QR de Student Passport; si no se
  /// puede, la misma pantalla ofrece cargarlo a mano como alumno nuevo.
  Future<void> _addStudent() async {
    final student = await Navigator.of(context).push<TestStudent>(
      MaterialPageRoute(
        builder: (_) => QrScanScreen(
          nextNum: _students.length + 1,
          allowManual: true,
        ),
      ),
    );
    if (student != null) setState(() => _students.add(student));
  }

  void _startTest() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TestGradingScreen(test: widget.test.copyWith(students: _students)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final test = widget.test;
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          test.name,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Test ID ${test.id}  |  ${test.center.name}, ${test.country.name}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TextButton.icon(
                  style: kCompactToolbarTextButtonStyle,
                  onPressed: _students.isEmpty
                      ? null
                      : () => _toggleSort(!_byAlphabet),
                  icon: const Icon(Icons.sort_by_alpha, size: 14),
                  label: const Text('By Alphabet'),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        FilledButton(
                          style: kCompactToolbarButtonStyle,
                          onPressed: _addGroup,
                          child: const Text('Add Group'),
                        ),
                        FilledButton(
                          style: kCompactToolbarButtonStyle,
                          onPressed: _addStudent,
                          child: const Text('Add Student'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildList()),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                onPressed: _participants == 0 ? null : _startTest,
                child: Text(
                  'START TEST ($_participants/${_students.length} STUDENTS)',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.group_add_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'No Students Here...',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add Students To Start The Test\nYou Can Also Add Saved Students Group',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _students.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final student = _students[index];
        return ListTile(
          leading: GestureDetector(
            onTap: () => setState(() => student.present = !student.present),
            child: CircleAvatar(
              radius: 10,
              backgroundColor: student.present
                  ? const Color(0xFF13B72E)
                  : const Color(0xFFECECEC),
              child: student.present
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ),
          title: Text(student.fullName),
          trailing: Text(
            student.levelName,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          onTap: () => setState(() => student.present = !student.present),
        );
      },
    );
  }
}
