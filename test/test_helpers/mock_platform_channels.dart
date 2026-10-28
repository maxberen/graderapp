import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mockea el MethodChannel real de flutter_secure_storage
/// ("plugins.it_nomads.com/flutter_secure_storage", confirmado leyendo el
/// plugin instalado — ver flutter_secure_storage_darwin-0.4.3) para que
/// cualquier widget que lea/escriba sesión durante el build no tire
/// MissingPluginException en los tests (no hay implementación nativa real
/// corriendo en `flutter test`, solo en un dispositivo/simulador).
///
/// Por defecto simula "no hay nada guardado" (todo `read` devuelve null) —
/// o sea, un usuario deslogueado. Llamar de nuevo con `values` para simular
/// una sesión ya guardada (ej. para testear pantallas que asumen login).
void mockSecureStorageChannel({Map<String, String> values = const {}}) {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestWidgetsFlutterBinding.ensureInitialized()
      .defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
    switch (call.method) {
      case 'read':
        final key = call.arguments['key'] as String;
        return values[key];
      case 'readAll':
        return values;
      case 'write':
      case 'delete':
      case 'deleteAll':
      case 'containsKey':
        return call.method == 'containsKey'
            ? values.containsKey(call.arguments['key'])
            : null;
      default:
        return null;
    }
  });
}
