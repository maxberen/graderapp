import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import '../location/countries_repository.dart';
import '../location/country_selector_screen.dart';
import 'add_test_repository.dart';

/// Porteado de AJ (main.js:52200+) — wizard real de 3 pasos: "SELECT
/// TESTER" (a quién se le toma el examen), "SELECT TEST" (plantilla de
/// curriculum) y "SELECT DATE" (acá además pedimos el centro, reusando
/// CountrySelectorScreen — el original lo hace con un selector embebido
/// equivalente). Confirmado contra `GET /api/tests/GetTestDataInstructor`
/// real. Al confirmar, crea el test directo en el servidor (ver
/// add_test_repository.dart para la simplificación vs. el original
/// offline-first).
class AddTestScreen extends StatefulWidget {
  const AddTestScreen({super.key});

  @override
  State<AddTestScreen> createState() => _AddTestScreenState();
}

enum _Step { tester, test, date }

class _AddTestScreenState extends State<AddTestScreen> {
  final _repository = AddTestRepository(ApiClient.instance.dio);

  AddTestData? _data;
  String? _error;
  _Step _step = _Step.tester;

  AddTestInstructor? _tester;
  AddTestTemplate? _template;
  GraderCenter? _center;
  DateTime _date = DateTime.now();

  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _repository.fetchTestData();
      setState(() => _data = data);
    } catch (e) {
      setState(() => _error = 'No se pudieron cargar los datos del test.');
    }
  }

  Future<void> _pickCenter() async {
    final center = await Navigator.of(context).push<GraderCenter>(
      MaterialPageRoute(builder: (_) => const CountrySelectorScreen()),
    );
    if (center != null) setState(() => _center = center);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_tester == null || _template == null || _center == null) return;
    setState(() => _creating = true);
    try {
      final testId = await _repository.createTest(
        instructorId: _tester!.id,
        centerId: _center!.id,
        templateId: _template!.id,
        date: _date,
      );
      if (!mounted) return;
      Navigator.of(context).pop(testId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear el test.')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Test')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) return Center(child: Text(_error!));
    final data = _data;
    if (data == null) return const Center(child: CircularProgressIndicator());

    switch (_step) {
      case _Step.tester:
        return _StepList(
          title: 'SELECT TESTER',
          items: data.instructors.map((i) => i.fullName).toList(),
          onSelect: (index) {
            setState(() {
              _tester = data.instructors[index];
              _step = _Step.test;
            });
          },
        );
      case _Step.test:
        return _StepList(
          title: 'SELECT TEST',
          items: data.templates
              .map((t) => '${t.name} (${t.techniqueCount} técnicas)')
              .toList(),
          onSelect: (index) {
            setState(() {
              _template = data.templates[index];
              _step = _Step.date;
            });
          },
        );
      case _Step.date:
        return _buildDateStep();
    }
  }

  Widget _buildDateStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SELECT DATE', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ListTile(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            title: Text(DateFormat('dd/MM/yyyy').format(_date)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            title: Text(_center?.name ?? 'Elegir centro'),
            trailing: const Icon(Icons.location_on_outlined),
            onTap: _pickCenter,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_center == null || _creating) ? null : _submit,
              child: _creating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('CREAR TEST'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepList extends StatelessWidget {
  const _StepList({
    required this.title,
    required this.items,
    required this.onSelect,
  });

  final String title;
  final List<String> items;
  final void Function(int index) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => ListTile(
              title: Text(items[index]),
              onTap: () => onSelect(index),
            ),
          ),
        ),
      ],
    );
  }
}
