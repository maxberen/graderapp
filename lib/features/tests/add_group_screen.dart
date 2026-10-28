import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import 'add_student_repository.dart';
import 'groups_repository.dart';
import 'test_detail_repository.dart';

/// Porteado de la pantalla real "Add New Group" (`/add-group` → clase HJ,
/// main.js:52790-53090; equivalente en Attendance `/attendance-add-group`
/// → clase cX, main.js:54309-54719) — confirmado contra el código fuente
/// decompilado. Arranca VACÍA (sin pre-cargar la lista actual del test —
/// eso es un camino distinto, "Set current list as a new group", que no
/// es este botón): nombre del grupo + "ADD STUDENTS" agrega de a un
/// alumno por vez (First Name/Last Name/Email/"Use My Default
/// Email"/nivel), SAVE crea el grupo en el servidor.
class AddGroupScreen extends StatefulWidget {
  const AddGroupScreen({super.key});

  @override
  State<AddGroupScreen> createState() => _AddGroupScreenState();
}

class _StudentFormEntry {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  bool useDefaultEmail = false;
  StudentLevel? level;

  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
  }
}

class _AddGroupScreenState extends State<AddGroupScreen> {
  final _groupsRepository = GroupsRepository(ApiClient.instance.dio);
  final _levelsRepository = LevelsRepository(ApiClient.instance.dio);
  final _groupNameController = TextEditingController();
  final _entries = <_StudentFormEntry>[];

  List<StudentLevel> _levels = [];
  String? _defaultEmail;
  bool _loadingLevels = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final levels = await _levelsRepository.fetchLevels();
    final defaultEmail = await SecureStorage.instance.defaultEmail;
    if (!mounted) return;
    setState(() {
      _levels = levels;
      _defaultEmail = defaultEmail;
      _loadingLevels = false;
    });
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  void _addStudentEntry() {
    setState(() => _entries.add(_StudentFormEntry()));
  }

  void _toggleDefaultEmail(_StudentFormEntry entry, bool value) {
    if (value && (_defaultEmail == null || _defaultEmail!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Todavía no configuraste tu email por defecto (Menu → Default Email).',
          ),
        ),
      );
      return;
    }
    setState(() {
      entry.useDefaultEmail = value;
      if (value) entry.emailController.text = _defaultEmail!;
    });
  }

  Future<void> _save() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ponele un nombre al grupo.')),
      );
      return;
    }
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agregá al menos un alumno (ADD STUDENTS).'),
        ),
      );
      return;
    }
    for (final e in _entries) {
      final email = e.useDefaultEmail
          ? _defaultEmail!
          : e.emailController.text.trim();
      if (e.firstNameController.text.trim().isEmpty ||
          e.lastNameController.text.trim().isEmpty ||
          !email.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Completá nombre, apellido y email de todos los alumnos.',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final instructorId = await SecureStorage.instance.userId;
      var num = 1;
      final students = _entries.map((e) {
        final level = e.level;
        return TestStudent(
          id: -(num),
          testStudentId: 0,
          num: num++,
          firstName: e.firstNameController.text.trim(),
          lastName: e.lastNameController.text.trim(),
          email: e.useDefaultEmail
              ? _defaultEmail!
              : e.emailController.text.trim(),
          present: true,
          levelName: level?.name ?? '',
          levelCode: level?.code ?? '',
          fail: false,
        );
      }).toList();

      await _groupsRepository.createGroup(
        name: name,
        students: students,
        levels: _levels,
        instructorId: instructorId ?? 0,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el grupo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Group')),
      body: _loadingLevels
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _groupNameController,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _addStudentEntry,
                    child: const Text('ADD STUDENTS'),
                  ),
                ),
                Expanded(
                  child: _entries.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Tocá ADD STUDENTS para cargar alumnos.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _entries.length,
                          itemBuilder: (context, index) =>
                              _buildStudentEntry(context, index, scheme),
                        ),
                ),
                SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const RoundedRectangleBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('SAVE'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStudentEntry(
    BuildContext context,
    int index,
    ColorScheme scheme,
  ) {
    final entry = _entries[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Student NO : ${index + 1}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: entry.firstNameController,
            decoration: const InputDecoration(
              labelText: 'First Name',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: entry.lastNameController,
            decoration: const InputDecoration(
              labelText: 'Last Name',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: entry.emailController,
            enabled: !entry.useDefaultEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          Row(
            children: [
              Switch(
                value: entry.useDefaultEmail,
                onChanged: (v) => _toggleDefaultEmail(entry, v),
              ),
              const Text('Use My Default Email'),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Current Rank:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _levels.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, levelIndex) {
                final level = _levels[levelIndex];
                final selected = entry.level?.id == level.id;
                return ChoiceChip(
                  label: Text(level.name.isNotEmpty ? level.name : level.code),
                  selected: selected,
                  onSelected: (_) => setState(() => entry.level = level),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
