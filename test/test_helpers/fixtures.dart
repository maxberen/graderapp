import 'package:grader_app/features/tests/test_detail_repository.dart';

/// Datos mock reutilizables para tests — moldeados sobre la forma REAL
/// confirmada contra /api/tests/{id} (ver HANDOFF.md), no inventada.
TestDetail fixtureTestDetail({
  int status = 2,
  List<TestStudent>? students,
  List<TestTechnique>? techniques,
}) {
  return TestDetail(
    id: 99999,
    name: 'Test de prueba',
    status: status,
    country: TestCountry(id: 136, name: 'Paraguay'),
    center: TestCenter(id: 76, name: 'PY-Asuncion'),
    students: students ??
        [
          TestStudent(
            id: 1,
            testStudentId: 1,
            num: 1,
            firstName: 'Juan',
            lastName: 'Perez',
            email: 'juan@example.com',
            present: true,
            levelName: 'Practitioner 1',
            levelCode: 'P1',
            fail: false,
          ),
        ],
    techniques: techniques ??
        [
          TestTechnique(
            id: 1,
            techniqueId: 1,
            name: 'Técnica de prueba',
            code: 'T1',
            score: 1.0,
            sort: 1,
            mistakes: [TestMistake(id: 1, name: 'Mistake de prueba')],
          ),
        ],
  );
}
