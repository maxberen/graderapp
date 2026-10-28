import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import 'add_student_repository.dart';
import 'test_detail_repository.dart';

/// Porteado de mU (main.js:44960+) — formulario para agregar UN alumno al
/// test actual (nombre, apellido, email, nivel, "Use My Default Email").
/// En el original el alta queda en SQLite local y se sube recién con
/// "Sync Test" (ver conversación) — acá, sin cola offline todavía, el
/// alumno nuevo se agrega solo a la lista en memoria de StudentsScreen de
/// esta sesión (mismo patrón ya usado para marcar presente/ausente).
///
/// "Use My Default Email" (texto real confirmado en main.js:45224): si el
/// alumno no tiene email propio, usa el email por defecto que el
/// instructor configuró en el Menu lateral (ver grader_menu_drawer.dart) en
/// vez de exigir uno único — así no bloquea el alta.
class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key, required this.nextNum});

  final int nextNum;

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _levelsRepository = LevelsRepository(ApiClient.instance.dio);

  List<StudentLevel>? _levels;
  StudentLevel? _selectedLevel;
  bool _useDefaultEmail = false;
  String? _defaultEmail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final levels = await _levelsRepository.fetchLevels();
    final defaultEmail = await SecureStorage.instance.defaultEmail;
    setState(() {
      _levels = levels;
      _selectedLevel = levels.isNotEmpty ? levels.first : null;
      _defaultEmail = defaultEmail;
    });
  }

  void _toggleUseDefaultEmail(bool value) {
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
      _useDefaultEmail = value;
      if (value) _emailController.text = _defaultEmail!;
    });
  }

  void _save({required bool andClose}) {
    if (!_formKey.currentState!.validate() || _selectedLevel == null) return;
    final student = TestStudent(
      id: -DateTime.now().millisecondsSinceEpoch, // negativo: id local, no sincronizado
      testStudentId: 0,
      num: widget.nextNum,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _useDefaultEmail ? _defaultEmail! : _emailController.text.trim(),
      present: true,
      levelName: _selectedLevel!.name,
      levelCode: _selectedLevel!.code,
      fail: false,
    );
    if (andClose) {
      Navigator.of(context).pop(student);
    } else {
      Navigator.of(context).pop(student);
      // El original permite cargar varios seguidos sin cerrar; acá
      // simplificamos a un alumno por vez — se puede volver a tocar
      // "Add Student" para cargar el siguiente.
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final levels = _levels;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Student')),
      body: levels == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(labelText: 'First Name'),
                      validator: (v) =>
                          (v == null || v.trim().length < 2) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                      validator: (v) =>
                          (v == null || v.trim().length < 2) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_useDefaultEmail,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Email inválido'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<StudentLevel>(
                      initialValue: _selectedLevel,
                      decoration: const InputDecoration(labelText: 'Level'),
                      items: levels
                          .map((l) => DropdownMenuItem(
                                value: l,
                                child: Text('${l.code} — ${l.name}'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedLevel = v),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _useDefaultEmail,
                      title: const Text('Use My Default Email'),
                      subtitle: _defaultEmail != null && _defaultEmail!.isNotEmpty
                          ? Text(_defaultEmail!)
                          : null,
                      onChanged: (v) => _toggleUseDefaultEmail(v ?? false),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => _save(andClose: true),
                      child: const Text('Guardar y volver'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
