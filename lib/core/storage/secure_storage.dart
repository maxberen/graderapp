import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper fino sobre flutter_secure_storage — el token de sesión (Bearer)
/// nunca se guarda en SharedPreferences plano, siempre en el keychain/keystore
/// cifrado del SO. Es el reemplazo correcto del `localStorage` que usaba el
/// cliente Angular original (ver docs/API.md — ahí el token quedaba en
/// localStorage del WebView, sin cifrar).
class SecureStorage {
  SecureStorage._();
  static final instance = SecureStorage._();

  // El constructor default de AndroidOptions ya usa AES-GCM + RSA-OAEP vía
  // Android KeyStore (API 23+) — no hace falta ningún flag extra en esta
  // versión del paquete.
  final _storage = const FlutterSecureStorage();

  static const _tokenKey = 'access_token';
  static const _userIdKey = 'user_id';
  static const _userNameKey = 'user_name';
  static const _userEmailKey = 'user_email';
  static const _defaultEmailKey = 'default_email';

  Future<void> saveSession({
    required String token,
    required int userId,
    required String userName,
    String? userEmail,
  }) async {
    await Future.wait([
      _storage.write(key: _tokenKey, value: token),
      _storage.write(key: _userIdKey, value: userId.toString()),
      _storage.write(key: _userNameKey, value: userName),
      if (userEmail != null) _storage.write(key: _userEmailKey, value: userEmail),
    ]);
  }

  Future<String?> get token => _storage.read(key: _tokenKey);
  Future<String?> get userName => _storage.read(key: _userNameKey);
  Future<String?> get userEmail => _storage.read(key: _userEmailKey);
  Future<int?> get userId async {
    final raw = await _storage.read(key: _userIdKey);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> saveDefaultEmail(String email) =>
      _storage.write(key: _defaultEmailKey, value: email);
  Future<String?> get defaultEmail => _storage.read(key: _defaultEmailKey);

  Future<void> clear() => _storage.deleteAll();
}
