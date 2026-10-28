import 'package:flutter_test/flutter_test.dart';
import 'package:grader_app/features/tests/add_student_repository.dart';
import 'package:grader_app/features/tests/qr_scan_screen.dart';

/// Testea el parseo del payload real de un QR de Student Passport
/// (`{name, last_name, email, grade: {id}, id}` — confirmado leyendo
/// addStudentQR() en main.js:45069-45079) SIN cámara ni simulador: esto es
/// justamente la parte de "qué pasa al escanear QR" que SÍ se puede
/// verificar en CI/automatizado, a diferencia de la UI de cámara en sí
/// (mobile_scanner necesita una cámara real — ver qr_scan_screen.dart).
void main() {
  final levels = [
    StudentLevel(id: 1, code: 'P1', name: 'Practitioner 1'),
    StudentLevel(id: 6, code: 'G1', name: 'Graduate 1'),
  ];

  test('parsea un QR válido de Student Passport', () {
    final student = parseStudentPassportQr(
      raw: '{"name":"Juan","last_name":"Perez","email":"juan@example.com","grade":{"id":1},"id":12345}',
      num: 1,
      levels: levels,
    );

    expect(student, isNotNull);
    expect(student!.firstName, 'Juan');
    expect(student.lastName, 'Perez');
    expect(student.email, 'juan@example.com');
    expect(student.levelCode, 'P1');
    expect(student.levelName, 'Practitioner 1');
    expect(student.present, isTrue);
    expect(student.testStudentId, 12345);
  });

  test('resuelve un nivel distinto (G1) correctamente', () {
    final student = parseStudentPassportQr(
      raw: '{"name":"Ana","last_name":"Gomez","email":"ana@example.com","grade":{"id":6},"id":999}',
      num: 2,
      levels: levels,
    );

    expect(student!.levelCode, 'G1');
  });

  test('devuelve null si el QR no es JSON válido', () {
    final student = parseStudentPassportQr(
      raw: 'esto no es json',
      num: 1,
      levels: levels,
    );
    expect(student, isNull);
  });

  test('devuelve null si falta un campo requerido (email)', () {
    final student = parseStudentPassportQr(
      raw: '{"name":"Juan","last_name":"Perez","grade":{"id":1},"id":1}',
      num: 1,
      levels: levels,
    );
    expect(student, isNull);
  });

  test('devuelve null si falta el campo grade', () {
    final student = parseStudentPassportQr(
      raw: '{"name":"Juan","last_name":"Perez","email":"juan@example.com","id":1}',
      num: 1,
      levels: levels,
    );
    expect(student, isNull);
  });

  test('si el nivel del QR no existe en la lista real, no revienta — queda vacío', () {
    final student = parseStudentPassportQr(
      raw: '{"name":"Juan","last_name":"Perez","email":"juan@example.com","grade":{"id":999},"id":1}',
      num: 1,
      levels: levels,
    );
    expect(student, isNotNull);
    expect(student!.levelCode, '');
    expect(student.levelName, '');
  });

  test('un QR que es JSON válido pero de otra forma (no un Student Passport) no revienta', () {
    final student = parseStudentPassportQr(
      raw: '{"foo":"bar"}',
      num: 1,
      levels: levels,
    );
    expect(student, isNull);
  });
}
