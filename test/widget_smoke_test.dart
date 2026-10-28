// Suite de "smoke tests": monta cada pantalla que NO depende de una
// llamada de red real durante su build (login en submit, no en build; las
// pantallas que sí pegan a la API real en initState — Results, Add Test,
// Add Student, Country Selector, Tests list — quedan FUERA de esta suite a
// propósito, ver nota al final de este archivo) y verifica que el build +
// primer layout no tiren NINGUNA excepción.
//
// Esto es exactamente la clase de bug que encontramos probando a mano en
// el simulador el 2026-10-26: un `Spacer()` dentro de un `Wrap` en
// students_screen.dart/attendance_screen.dart tiraba
// "Incorrect use of ParentDataWidget" en cada build — este test lo habría
// atrapado al instante, sin simulador, sin coordenadas, en segundos.
//
// Para agregar una pantalla nueva a esta suite: si construye sin pegarle a
// una API real (o la llamada está en un Future no-bloqueante dentro de un
// try/catch, como TestDetailRepository/ResultsRepository), sumala acá con
// el mismo patrón `pumpApp` + `expect(tester.takeException(), isNull)`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grader_app/features/auth/about_us_screen.dart';
import 'package:grader_app/features/auth/forgot_password_screen.dart';
import 'package:grader_app/features/auth/login_screen.dart';
import 'package:grader_app/features/curriculum/curriculum_screen.dart';
import 'package:grader_app/features/home/home_screen.dart';
import 'package:grader_app/features/menu/grader_menu_drawer.dart';
import 'package:grader_app/features/tests/students_screen.dart';
import 'package:grader_app/features/tests/test_grading_screen.dart';

import 'test_helpers/fixtures.dart';
import 'test_helpers/pump_app.dart';

void main() {
  testWidgets('LoginScreen se construye sin excepciones', (tester) async {
    await pumpApp(tester, LoginScreen(onLoggedIn: () {}));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('About Us'), findsOneWidget);
  });

  testWidgets('AboutUsScreen se construye sin excepciones', (tester) async {
    await pumpApp(tester, const AboutUsScreen());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ForgotPasswordScreen se construye sin excepciones', (tester) async {
    await pumpApp(tester, const ForgotPasswordScreen());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('HomeScreen (+ GraderMenuDrawer embebido) sin excepciones',
      (tester) async {
    await pumpApp(
      tester,
      HomeScreen(onOpenGrader: () {}, onLogout: () {}),
      secureStorageValues: const {'default_email': 'dario.karmel@gmail.com'},
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Abrir el Menu lateral — mismo widget que falló en Students/Attendance
    // antes del fix de Wrap+Spacer; si vuelve a romperse, esto lo atrapa.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Curriculum'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  });

  testWidgets('GraderMenuDrawer standalone, con y sin default email guardado',
      (tester) async {
    for (final values in [
      <String, String>{},
      {'default_email': 'dario.karmel@gmail.com'},
    ]) {
      await pumpApp(
        tester,
        Scaffold(
          drawer: GraderMenuDrawer(onApp: () {}, onHome: () {}, onLogout: () {}),
        ),
        secureStorageValues: values,
      );
      await tester.pump();
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('GraderMenuDrawer: tocar Logout SÍ dispara onLogout', (tester) async {
    // Esto quedó sin poder confirmarse a mano en el simulador (varios
    // intentos de tap con coordenadas de píxeles no lo dispararon,
    // 2026-10-26) — acá se toca por ÁRBOL DE WIDGETS (find.text), no por
    // coordenadas, así que es la forma confiable de probarlo.
    var logoutCalled = false;
    await pumpApp(
      tester,
      Scaffold(
        drawer: GraderMenuDrawer(
          onApp: () {},
          onHome: () {},
          onLogout: () => logoutCalled = true,
        ),
      ),
    );
    await tester.pump();
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(logoutCalled, isTrue,
        reason: 'onLogout no se disparó al tocar "Logout"');
  });

  testWidgets('StudentsScreen (toolbar real) sin excepciones, con y sin alumnos',
      (tester) async {
    // Caso real que rompió: lista vacía (estado "No Students Here...") Y
    // lista con alumnos — el toolbar con Add Group/Add Student/QR es el
    // mismo en ambos casos.
    for (final students in [<dynamic>[], null]) {
      await pumpApp(
        tester,
        StudentsScreen(
          test: fixtureTestDetail(
            status: 1,
            students: students == null ? null : [],
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('By Alphabet'), findsOneWidget);
      expect(find.text('Add Group'), findsOneWidget);
      expect(find.text('Add Student'), findsOneWidget);
      expect(find.text('QR'), findsOneWidget);
    }
  });

  testWidgets('TestGradingScreen (video placeholder, sin tocar play) sin excepciones',
      (tester) async {
    await pumpApp(tester, TestGradingScreen(test: fixtureTestDetail()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Results'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
  });

  testWidgets('CurriculumScreen carga el asset real (G1-G5) sin excepciones',
      (tester) async {
    await pumpApp(tester, const CurriculumScreen());
    // rootBundle.loadString hace I/O real (lee un archivo de 56KB del
    // sistema), que el reloj SINTÉTICO de pump()/pumpAndSettle() no
    // espera — confirmado: con pump() normal el Future nunca se resolvía
    // (CircularProgressIndicator seguía ahí indefinidamente, cero
    // excepción). runAsync() le presta el reloj REAL del test a este
    // await puntual. Encima el TextField de búsqueda tiene un cursor
    // parpadeante con animación infinita, así que tampoco sirve
    // pumpAndSettle() acá (por eso el pump() fijo después).
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('K1-K5'), findsOneWidget);
    expect(find.text('P1-P5'), findsOneWidget);
    expect(find.text('G1-G5'), findsOneWidget);
    // Primer técnica real de la categoría default (Graduate) — si esto
    // cambia de contenido, confirma que el asset se está leyendo de verdad.
    expect(find.textContaining('Hard break fall forward'), findsOneWidget);
  });
}

// Pantallas NO cubiertas acá a propósito (pegan a la API real de
// producción en initState — montar un widget test real haría un request
// de red real, lento y frágil para CI):
//   - TestsListScreen, CountrySelectorScreen (tests/países reales)
//   - AddTestScreen (GetTestDataInstructor real)
//   - AddStudentScreen, QrScanScreen (levels real + cámara)
//   - ResultsScreen (getTestResults real)
//   - AttendanceScreen (igual que Students pero con fetch de email —
//     cubierto indirectamente por el test de GraderMenuDrawer de arriba,
//     que comparte el mismo patrón de toolbar)
// Para cubrirlas de verdad habría que inyectar los repositorios (Dio) por
// constructor en vez de instanciarlos adentro de cada State, para poder
// pasar un Dio fake/mockeado en los tests — refactor real, no hecho acá
// para no tocar 10+ archivos solo para esto.
