import 'package:dio/dio.dart';

import '../../core/storage/secure_storage.dart';

class LoginResult {
  LoginResult({
    required this.userId,
    required this.name,
    required this.paymentStatus,
  });

  final int userId;
  final String name;
  final String? paymentStatus;
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
}

/// Login OAuth2 Resource Owner Password Credentials contra `POST /token`
/// de producción — contrato exacto documentado en docs/API.md líneas 81-117
/// (grant_type=password, form-urlencoded, NO json). Probado contra el
/// servidor real.
class AuthRepository {
  AuthRepository(this._dio);
  final Dio _dio;

  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/token',
        data: {
          'grant_type': 'password',
          'username': username,
          'password': password,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['access_token'] as String;
      // OJO: la producción real devuelve "id" como STRING ("52"), no como
      // número — distinto de lo que decía docs/API.md (generado por
      // ingeniería inversa, no 100% preciso). Confirmado con un login real
      // contra ikmfgrader.xyz. Parseo defensivo por si algún día cambia.
      final userId = int.parse(data['id'].toString());
      final name = (data['name'] as String? ?? '').trim();
      final email = data['email'] as String?;

      await SecureStorage.instance.saveSession(
        token: token,
        userId: userId,
        userName: name,
        userEmail: email,
      );

      return LoginResult(
        userId: userId,
        name: name,
        // El campo real es "paymentstatus" en minúsculas, no "paymentStatus"
        // (otra discrepancia real vs. lo documentado, confirmada en vivo).
        paymentStatus: data['paymentstatus']?.toString(),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 || e.response?.statusCode == 401) {
        throw AuthException('Usuario o contraseña incorrectos.');
      }
      throw AuthException('No se pudo conectar al servidor. Revisá tu conexión.');
    }
  }

  Future<bool> get isLoggedIn async =>
      (await SecureStorage.instance.token) != null;

  Future<void> logout() => SecureStorage.instance.clear();

  /// Porteado de `GET /api/master/v2/forgetPassword?userName={email}` —
  /// contrato real documentado en docs/API.md líneas 157-173. Sin auth,
  /// sin body (GET con query param). No se cambió nada de este flujo —
  /// a diferencia del backend Laravel nuevo, donde sí corregimos el bug de
  /// reenviar la password real (ver docs/LARAVEL_BACKEND_PLAN.md sección
  /// 1.2) — esta app apunta a producción real, que sigue con el
  /// comportamiento original del servidor, fuera de nuestro control.
  Future<void> forgotPassword({required String email}) async {
    try {
      await _dio.get(
        '/api/master/v2/forgetPassword',
        queryParameters: {'userName': email},
      );
    } on DioException {
      throw AuthException('No se pudo enviar el email. Revisá tu conexión.');
    }
  }

  /// Porteado de `POST /api/users/enabledefaultemail` (main.js:29343-29349),
  /// usado por el ítem "Default Email" del Menu lateral real.
  Future<void> changeDefaultEmail({required String email}) async {
    try {
      await _dio.post(
        '/api/users/enabledefaultemail',
        data: {'Email': email, 'IsEnable': 1},
      );
      await SecureStorage.instance.saveDefaultEmail(email);
    } on DioException {
      throw AuthException('No se pudo guardar el email por defecto.');
    }
  }
}
