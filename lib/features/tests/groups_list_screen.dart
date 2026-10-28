import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import 'add_group_screen.dart';
import 'add_student_repository.dart';
import 'groups_repository.dart';
import 'test_detail_repository.dart';

/// Porteado de la pantalla real "Groups" (`/groups` para Students,
/// `/attendance-groups` para Attendance — ver groups_repository.dart para
/// el detalle de la investigación contra main.js). Buscador que filtra
/// client-side, lista de grupos guardados con checkbox, "+" abre
/// [AddGroupScreen] para crear un grupo nuevo desde cero, ADD para sumar
/// los alumnos de los grupos marcados a la lista actual, DELETE para
/// borrarlos.
class GroupsListScreen extends StatefulWidget {
  const GroupsListScreen({
    super.key,
    required this.startNum,
    required this.deleteUsesCamelCaseKey,
  });

  final int startNum;
  final bool deleteUsesCamelCaseKey;

  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> {
  final _groupsRepository = GroupsRepository(ApiClient.instance.dio);
  final _levelsRepository = LevelsRepository(ApiClient.instance.dio);
  final _searchController = TextEditingController();

  List<StudentGroup>? _groups;
  List<StudentLevel> _levels = [];
  final Set<int> _selected = {};
  String _query = '';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _groupsRepository.fetchGroups(),
        _levelsRepository.fetchLevels(),
      ]);
      setState(() {
        _groups = results[0] as List<StudentGroup>;
        _levels = results[1] as List<StudentLevel>;
      });
    } catch (_) {
      setState(() => _error = 'No se pudieron cargar los grupos guardados.');
    }
  }

  List<StudentGroup> get _filtered {
    final groups = _groups ?? const [];
    if (_query.isEmpty) return groups;
    return groups.where((g) => g.name.toLowerCase().contains(_query)).toList();
  }

  Future<void> _addSelected() async {
    if (_selected.isEmpty) return;
    setState(() => _busy = true);
    try {
      final merged = <TestStudent>[];
      var num = widget.startNum;
      for (final groupId in _selected) {
        final students = await _groupsRepository.fetchGroupStudents(
          groupId,
          levels: _levels,
          startNum: num,
        );
        merged.addAll(students);
        num += students.length;
      }
      if (mounted) Navigator.of(context).pop(merged);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron traer los alumnos del grupo.'),
          ),
        );
      }
    }
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _groupsRepository.deleteGroups(
        _selected.toList(),
        camelCaseKey: widget.deleteUsesCamelCaseKey,
      );
      setState(() => _selected.clear());
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron borrar los grupos.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAddNewGroup() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddGroupScreen()));
    if (created ?? false) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add New Group',
            onPressed: _busy ? null : _openAddNewGroup,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search Test',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(child: _buildBody()),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy || _selected.isEmpty
                          ? null
                          : _deleteSelected,
                      child: const Text('DELETE GROUP'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy || _selected.isEmpty
                          ? null
                          : _addSelected,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('ADD GROUP'),
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

  Widget _buildBody() {
    if (_error != null) return Center(child: Text(_error!));
    if (_groups == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final groups = _filtered;
    if (groups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "There's No Group Here...\nAdd Group To Select Group",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return CheckboxListTile(
          value: _selected.contains(group.id),
          title: Text(group.name),
          onChanged: _busy
              ? null
              : (checked) => setState(() {
                  if (checked ?? false) {
                    _selected.add(group.id);
                  } else {
                    _selected.remove(group.id);
                  }
                }),
        );
      },
    );
  }
}
