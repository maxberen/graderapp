import 'package:dio/dio.dart';

import 'add_student_repository.dart';
import 'test_detail_repository.dart';

/// Porteado de la sección "Groups" real (main.js:30177-30303, componentes
/// zJ/fX en main.js:53000-53360 y 54700-54990) — confirmado contra el
/// código fuente decompilado, no contra la API en vivo (a diferencia del
/// resto de los endpoints de esta app). "Add Group" en el toolbar real NO
/// agrega directo: abre una lista de grupos YA guardados (con un buscador
/// que filtra client-side por nombre, no una búsqueda server-side) donde
/// elegís uno o más para sumar sus alumnos a la lista actual — eso se hace
/// con GET getstudentgroups/{id} por cada grupo marcado y empujando los
/// alumnos al array local, SIN ningún POST; el servidor recién se entera
/// cuando se arranca el test (SyncNewStudent), igual que agregar un
/// alumno individual o por QR.
///
/// Discrepancia real confirmada entre las dos pantallas gemelas del
/// original: el delete de Students manda `{ groupId: id }` (camelCase) y
/// el de Attendance manda `{ groupid: id }` (minúscula) — mismo endpoint,
/// mismo propósito, bodies distintos en el código real. Se respeta acá vía
/// [deleteGroups]'s `camelCaseKey` en vez de unificarlo a propósito.
class StudentGroup {
  StudentGroup({required this.id, required this.name});

  final int id;
  final String name;

  factory StudentGroup.fromJson(Map<String, dynamic> json) => StudentGroup(
    id: int.parse(json['id'].toString()),
    name: json['name'] as String? ?? '',
  );
}

class GroupsRepository {
  GroupsRepository(this._dio);
  final Dio _dio;

  Future<List<StudentGroup>> fetchGroups() async {
    final response = await _dio.get('/api/students/groups');
    final list = response.data as List;
    return list
        .cast<Map<String, dynamic>>()
        .map(StudentGroup.fromJson)
        .toList();
  }

  /// Trae los alumnos de un grupo guardado y los arma como [TestStudent]
  /// listos para agregar a la lista local del test — mismo contrato que
  /// [AddStudentScreen]/QR: sin `testStudentId` real todavía (se asigna al
  /// sincronizar), `present: true` por default.
  Future<List<TestStudent>> fetchGroupStudents(
    int groupId, {
    required List<StudentLevel> levels,
    required int startNum,
  }) async {
    final response = await _dio.get('/api/students/getstudentgroups/$groupId');
    final list = response.data as List;
    var num = startNum;
    return list.cast<Map<String, dynamic>>().map((json) {
      final levelId = json['levelId'];
      final level = levels.where((l) => l.id == levelId).firstOrNull;
      final id = int.tryParse(json['studentId'].toString()) ?? -(num);
      return TestStudent(
        id: id,
        testStudentId: 0,
        num: num++,
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        present: true,
        levelName: json['levelName'] as String? ?? level?.name ?? '',
        levelCode: json['levelCode'] as String? ?? level?.code ?? '',
        fail: false,
      );
    }).toList();
  }

  /// Crea un grupo nuevo a partir de la lista de alumnos pasada — en el
  /// original esto es un formulario propio (nombre + alta manual de
  /// alumnos); acá se simplifica a "guardar la lista actual del test con
  /// un nombre", que es exactamente el otro camino real para llegar a
  /// crear un grupo (`addStudentToGroup()` → "usar la lista actual").
  Future<void> createGroup({
    required String name,
    required List<TestStudent> students,
    required List<StudentLevel> levels,
    required int instructorId,
  }) async {
    await _dio.post(
      '/api/students/creategroup',
      data: {
        'name': name,
        'students': students.map((s) {
          final level = levels.where((l) => l.code == s.levelCode).firstOrNull;
          return {
            'Email': s.email,
            'FirstName': s.firstName,
            'LastName': s.lastName,
            'CountryId': 1,
            'LevelId': level?.id,
            'Id': 0,
            'DefautEmail': false,
          };
        }).toList(),
        'INSTRUCTOR_ID': instructorId.toString(),
      },
    );
  }

  Future<void> deleteGroups(
    List<int> groupIds, {
    required bool camelCaseKey,
  }) async {
    final key = camelCaseKey ? 'groupId' : 'groupid';
    await _dio.post(
      '/api/students/deletegroup',
      data: groupIds.map((id) => {key: id}).toList(),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
