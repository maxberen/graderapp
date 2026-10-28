import 'package:dio/dio.dart';

/// Porteado de mS (main.js:37409+) — `GET /api/getTestResults/{id}`.
/// Confirmado en vivo 2026-10-25 contra el test real 10344 (DEMO
/// J1J2J3J4J5), devolviendo exactamente lo que mostró el usuario en una
/// captura real de producción: totalPassed/totalFailed/totalCondition +
/// lista de alumnos con totalPoints (viene como STRING, ej "100.00") y un
/// campo `result` ya clasificado ("pass"/"fail"/"condition").
class TestResultStudent {
  TestResultStudent({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.levelCode,
    required this.shirtNum,
    required this.totalPoints,
    required this.result,
    required this.mistakeCount,
  });

  final int studentId;
  final String firstName;
  final String lastName;
  final String levelCode;
  final int shirtNum;
  final double totalPoints;
  final String result;
  final int mistakeCount;

  String get fullName => '$firstName $lastName'.trim();

  factory TestResultStudent.fromJson(Map<String, dynamic> json) {
    final results = (json['results'] as List? ?? []);
    final mistakeCount =
        results.where((r) => r['result'] == 'Mistake').length;
    return TestResultStudent(
      studentId: json['studentId'] as int? ?? 0,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      levelCode: json['levelCode'] as String? ?? '',
      shirtNum: json['shirtNum'] as int? ?? 0,
      totalPoints: double.tryParse(json['totalPoints']?.toString() ?? '') ?? 0,
      result: json['result'] as String? ?? '',
      mistakeCount: mistakeCount,
    );
  }
}

class TestResults {
  TestResults({
    required this.testId,
    required this.testName,
    required this.totalPassed,
    required this.totalFailed,
    required this.totalCondition,
    required this.students,
  });

  final int testId;
  final String testName;
  final int totalPassed;
  final int totalFailed;
  final int totalCondition;
  final List<TestResultStudent> students;

  factory TestResults.fromJson(Map<String, dynamic> json) => TestResults(
        testId: json['testId'] as int? ?? 0,
        testName: json['testName'] as String? ?? '',
        totalPassed: json['totalPassed'] as int? ?? 0,
        totalFailed: json['totalFailed'] as int? ?? 0,
        totalCondition: json['totalCondition'] as int? ?? 0,
        students: (json['students'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(TestResultStudent.fromJson)
            .toList(),
      );
}

class ResultsRepository {
  ResultsRepository(this._dio);
  final Dio _dio;

  Future<TestResults> fetchTestResults(int testId) async {
    final response = await _dio.get('/api/getTestResults/$testId');
    return TestResults.fromJson(response.data as Map<String, dynamic>);
  }
}
