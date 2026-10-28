import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import 'countries_repository.dart';

/// Porteado de km-test-country-selector / km-test-country-header
/// (main.js:51850-51960): lista horizontal de países (con bandera) arriba,
/// lista de centros con radio button abajo, botón CONTINUE. El original lo
/// muestra como un panel que se desliza sobre el header de Tests; acá va
/// como pantalla completa por simplicidad — mismo contenido y flujo.
class CountrySelectorScreen extends StatefulWidget {
  const CountrySelectorScreen({super.key});

  @override
  State<CountrySelectorScreen> createState() => _CountrySelectorScreenState();
}

class _CountrySelectorScreenState extends State<CountrySelectorScreen> {
  final _repository = CountriesRepository(ApiClient.instance.dio);

  List<GraderCountry>? _countries;
  GraderCountry? _selectedCountry;
  GraderCenter? _selectedCenter;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final countries = await _repository.fetchCountriesByInstructor();
      setState(() {
        _countries = countries;
        _selectedCountry = countries.isNotEmpty ? countries.first : null;
      });
    } catch (e) {
      setState(() => _error = 'No se pudo cargar la lista de países.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Country and Location')),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _selectedCenter == null
                ? null
                : () => Navigator.of(context).pop(_selectedCenter),
            child: const Text('CONTINUE'),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_countries == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_countries!.isEmpty) {
      return const Center(child: Text('No hay países asignados a tu cuenta.'));
    }

    return Column(
      children: [
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _countries!.length,
            itemBuilder: (context, index) {
              final country = _countries![index];
              final selected = country.id == _selectedCountry?.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(country.name.toUpperCase()),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _selectedCountry = country;
                    _selectedCenter = null;
                  }),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: (_selectedCountry?.centers ?? []).map((center) {
              final selected = center.id == _selectedCenter?.id;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: RadioListTile<int>(
                  value: center.id,
                  groupValue: _selectedCenter?.id,
                  title: Text(
                    center.name,
                    style: TextStyle(fontWeight: selected ? FontWeight.bold : null),
                  ),
                  onChanged: (_) => setState(() => _selectedCenter = center),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
