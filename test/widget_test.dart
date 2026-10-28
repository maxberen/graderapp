import 'package:flutter_test/flutter_test.dart';

import 'package:grader_app/main.dart';

import 'test_helpers/mock_platform_channels.dart';

void main() {
  testWidgets('App arranca deslogueada y muestra la pantalla de login',
      (tester) async {
    // Sin esto, go_router's redirect (que lee la sesión vía
    // AuthRepository.isLoggedIn en el primer frame) tira
    // MissingPluginException porque no hay implementación nativa real de
    // flutter_secure_storage corriendo en `flutter test` — causa real de
    // que este test estuviera roto antes.
    mockSecureStorageChannel();

    await tester.pumpWidget(const GraderApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Grader'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
