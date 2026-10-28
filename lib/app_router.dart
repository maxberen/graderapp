import 'package:go_router/go_router.dart';

import 'core/network/api_client.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/tests/tests_list_screen.dart';

/// A diferencia del original (ver docs/ORIGINAL_PROJECT_ISSUES.md 3.1 — el
/// guard `wu.canActivate` del cliente Angular en realidad NO verificaba
/// sesión, era un no-op hardcodeado a `true`), acá el guard es real: lee el
/// token del storage seguro y redirige a /login si no existe.
///
/// Flujo: login -> home (hub de 4 opciones, porteado de la clase JJ del
/// original) -> tests (solo al tocar "IKMF GRADER"). Las otras 3 opciones
/// del hub abren navegador externo, no son rutas de esta app — ver
/// HomeScreen.
GoRouter buildRouter() {
  final authRepository = AuthRepository(ApiClient.instance.dio);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      // Defensivo: si falla la lectura del storage seguro (plataforma no
      // disponible, error de keychain, etc.) se trata como "no logueado"
      // en vez de romper la navegación — nunca debe dejar al usuario en una
      // pantalla en blanco.
      bool loggedIn;
      try {
        loggedIn = await authRepository.isLoggedIn;
      } catch (_) {
        loggedIn = false;
      }
      final loggingIn = state.matchedLocation == '/login';

      if (!loggedIn && !loggingIn) return '/login';
      if (loggedIn && loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          onLoggedIn: () => context.go('/home'),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => HomeScreen(
          // push (no go): Tests queda arriba de Home en el stack, así el
          // usuario tiene un back real para volver al hub de 4 opciones.
          onOpenGrader: () => context.push('/tests'),
          onLogout: () => context.go('/login'),
        ),
      ),
      GoRoute(
        path: '/tests',
        builder: (context, state) => TestsListScreen(
          onLogout: () => context.go('/login'),
        ),
      ),
    ],
  );
}
