import 'package:dio/dio.dart';

class GraderCenter {
  GraderCenter({required this.id, required this.name});
  final int id;
  final String name;

  factory GraderCenter.fromJson(Map<String, dynamic> json) =>
      GraderCenter(id: json['id'] as int, name: json['name'] as String);
}

class GraderCountry {
  GraderCountry({
    required this.id,
    required this.name,
    required this.flag,
    required this.centers,
  });

  final int id;
  final String name;
  final String flag;
  final List<GraderCenter> centers;

  factory GraderCountry.fromJson(Map<String, dynamic> json) => GraderCountry(
        id: json['id'] as int,
        name: json['name'] as String,
        flag: json['flag'] as String? ?? '',
        centers: (json['centers'] as List)
            .cast<Map<String, dynamic>>()
            .map(GraderCenter.fromJson)
            .toList(),
      );
}

/// Porteado de `repository.countries.getCountriesByInstructor()` —
/// `GET /api/instructors/countries?lang={lang}` (main.js:30370-30410). No
/// estaba documentado en docs/API.md original — encontrado y confirmado
/// contra producción real (ver HANDOFF.md). El original cachea la respuesta
/// en localStorage indefinidamente (hasta logout); acá no se replica ese
/// cache todavía, cada carga pega a la red.
class CountriesRepository {
  CountriesRepository(this._dio);
  final Dio _dio;

  Future<List<GraderCountry>> fetchCountriesByInstructor({int lang = 1}) async {
    final response = await _dio.get(
      '/api/instructors/countries',
      queryParameters: {'lang': lang},
    );

    final list = response.data as List;
    return list.cast<Map<String, dynamic>>().map(GraderCountry.fromJson).toList();
  }
}
