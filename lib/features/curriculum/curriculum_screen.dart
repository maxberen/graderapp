import 'package:flutter/material.dart';

import '../tests/technique_video_player.dart';
import '../tests/test_detail_repository.dart';
import 'curriculum_repository.dart';

/// Porteado de kX (main.js:61156+) — "Curriculum Video List": 3 categorías
/// (G1-G5 / P1-P5 / K1-K5), buscador, lista de técnicas; tocar una técnica
/// expande el video real de esa técnica (mismo reproductor que en el
/// wizard de calificación).
class CurriculumScreen extends StatefulWidget {
  const CurriculumScreen({super.key});

  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen> {
  final _repository = CurriculumRepository();
  CurriculumCategory _category = CurriculumCategory.graduate;
  List<TestTechnique>? _techniques;
  String _search = '';
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _techniques = null);
    final techniques = await _repository.fetchCategory(_category);
    if (mounted) setState(() => _techniques = techniques);
  }

  void _selectCategory(CurriculumCategory category) {
    if (category == _category) return;
    setState(() {
      _category = category;
      _expandedIndex = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final techniques = _techniques;
    final filtered = techniques == null
        ? null
        : techniques.where((t) {
            if (_search.isEmpty) return true;
            final q = _search.toLowerCase();
            return t.name.toLowerCase().contains(q) ||
                t.code.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Curriculum Video List')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search Videos',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: _CategoryCard(
                    label: 'K1-K5',
                    selected: _category == CurriculumCategory.kids,
                    onTap: () => _selectCategory(CurriculumCategory.kids),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CategoryCard(
                    label: 'P1-P5',
                    selected: _category == CurriculumCategory.practitioner,
                    onTap: () => _selectCategory(CurriculumCategory.practitioner),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CategoryCard(
                    label: 'G1-G5',
                    selected: _category == CurriculumCategory.graduate,
                    onTap: () => _selectCategory(CurriculumCategory.graduate),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final technique = filtered[index];
                      final expanded = _expandedIndex == index;
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              title: Text(technique.name),
                              subtitle: Text('${technique.code} · ${technique.score} pts'),
                              trailing: Icon(
                                expanded ? Icons.expand_less : Icons.play_circle_outline,
                              ),
                              onTap: () => setState(
                                () => _expandedIndex = expanded ? null : index,
                              ),
                            ),
                            if (expanded)
                              TechniqueVideoPlayer(techniqueCode: technique.code),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
