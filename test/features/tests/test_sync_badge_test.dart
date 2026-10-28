import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grader_app/features/tests/results_outbox.dart';
import 'package:grader_app/features/tests/results_sync_repository.dart';
import 'package:grader_app/features/tests/test_detail_repository.dart';
import 'package:grader_app/features/tests/tests_list_screen.dart';

void main() {
  test('isTestSynced: pendiente o cierre pedido = no sincronizado', () {
    final o = ResultsOutbox();
    expect(isTestSynced(7, o), isTrue);
    o.put(
      testId: 7, techniqueId: 1, studentId: 1, testStudentId: 11,
      result: const GradedResult(status: TechniqueResultStatus.pass),
    );
    expect(isTestSynced(7, o), isFalse);
    expect(isTestSynced(8, o), isTrue, reason: 'otro test no se afecta');
    o.markSynced(o.get(7, 1, 1)!, 1);
    expect(isTestSynced(7, o), isTrue);
    o.requestClose(7);
    expect(isTestSynced(7, o), isFalse);
    o.markClosed(7);
    expect(isTestSynced(7, o), isTrue);
  });

  testWidgets('TestSyncBadge muestra tilde o cruz', (tester) async {
    for (final synced in [true, false]) {
      await tester.pumpWidget(MaterialApp(home: TestSyncBadge(synced: synced)));
      expect(find.byIcon(synced ? Icons.check : Icons.close), findsOneWidget);
    }
  });
}
