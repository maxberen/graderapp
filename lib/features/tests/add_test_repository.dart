import 'package:dio/dio.dart';

/// Porteado de AJ (main.js:52280+) — `GET /api/tests/GetTestDataInstructor`
/// confirmado en vivo 2026-10-25: devuelve `instructors` (candidatos a
/// "examinado"), `templates` (niveles/currículums disponibles como punto
/// de partida de un test nuevo) y `centers` (no usado acá — reusamos
/// CountrySelectorScreen, que ya pega a /api/instructors/countries).
///
/// El original crea el test SOLO local (SQLite) y recién lo sube al
/// servidor real con "Sync Test" (ver addNewTestToServer,
/// POST /api/tests/addNewTest). Esta app no tiene cola offline todavía, así
/// que createTest() pega directo a ese mismo endpoint real al confirmar el
/// wizard — simplificación consciente: el test queda creado en el servidor
/// al toque, no en un borrador local pendiente de sync.
class AddTestInstructor {
  AddTestInstructor({required this.id, required this.fullName});
  final int id;
  final String fullName;

  factory AddTestInstructor.fromJson(Map<String, dynamic> json) {
    final first = (json['f_NAME'] as String? ?? '').trim();
    final last = (json['l_NAME'] as String? ?? '').trim();
    return AddTestInstructor(
      id: json['id'] as int,
      fullName: '$first $last'.trim(),
    );
  }
}

class AddTestTemplate {
  AddTestTemplate({
    required this.id,
    required this.name,
    required this.techniqueCount,
  });
  final int id;
  final String name;
  final int techniqueCount;

  factory AddTestTemplate.fromJson(Map<String, dynamic> json) =>
      AddTestTemplate(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        techniqueCount: (json['techniques'] as List? ?? []).length,
      );
}

class AddTestData {
  AddTestData({required this.instructors, required this.templates});
  final List<AddTestInstructor> instructors;
  final List<AddTestTemplate> templates;
}

class AddTestRepository {
  AddTestRepository(this._dio);
  final Dio _dio;

  Future<AddTestData> fetchTestData() async {
    final response = await _dio.get('/api/tests/GetTestDataInstructor');
    final data = response.data as Map<String, dynamic>;
    return AddTestData(
      instructors: (data['instructors'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(AddTestInstructor.fromJson)
          .toList(),
      templates: (data['templates'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(AddTestTemplate.fromJson)
          .toList(),
    );
  }

  /// Devuelve el id del test real creado en el servidor.
  Future<int> createTest({
    required int instructorId,
    required int centerId,
    required int templateId,
    required DateTime date,
  }) async {
    final response = await _dio.post(
      '/api/tests/addNewTest',
      data: [
        {
          'InstructorId': instructorId,
          'CenterId': centerId,
          'TestId': templateId,
          'Day': date.day,
          'Month': date.month,
          'Year': date.year,
        },
      ],
    );
    final list = response.data as List;
    return (list.first as Map<String, dynamic>)['testId'] as int;
  }
}
