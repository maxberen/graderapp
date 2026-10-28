import 'package:dio/dio.dart';

import '../tests/test_detail_repository.dart';

/// Porteado de bX (main.js:55063+) — `POST /api/attendance/saveattendance`,
/// confirmado leyendo takeAttendance() (main.js:30277-30281). A diferencia
/// de Students (atado a un test), Attendance es una lista independiente que
/// el instructor arma en el momento (siempre arranca vacía, igual que el
/// original) y envía con "Save & Send To {email}".
class AttendanceRepository {
  AttendanceRepository(this._dio);
  final Dio _dio;

  Future<void> saveAttendance({
    required List<TestStudent> students,
    required int instructorId,
  }) async {
    await _dio.post(
      '/api/attendance/saveattendance',
      data: {
        'InstructorId': instructorId,
        'Students': students
            .asMap()
            .entries
            .map((entry) => {
                  'StudentId': entry.value.id,
                  'firstName': entry.value.firstName,
                  'lastName': entry.value.lastName,
                  'email': entry.value.email,
                  'present': entry.value.present,
                  'testStudentId': entry.value.testStudentId,
                  'num': entry.key + 1,
                  'defaultEmail': false,
                  'LevelId': entry.value.levelCode,
                })
            .toList(),
      },
    );
  }
}
