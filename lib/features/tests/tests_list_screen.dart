import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import '../auth/auth_repository.dart';
import '../location/countries_repository.dart';
import '../location/country_selector_screen.dart';
import '../menu/grader_menu_drawer.dart';
import 'results_outbox.dart';
import 'results_screen.dart';
import 'students_screen.dart';
import 'test_detail_repository.dart';
import 'test_grading_screen.dart';
import 'tests_repository.dart';

/// Porteado del flujo real: km-test-country-header (selector de
/// país/ubicación embebido arriba) + lista de tests agrupada en 3 tabs
/// (OPENED / IN PROGRESS / ENDED según status 1/2/3) — nombres de tab y
/// comportamiento confirmados contra capturas reales de producción.
class TestsListScreen extends StatefulWidget {
  const TestsListScreen({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<TestsListScreen> createState() => _TestsListScreenState();
}

class _TestsListScreenState extends State<TestsListScreen> {
  final _testsRepository = TestsRepository(ApiClient.instance.dio);
  final _testDetailRepository = TestDetailRepository(ApiClient.instance.dio);
  final _authRepository = AuthRepository(ApiClient.instance.dio);

  GraderCenter? _center;
  GraderCountry? _country;
  List<GraderTest>? _tests;
  String? _error;
  bool _loading = true;
  bool _pickingLocation = false;

  @override
  void initState() {
    super.initState();
    // Navigator.push no puede llamarse de forma síncrona en initState — el
    // Overlay todavía se está construyendo. Diferido a después del primer
    // frame (causaba "setState() called during build" + navigator locked).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pickLocationThenLoad();
    });
  }

  Future<void> _pickLocationThenLoad() async {
    if (_pickingLocation) return;
    _pickingLocation = true;
    try {
      final result = await Navigator.of(context).push<GraderCenter>(
        MaterialPageRoute(builder: (_) => const CountrySelectorScreen()),
      );
      if (result == null) {
        // El usuario canceló el selector sin elegir — volvemos atrás (a Home).
        if (mounted) Navigator.of(context).maybePop();
        return;
      }
      setState(() => _center = result);
      await _loadTests();
    } finally {
      _pickingLocation = false;
    }
  }

  Future<void> _loadTests() async {
    if (_center == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tests = await _testsRepository.fetchTests(centerId: _center!.id);
      setState(() => _tests = tests);
    } catch (e) {
      setState(() => _error = 'No se pudieron cargar los tests.');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Porteado de openTest() (main.js:42527-42547): carga el detalle
  /// completo del test y navega según status — 1 Opened -> Students,
  /// 2 In Progress -> Test (calificar), 3 Ended -> Results.
  Future<void> _openTest(GraderTest test) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final detail = await _testDetailRepository.fetchTestDetail(test.id);
      if (!mounted) return;
      Navigator.of(context).pop(); // cierra el loader
      Widget screen;
      switch (detail.status) {
        case 1:
          screen = StudentsScreen(test: detail);
          break;
        case 3:
          screen = ResultsScreen(test: detail);
          break;
        default:
          screen = TestGradingScreen(test: detail);
      }
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // cierra el loader
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar el test.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_center == null) {
      // Todavía eligiendo ubicación (o cargándola).
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tests = _tests ?? [];
    final opened = tests.where((t) => t.status == 1).toList();
    final inProgress = tests.where((t) => t.status == 2).toList();
    final ended = tests.where((t) => t.status == 3).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        drawer: GraderMenuDrawer(
          onApp: () => Navigator.of(context).popUntil((r) => r.isFirst),
          onHome: _pickLocationThenLoad,
          onLogout: () async {
            await _authRepository.logout();
            widget.onLogout();
          },
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 160,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                  child: InkWell(
                    onTap: _pickLocationThenLoad,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '${_center!.name}${_country != null ? ', ${_country!.name}' : ''}',
                            style: Theme.of(context).textTheme.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down),
                      ],
                    ),
                  ),
                ),
              ),
              bottom: TabBar(
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                tabs: [
                  _CountTab(label: 'OPENED', count: opened.length),
                  _CountTab(label: 'IN PROGRESS', count: inProgress.length),
                  _CountTab(label: 'ENDED', count: ended.length),
                ],
              ),
            ),
          ],
          body: _buildBody(opened: opened, inProgress: inProgress, ended: ended),
        ),
      ),
    );
  }

  Widget _buildBody({
    required List<GraderTest> opened,
    required List<GraderTest> inProgress,
    required List<GraderTest> ended,
  }) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }

    // Se redibuja cuando cambia la cola local (resultados pendientes / cierre).
    return ListenableBuilder(
      listenable: ResultsOutbox.instance,
      builder: (context, _) => RefreshIndicator(
      onRefresh: _loadTests,
      child: TabBarView(
        children: [
          _TestList(tests: opened, onTap: _openTest),
          _TestList(tests: inProgress, onTap: _openTest),
          _TestList(tests: ended, onTap: _openTest),
        ],
      ),
      ),
    );
  }
}

/// ¿Está todo lo de este test en el servidor? No si quedan resultados
/// calificados en el teléfono sin subir, o si el cierre (End Test) está
/// pedido y el servidor todavía no lo confirmó.
bool isTestSynced(int testId, [ResultsOutbox? outbox]) {
  final o = outbox ?? ResultsOutbox.instance;
  return o.pendingCount(testId) == 0 && !o.isCloseRequested(testId);
}

/// Nube con tilde verde (sincronizado) o cruz roja (sin sincronizar), como
/// el indicador de cada test en la app original.
class TestSyncBadge extends StatelessWidget {
  const TestSyncBadge({super.key, required this.synced});

  final bool synced;

  @override
  Widget build(BuildContext context) {
    final color = synced ? const Color(0xFF13B72E) : const Color(0xFFB61317);
    return Tooltip(
      message: synced ? 'Synced' : 'Not synced',
      child: SizedBox(
        key: Key(synced ? 'sync-badge-synced' : 'sync-badge-unsynced'),
        width: 34,
        height: 30,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned(
              left: 0,
              top: 0,
              child: Icon(Icons.cloud_outlined, size: 28),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(
                  synced ? Icons.check : Icons.close,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountTab extends StatelessWidget {
  const _CountTab({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text('$label ($count)'),
      ),
    );
  }
}

class _TestList extends StatelessWidget {
  const _TestList({required this.tests, required this.onTap});
  final List<GraderTest> tests;
  final void Function(GraderTest test) onTap;

  @override
  Widget build(BuildContext context) {
    if (tests.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('No hay tests en esta categoría.')),
        ],
      );
    }

    final dateFormat = DateFormat('dd.MM.yyyy');

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: tests.length,
      itemBuilder: (context, index) {
        final test = tests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
          onTap: () => onTap(test),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  color: Theme.of(context).colorScheme.primary,
                  margin: const EdgeInsets.only(right: 12),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        test.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      if (test.date != null)
                        Text(dateFormat.format(test.date!)),
                      const SizedBox(height: 4),
                      Text('Participants: ${test.participants}'),
                    ],
                  ),
                ),
                TestSyncBadge(synced: isTestSynced(test.id)),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}
