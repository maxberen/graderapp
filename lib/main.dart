import 'package:flutter/material.dart';

import 'app_router.dart';
import 'features/tests/results_outbox.dart';

// TODO(firebase): inicializar Crashlytics acá una vez que exista un
// proyecto Firebase real para esta app (requiere acceso a la cuenta de
// Google/Firebase del cliente — no se puede crear sin eso). Cuando esté
// listo, agregar:
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
//   PlatformDispatcher.instance.onError = (error, stack) {
//     FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
//     return true;
//   };
// Ver docs/FLUTTER_APP_PLAN.md sección 7 y HANDOFF.md de este proyecto.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Carga la cola de resultados pendientes y sube lo que haya quedado.
  await ResultsSyncEngine.instance.start();
  runApp(const GraderApp());
}

// Paleta de marca en negro/gris en vez del rojo/rosado del original (pedido
// explícito del usuario). OJO: ColorScheme.fromSeed(seedColor: Colors.grey...)
// NO da gris puro — el algoritmo tonal de Material 3 (HCT) igual le mete
// matiz (probado en vivo: salió celeste/teal) — por eso acá el ColorScheme
// se arma a mano con grises reales, sin pasar por fromSeed. El rojo se
// mantiene SOLO como color funcional de Fail/Mistake en el wizard de
// calificación (ver test_grading_screen.dart y results_screen.dart) — ahí
// no es "marca", es semántico.
//
// Expuesto como función (no inline en build()) para que los tests puedan
// envolver widgets con el mismo theme real — ver test/test_helpers/pump_app.dart.
ThemeData graderLightTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF2B2B2B),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE0E0E0),
    onPrimaryContainer: Color(0xFF1A1A1A),
    secondary: Color(0xFF5A5A5A),
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: Color(0xFF1A1A1A),
    surfaceContainerHighest: Color(0xFFEDEDED),
    error: Color(0xFFB61317),
    onError: Colors.white,
  ),
);

ThemeData graderDarkTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFFD0D0D0),
    onPrimary: Color(0xFF1A1A1A),
    primaryContainer: Color(0xFF3A3A3A),
    onPrimaryContainer: Colors.white,
    secondary: Color(0xFFBDBDBD),
    onSecondary: Color(0xFF1A1A1A),
    surface: Color(0xFF121212),
    onSurface: Colors.white,
    surfaceContainerHighest: Color(0xFF2A2A2A),
    error: Color(0xFFB61317),
    onError: Colors.white,
  ),
);

class GraderApp extends StatelessWidget {
  const GraderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter();

    return MaterialApp.router(
      title: 'KravMaga Grader',
      debugShowCheckedModeBanner: false,
      theme: graderLightTheme(),
      darkTheme: graderDarkTheme(),
      routerConfig: router,
    );
  }
}
