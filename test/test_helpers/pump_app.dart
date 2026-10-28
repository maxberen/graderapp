import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grader_app/main.dart';

import 'mock_platform_channels.dart';

/// Envuelve [child] en un MaterialApp con el theme REAL de la app (el mismo
/// que usa GraderApp en main.dart) y lo monta. Usar esto en vez de
/// `tester.pumpWidget(MaterialApp(home: ...))` a mano para que:
///  1) un futuro cambio de theme roto se detecte acá también, y
///  2) todas las pantallas que leen sesión (SecureStorage) durante el
///     build no exploten por falta de implementación nativa en el test.
///
/// Después de llamarla, revisar `tester.takeException()` — null significa
/// que el widget se construyó y layouteó sin tirar ninguna excepción (esto
/// es justo lo que habría atrapado el bug real de "Spacer dentro de un Wrap"
/// que encontramos probando a mano en el simulador).
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Map<String, String> secureStorageValues = const {},
}) async {
  mockSecureStorageChannel(values: secureStorageValues);
  await tester.pumpWidget(
    MaterialApp(
      theme: graderLightTheme(),
      home: child,
    ),
  );
}
