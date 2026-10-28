import 'package:dio/dio.dart';

/// Los nombres de técnica reales traen entidades HTML sin decodificar
/// (ej. "Assailant&#039;s" en vez de "Assailant's") — confirmado tanto en
/// la data real de /api/tests/{id} como en el curriculum estático
/// embebido en el bundle original. Angular no las decodifica tampoco (usa
/// text nodes, no innerHTML), así que probablemente se ven rotas también
/// en producción — acá las limpiamos igual, es una mejora cosmética sin
/// efecto funcional.
String _decodeHtmlEntities(String input) {
  return input
      .replaceAll('&#039;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
}

/// Porteado de `GET /api/tests/{id}` — confirmado contra producción real
/// (ikmfgrader.xyz) el 2026-10-25 con tests reales de distintos status
/// (1 Opened sin alumnos, 2 In Progress con alumnos/técnicas/resultados).
/// Devuelve el detalle completo: país, centro, alumnos, hasta ~176 técnicas
/// del curriculum y un resultado por técnica (uno por alumno una vez
/// calificado).
class TestCountry {
  TestCountry({required this.id, required this.name});
  final int id;
  final String name;

  factory TestCountry.fromJson(Map<String, dynamic> json) =>
      TestCountry(id: json['id'] as int, name: json['name'] as String? ?? '');
}

class TestCenter {
  TestCenter({required this.id, required this.name});
  final int id;
  final String name;

  factory TestCenter.fromJson(Map<String, dynamic> json) =>
      TestCenter(id: json['id'] as int, name: json['name'] as String? ?? '');
}

class TestStudent {
  TestStudent({
    required this.id,
    required this.testStudentId,
    required this.num,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.present,
    required this.levelName,
    required this.levelCode,
    required this.fail,
  });

  final int id;
  final int testStudentId;
  final int num;
  final String firstName;
  final String lastName;
  final String email;
  bool present;
  final String levelName;
  final String levelCode;
  final bool fail;

  String get fullName => '$firstName $lastName'.trim();

  factory TestStudent.fromJson(Map<String, dynamic> json) => TestStudent(
    id: json['id'] as int,
    testStudentId: json['testStudentId'] as int? ?? json['id'] as int,
    num: json['num'] as int? ?? 0,
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    present: json['present'] as bool? ?? true,
    levelName: json['levelName'] as String? ?? '',
    levelCode: json['levelCode'] as String? ?? '',
    fail: json['fail'] as bool? ?? false,
  );
}

/// Porteado de Ho enum (main.js:36056-36063): 3 estados posibles por
/// alumno/técnica. TOTAL_FAIL reprueba el test completo, FAIL es un "error"
/// puntual que exige elegir un "mistake" de la lista del curriculum.
enum TechniqueResultStatus { pass, fail, totalFail }

class TestMistake {
  TestMistake({required this.id, required this.name});
  final int id;
  final String name;

  factory TestMistake.fromJson(Map<String, dynamic> json) => TestMistake(
    id: json['id'] as int,
    name: _decodeHtmlEntities(json['name'] as String? ?? ''),
  );
}

class TestTechnique {
  TestTechnique({
    required this.id,
    required this.techniqueId,
    required this.name,
    required this.code,
    required this.score,
    required this.sort,
    required this.mistakes,
  });

  final int id;
  final int techniqueId;
  final String name;
  final String code;
  final double score;
  final int sort;
  final List<TestMistake> mistakes;

  factory TestTechnique.fromJson(Map<String, dynamic> json) => TestTechnique(
    id: json['id'] as int,
    techniqueId: json['techniqueId'] as int? ?? json['id'] as int,
    name: _decodeHtmlEntities(json['name'] as String? ?? ''),
    code: json['code'] as String? ?? '',
    score: (json['score'] as num?)?.toDouble() ?? 0,
    sort: json['sort'] as int? ?? 0,
    mistakes: (json['mistakes'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(TestMistake.fromJson)
        .toList(),
  );
}

/// Resultado de un alumno en una técnica, tal como lo devuelve el servidor
/// dentro de `GET /api/tests/{id}` -> `results`.
///
/// OJO, sin verificar contra el servidor real: la forma
/// `results:[{techniqueId, results:[{studentId, resultId, mistakeId, passed,
/// isFail, freeText}]}]` está inferida de cómo la lee el cliente Angular
/// original (main.js: `a.techniqueId`, `c.studentId`, `c.resultId`,
/// `c.passed`, `c.isFail`, `c.mistakeId`, `c.freeText`), porque el código
/// del servidor recuperado es de una versión más vieja que la que corre hoy.
/// Por eso el parseo es defensivo: lo que no entiende lo ignora.
class ServerResult {
  ServerResult({
    required this.techniqueId,
    required this.studentId,
    required this.status,
    this.resultId,
    this.mistakeId,
    this.freeText = '',
  });

  final int techniqueId;
  final int studentId;
  final int? resultId;
  final TechniqueResultStatus status;
  final int? mistakeId;
  final String freeText;

  static List<ServerResult> parseAll(dynamic raw) {
    if (raw is! List) return const [];
    final out = <ServerResult>[];
    for (final group in raw) {
      if (group is! Map) continue;
      final techniqueId = _asInt(group['techniqueId']);
      final items = group['results'];
      if (techniqueId == null || items is! List) continue;
      for (final item in items) {
        if (item is! Map) continue;
        final studentId = _asInt(item['studentId']);
        if (studentId == null) continue;
        final TechniqueResultStatus status;
        if (item['isFail'] == true) {
          status = TechniqueResultStatus.totalFail;
        } else if (item['passed'] == true) {
          status = TechniqueResultStatus.pass;
        } else if (item['passed'] == false) {
          status = TechniqueResultStatus.fail;
        } else {
          continue;
        }
        final mistakeId = _asInt(item['mistakeId']);
        out.add(
          ServerResult(
            techniqueId: techniqueId,
            studentId: studentId,
            resultId: _asInt(item['resultId']),
            status: status,
            mistakeId: (mistakeId == null || mistakeId == 0) ? null : mistakeId,
            freeText: (item['freeText'] as String?) ?? '',
          ),
        );
      }
    }
    return out;
  }
}

int? _asInt(dynamic v) => v == null ? null : int.tryParse(v.toString());

class TestDetail {
  TestDetail({
    required this.id,
    required this.name,
    required this.status,
    required this.country,
    required this.center,
    required this.students,
    required this.techniques,
    this.results = const [],
  });

  final int id;
  final String name;
  final int status; // 1 Opened, 2 In Progress, 3 Ended
  final TestCountry country;
  final TestCenter center;
  final List<TestStudent> students;
  final List<TestTechnique> techniques;
  final List<ServerResult> results;

  TestDetail copyWith({List<TestStudent>? students}) => TestDetail(
    id: id,
    name: name,
    status: status,
    country: country,
    center: center,
    students: students ?? this.students,
    techniques: techniques,
    results: results,
  );

  factory TestDetail.fromJson(Map<String, dynamic> json) => TestDetail(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    status: json['status'] as int? ?? 1,
    country: TestCountry.fromJson(
      json['country'] as Map<String, dynamic>? ?? const {},
    ),
    center: TestCenter.fromJson(
      json['center'] as Map<String, dynamic>? ?? const {},
    ),
    students: (json['students'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(TestStudent.fromJson)
        .toList(),
    techniques: (json['techniques'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(TestTechnique.fromJson)
        .toList(),
    results: ServerResult.parseAll(json['results']),
  );
}

class TestDetailRepository {
  TestDetailRepository(this._dio);
  final Dio _dio;

  Future<TestDetail> fetchTestDetail(int testId) async {
    final response = await _dio.get('/api/tests/$testId');
    return TestDetail.fromJson(response.data as Map<String, dynamic>);
  }
}
