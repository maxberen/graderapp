import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:grader_app/features/tests/results_outbox.dart';
import 'package:grader_app/features/tests/results_sync_repository.dart';
import 'package:grader_app/features/tests/test_detail_repository.dart';
import 'package:grader_app/features/tests/test_grading_screen.dart';

import '../../test_helpers/fixtures.dart';
import '../../test_helpers/pump_app.dart';

/// No sincroniza: acá solo se prueba la pantalla y lo que deja en la cola.
class _IdleEngine extends ResultsSyncEngine {
  _IdleEngine(ResultsOutbox outbox)
    : super(
        outbox: outbox,
        repository: ResultsSyncRepository(Dio()),
        fetchDetail: (_) async => throw UnimplementedError(),
      );

  @override
  void kick() {}
}

void main() {
  late ResultsOutbox outbox;
  late ResultsSyncEngine engine;

  setUp(() {
    outbox = ResultsOutbox();
    // Sin servidor: el engine no se arranca; solo se prueba lo local.
    engine = _IdleEngine(outbox);
  });

  tearDown(() => engine.dispose());

  Future<void> open(WidgetTester tester) async {
    await pumpApp(
      tester,
      TestGradingScreen(
        test: fixtureTestDetail(),
        outbox: outbox,
        engine: engine,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('student-1')));
    await tester.pumpAndSettle();
  }

  testWidgets('check se guarda al toque, sin SAVE', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('result-pass')));
    await tester.pumpAndSettle();
    final e = outbox.get(99999, 1, 1)!;
    expect(e.result.status, TechniqueResultStatus.pass);
    expect(e.dirty, isTrue);
  });

  for (final k in ['result-fail', 'result-total-fail']) {
    testWidgets('$k: elegir un error predeterminado guarda con un toque', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(Key(k)));
      await tester.pumpAndSettle();
      expect(outbox.get(99999, 1, 1), isNull, reason: 'aún no se guardó');
      await tester.tap(find.byKey(const Key('mistake-1')));
      await tester.pumpAndSettle();
      final e = outbox.get(99999, 1, 1)!;
      expect(e.result.mistakeId, 1);
      expect(
        e.result.status,
        k == 'result-fail'
            ? TechniqueResultStatus.fail
            : TechniqueResultStatus.totalFail,
      );
    });

    testWidgets('$k: el texto libre solo se guarda con su SAVE', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(Key(k)));
      await tester.pumpAndSettle();
      final save = find.byKey(const Key('free-text-save'));
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.enterText(
        find.byKey(const Key('free-text')),
        'mala guardia',
      );
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(outbox.get(99999, 1, 1)!.result.freeText, 'mala guardia');
    });
  }

  testWidgets('el estado pendiente se ve en pantalla', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('result-pass')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sync-status')), findsOneWidget);
    expect(find.textContaining('1'), findsWidgets);
  });

  testWidgets('en la última técnica, NEXT pasa a ser RESULTS', (tester) async {
    await pumpApp(
      tester,
      TestGradingScreen(
        test: fixtureTestDetail(),
        outbox: outbox,
        engine: engine,
      ),
    );
    // El fixture tiene una sola técnica: ya es la última.
    expect(find.text('RESULTS'), findsOneWidget);
    expect(find.text('NEXT'), findsNothing);
  });

  testWidgets('con el cierre pedido no se puede calificar; al cancelar sí',
      (tester) async {
    outbox.requestClose(99999);
    await open(tester);
    expect(find.byKey(const Key('result-pass')), findsNothing);
    expect(find.textContaining('grading is locked'), findsOneWidget);
    outbox.cancelClose(99999);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.tap(find.byKey(const ValueKey('student-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('result-pass')), findsOneWidget);
  });
}
