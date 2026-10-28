import 'package:dio/dio.dart';

/// Porteado de `GET /api/students/levels` — confirmado en vivo 2026-10-25,
/// usado por mU (Add Student) para el selector de nivel.
class StudentLevel {
  StudentLevel({required this.id, required this.code, required this.name});
  final int id;
  final String code;
  final String name;

  factory StudentLevel.fromJson(Map<String, dynamic> json) => StudentLevel(
        id: json['id'] as int,
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}

class LevelsRepository {
  LevelsRepository(this._dio);
  final Dio _dio;

  Future<List<StudentLevel>> fetchLevels() async {
    final response = await _dio.get('/api/students/levels');
    final list = response.data as List;
    return list.cast<Map<String, dynamic>>().map(StudentLevel.fromJson).toList();
  }
}
