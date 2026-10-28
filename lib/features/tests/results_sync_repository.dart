import 'package:dio/dio.dart';

import 'test_detail_repository.dart';

/// Resultado elegido por el instructor para un alumno en una técnica:
/// pass (check), fail (X) o totalFail (F). En fail/totalFail puede llevar un
/// "mistake" predeterminado, un texto libre, o ambos (igual que el original,
/// que guarda mistakeId y freeText juntos).
class GradedResult {
  const GradedResult({
    required this.status,
    this.mistakeId,
    this.freeText = '',
  });

  final TechniqueResultStatus status;
  final int? mistakeId;
  final String freeText;

  bool get isPass => status == TechniqueResultStatus.pass;

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'mistakeId': mistakeId,
    'freeText': freeText,
  };

  factory GradedResult.fromJson(Map<String, dynamic> json) => GradedResult(
    status: TechniqueResultStatus.values.byName(json['status'] as String),
    mistakeId: json['mistakeId'] as int?,
    freeText: (json['freeText'] as String?) ?? '',
  );
}

/// `POST /api/sync/SyncStudentsResults`. Mismo contrato que usa el cliente
/// Angular original (main.js ~37700, el armado del lote al sincronizar):
///
///  - `PASSED`: 1 si pasa, 0 si falla (X o F).
///  - `TEST_LEVEL_FAIL_ID`: el mistake elegido (0 si pasa o no hay).
///  - `FREE_TEXT`: el texto libre.
///  - `FAIL`: bandera de reprobación TOTAL del alumno (la "F"). El servidor
///    la copia a `km_test_student.FAIL` cada vez que viene con valor, así
///    que SOLO se manda cuando este cambio toca una F; si se mandara
///    `false` en cada resultado normal, cualquier check posterior le
///    borraría al alumno la reprobación total.
///  - `ID`: id del resultado ya guardado. Si viene, el servidor actualiza;
///    si no, inserta (y la tabla tiene clave única por test+alumno+técnica,
///    así que insertar dos veces lo mismo da error).
///
/// Se manda de a UN resultado por pedido a propósito: el servidor procesa el
/// lote de a uno y, si falla a mitad, responde error sin decir cuáles ya
/// guardó; reenviar el lote duplicaría esos. Con uno por pedido, cada
/// respuesta es inequívoca.
class ResultsSyncRepository {
  ResultsSyncRepository(this._dio);
  final Dio _dio;

  static Map<String, dynamic> buildItem({
    required int testId,
    required int testStudentId,
    required int techniqueId,
    required GradedResult result,
    int? resultId,
    bool? studentHardFail,
  }) {
    final isPass = result.isPass;
    final text = isPass ? '' : result.freeText;
    return {
      if (resultId != null) 'ID': resultId,
      'TESTID': testId,
      'TEST_STUDENT_ID': testStudentId,
      'LEVELID': techniqueId,
      'PASSED': isPass ? 1 : 0,
      'TEST_LEVEL_FAIL_ID': isPass ? 0 : (result.mistakeId ?? 0),
      'FREE_TEXT': text,
      'FAIL_FREE_TEXT': text,
      if (studentHardFail != null) 'FAIL': studentHardFail,
    };
  }

  Future<void> saveResult({
    required int testId,
    required int testStudentId,
    required int techniqueId,
    required GradedResult result,
    int? resultId,
    bool? studentHardFail,
  }) async {
    await _dio.post(
      '/api/sync/SyncStudentsResults',
      data: [
        buildItem(
          testId: testId,
          testStudentId: testStudentId,
          techniqueId: techniqueId,
          result: result,
          resultId: resultId,
          studentHardFail: studentHardFail,
        ),
      ],
    );
  }

  /// `POST /api/sync/SyncTestStatus` con `lastRow: true`: el servidor marca
  /// el test como finalizado. (El original, al terminar, además llama a
  /// `GET /api/sync/SendStudentsEmail/{id}` para mandar los resultados por
  /// email a los alumnos; eso NO se hace acá.)
  Future<void> finishTest(int testId) async {
    await _dio.post(
      '/api/sync/SyncTestStatus',
      data: {'TestId': testId, 'lastRow': true},
    );
  }
}
