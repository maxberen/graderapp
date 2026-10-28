import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import 'results_repository.dart';
import 'test_detail_repository.dart';

/// Porteado de mS (main.js:37409+) — layout real confirmado contra una
/// captura de producción y el endpoint real `GET /api/getTestResults/{id}`
/// (probado en vivo con el test 10344, misma data que mostró el usuario):
/// "Results Higlights" con 3 cajas (Passed/Failed/Under Conditions) +
/// botón Sync Test, luego "Students Results" con sort "By Score" y la
/// lista de alumnos (puntaje, cantidad de mistakes).
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, required this.test});

  final TestDetail test;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _repository = ResultsRepository(ApiClient.instance.dio);
  TestResults? _results;
  String? _error;
  bool _byScore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await _repository.fetchTestResults(widget.test.id);
      setState(() => _results = results);
    } catch (e) {
      setState(() => _error = 'No se pudieron cargar los resultados.');
    }
  }

  Future<void> _syncTest() async {
    // El "Sync Test" real empuja a producción los resultados calificados
    // offline (ver conversación — no implementado todavía en esta app:
    // calificamos solo en memoria, no hay cola local para sincronizar).
    // Por ahora este botón simplemente refresca contra el servidor real.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sincronización de calificaciones todavía no implementada — '
          'actualizando desde el servidor.',
        ),
      ),
    );
    await _load();
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
                TextButton(
                  onPressed: _syncTest,
                  child: const Text('Sync Test'),
                ),
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
              child: Center(child: Text('Sin resultados para este test.')),
            )
          else
            ...students.map((student) => ListTile(
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
                )),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label, required this.color});

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
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
