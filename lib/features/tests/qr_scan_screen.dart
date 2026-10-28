import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/network/api_client.dart';
import 'add_student_repository.dart';
import 'test_detail_repository.dart';

/// Porteado de scanBarCode()/addStudentQR() (main.js:45530-45554, y
/// equivalentes en Attendance/Add Student) — el original usa el plugin
/// Cordova `cordova-plugin-qrscanner` con prompt "Scan QR code" y espera un
/// QR de Student Passport con JSON:
/// `{name, last_name, email, grade: {id}, id}`. Acá usamos `mobile_scanner`
/// (cámara real vía AVFoundation/CameraX) — funcionalmente equivalente,
/// mismo contrato de datos.
///
/// OJO: el Simulador de iOS no tiene cámara física, así que esta pantalla
/// no se puede probar escaneando de verdad ahí — solo en un dispositivo
/// real o el emulador de Android con cámara virtual. El parseo del payload
/// (la parte que sí se puede romper con datos reales) tiene su propio test
/// unitario en test/features/tests/qr_payload_test.dart.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, required this.nextNum});

  final int nextNum;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

/// Parsea el payload real de un QR de Student Passport. Separado de la UI
/// para poder testearlo sin cámara ni simulador.
TestStudent? parseStudentPassportQr({
  required String raw,
  required int num,
  required List<StudentLevel> levels,
}) {
  final Map<String, dynamic> data;
  try {
    data = jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }

  final name = data['name'] as String?;
  final lastName = data['last_name'] as String?;
  final email = data['email'] as String?;
  final grade = data['grade'] as Map<String, dynamic>?;
  final gradeId = grade?['id'];
  final qrId = data['id'];

  if (name == null || lastName == null || email == null || gradeId == null) {
    return null;
  }

  final level = levels.where((l) => l.id == gradeId).firstOrNull;

  return TestStudent(
    id: qrId is int ? qrId : int.tryParse(qrId.toString()) ?? -num,
    testStudentId: qrId is int ? qrId : 0,
    num: num,
    firstName: name,
    lastName: lastName,
    email: email,
    present: true,
    levelName: level?.name ?? '',
    levelCode: level?.code ?? '',
    fail: false,
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  final _levelsRepository = LevelsRepository(ApiClient.instance.dio);
  bool _handling = false;
  String? _error;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    setState(() => _handling = true);
    try {
      final levels = await _levelsRepository.fetchLevels();
      final student = parseStudentPassportQr(
        raw: raw,
        num: widget.nextNum,
        levels: levels,
      );
      if (student == null) {
        setState(() => _error = 'QR inválido — no es un Student Passport.');
        await Future.delayed(const Duration(seconds: 2));
        setState(() => _error = null);
      } else if (mounted) {
        Navigator.of(context).pop(student);
      }
    } finally {
      if (mounted) setState(() => _handling = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR code')),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          if (_handling)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black38,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Material(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
