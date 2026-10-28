import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/widgets/compact_toolbar_style.dart';
import '../tests/add_student_screen.dart';
import '../tests/groups_list_screen.dart';
import '../tests/test_detail_repository.dart';
import 'attendance_repository.dart';

/// Porteado de bX (main.js:55063+) — pantalla "Attendance", gemela de
/// Students pero independiente de cualquier test: el instructor arma una
/// lista de alumnos presentes y la envía con "Save & Send To {email}"
/// (email real del instructor logueado, no un texto fijo).
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _repository = AttendanceRepository(ApiClient.instance.dio);
  final _students = <TestStudent>[];
  String? _email;
  bool _byAlphabet = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    SecureStorage.instance.userEmail.then((e) {
      if (mounted) setState(() => _email = e);
    });
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

  Future<void> _addStudent() async {
    final student = await Navigator.of(context).push<TestStudent>(
      MaterialPageRoute(
        builder: (_) => AddStudentScreen(nextNum: _students.length + 1),
      ),
    );
    if (student != null) setState(() => _students.add(student));
  }

  Future<void> _addGroup() async {
    final added = await Navigator.of(context).push<List<TestStudent>>(
      MaterialPageRoute(
        builder: (_) => GroupsListScreen(
          startNum: _students.length + 1,
          // Attendance manda `{ groupid }` (minúscula) al borrar un grupo
          // — distinto de Students, ver groups_repository.dart.
          deleteUsesCamelCaseKey: false,
        ),
      ),
    );
    if (added != null && added.isNotEmpty) {
      setState(() => _students.addAll(added));
    }
  }

  Future<void> _save() async {
    final instructorId = await SecureStorage.instance.userId;
    if (instructorId == null) return;
    setState(() => _saving = true);
    try {
      await _repository.saveAttendance(
        students: _students,
        instructorId: instructorId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Succesfully Attendance Taken')),
      );
      setState(() => _students.clear());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please Try Again Later')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: Column(
        children: [
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
                onPressed: (_participants == 0 || _saving) ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Save & Send To ${_email ?? ''}'),
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
