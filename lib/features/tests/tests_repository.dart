import 'package:dio/dio.dart';

/// Porteado de GET /api/tests — confirmado contra producción real
/// (ikmfgrader.xyz) el 2026-10-25 con datos reales (no solo un array
/// vacío): devuelve un array PLANO con un campo `status` por item (1, 2 o
/// 3), NO una lista ya agrupada en 3 sub-listas como hace el código fuente
/// ASP.NET original recuperado del VM — el cliente agrupa localmente (ver
/// TestsListScreen). Esto confirma que el código del VM puede corresponder
/// a una versión distinta a la que corre hoy en producción.
class GraderTest {
  GraderTest({
    required this.id,
    required this.name,
    required this.date,
    required this.participants,
    required this.failed,
    required this.status,
  });

  final int id;
  final String name;
  final DateTime? date;
  final int participants;
  final int failed;
  final int status; // 1 = Opened, 2 = In progress, 3 = Ended

  factory GraderTest.fromJson(Map<String, dynamic> json) {
    return GraderTest(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '(sin nombre)',
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
      participants: json['participants'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      status: json['status'] as int? ?? 1,
    );
  }
}

class TestsRepository {
  TestsRepository(this._dio);
  final Dio _dio;

  Future<List<GraderTest>> fetchTests({required int centerId}) async {
    final response = await _dio.get(
      '/api/tests',
      queryParameters: {'center': centerId},
    );

    final list = response.data as List;
    return list.cast<Map<String, dynamic>>().map(GraderTest.fromJson).toList();
  }
}
