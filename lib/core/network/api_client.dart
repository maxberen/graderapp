import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../storage/secure_storage.dart';

/// Certificado raíz "Sectigo Public Server Authentication Root R46" (el que
/// firma la cadena real de ikmfgrader.xyz, confirmado con
/// `openssl s_client -connect ikmfgrader.xyz:443 -showcerts`) — self-signed,
/// vigente 2021-2046, ya confiado por macOS/iOS/navegadores modernos.
///
/// Se agrega EXPLÍCITAMENTE a los certificados confiables del cliente HTTP
/// (sin desactivar la validación de certificados) porque algunos Android sin
/// Google Mobile Services (confirmado en un Honor/Huawei real, Android 14,
/// sin GMS) no reciben las actualizaciones automáticas del almacén de raíces
/// de confianza que sí reciben los Android con Play Services — y esta raíz
/// de Sectigo, al ser relativamente nueva (2021), no está en su almacén del
/// sistema todavía. Sin esto: `HandshakeException: CERTIFICATE_VERIFY_FAILED:
/// unable to get local issuer certificate` en login y cualquier request real.
const String _kSectigoRootR46Pem = '''
-----BEGIN CERTIFICATE-----
MIIFijCCA3KgAwIBAgIQdY39i658BwD6qSWn4cetFDANBgkqhkiG9w0BAQwFADBf
MQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMTYwNAYDVQQD
Ey1TZWN0aWdvIFB1YmxpYyBTZXJ2ZXIgQXV0aGVudGljYXRpb24gUm9vdCBSNDYw
HhcNMjEwMzIyMDAwMDAwWhcNNDYwMzIxMjM1OTU5WjBfMQswCQYDVQQGEwJHQjEY
MBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMTYwNAYDVQQDEy1TZWN0aWdvIFB1Ymxp
YyBTZXJ2ZXIgQXV0aGVudGljYXRpb24gUm9vdCBSNDYwggIiMA0GCSqGSIb3DQEB
AQUAA4ICDwAwggIKAoICAQCTvtU2UnXYASOgHEdCSe5jtrch/cSV1UgrJnwUUxDa
ef0rty2k1Cz66jLdScK5vQ9IPXtamFSvnl0xdE8H/FAh3aTPaE8bEmNtJZlMKpnz
SDBh+oF8HqcIStw+KxwfGExxqjWMrfhu6DtK2eWUAtaJhBOqbchPM8xQljeSM9xf
iOefVNlI8JhD1mb9nxc4Q8UBUQvX4yMPFF1bFOdLvt30yNoDN9HWOaEhUTCDsG3X
ME6WW5HwcCSrv0WBZEMNvSE6Lzzpng3LILVCJ8zab5vuZDCQOc2TZYEhMbUjUDM3
IuM47fgxMMxF/mL50V0yeUKH32rMVhlATc6qu/m1dkmU8Sf4kaWD5QazYw6A3OAS
VYCmO2a0OYctyPDQ0RTp5A1NDvZdV3LFOxxHVp3i1fuBYYzMTYCQNFu31xR13NgE
SJ/AwSiItOkcyqex8Va3e0lMWeUgFaiEAin6OJRpmkkGj80feRQXEgyDet4fsZfu
+Zd4KKTIRJLpfSYFplhym3kT2BFfrsU4YjRosoYwjviQYZ4ybPUHNs2iTG7sijbt
8uaZFURww3y8nDnAtOFr94MlI1fZEoDlSfB1D++N6xybVCi0ITz8fAr/73trdf+L
HaAZBav6+CuBQug4urv7qv094PPK306Xlynt8xhW6aWWrL3DkJiy4Pmi1KZHQ3xt
zwIDAQABo0IwQDAdBgNVHQ4EFgQUVnNYZJX5khqwEioEYnmhQBWIIUkwDgYDVR0P
AQH/BAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQEMBQADggIBAC9c
mTz8Bl6MlC5w6tIyMY208FHVvArzZJ8HXtXBc2hkeqK5Duj5XYUtqDdFqij0lgVQ
YKlJfp/imTYpE0RHap1VIDzYm/EDMrraQKFz6oOht0SmDpkBm+S8f74TlH7Kph52
gDY9hAaLMyZlbcp+nv4fjFg4exqDsQ+8FxG75gbMY/qB8oFM2gsQa6H61SilzwZA
Fv97fRheORKkU55+MkIQpiGRqRxOF3yEvJ+M0ejf5lG5Nkc/kLnHvALcWxxPDkjB
JYOcCj+esQMzEhonrPcibCTRAUH4WAP+JWgiH5paPHxsnnVI84HxZmduTILA7rpX
DhjvLpr3Etiga+kFpaHpaPi8TD8SHkXoUsCjvxInebnMMTzD9joiFgOgyY9mpFui
TdaBJQbpdqQACj7LzTWb4OE4y2BThihCQRxEV+ioratF4yUQvNs+ZUH7G6aXD+u5
dHn5HrwdVw1Hr8Mvn4dGp+smWg9WY7ViYG4A++MnESLn/pmPNPW56MORcr3Ywx65
LvKRRFHQV80MNNVIIb/bE/FmJUNS0nAiNs2fxBx1IK1jcmMGDw4nztJqDby1ORrp
0XZ60Vzk50lJLVU3aPAaOpg+VBeHVOmmJ1CJeyAvP/+/oYtKR5j/K3tJPsMpRmAY
QqszKbrAKbkTidOIijlBO8n9pu0f9GBj39ItVQGL
-----END CERTIFICATE-----
''';

/// Base URL de PRODUCCIÓN REAL — a propósito, no apunta al backend Laravel
/// nuevo (`localhost:8003`). Esta app consume el backend ASP.NET que sigue
/// sirviendo usuarios reales en ikmfgrader.xyz, documentado end a end en
/// docs/API.md de ASHISH (verificado contra el código fuente real
/// recuperado — ver docs/LARAVEL_BACKEND_PLAN.md). Cuando el backend Laravel
/// reemplace a producción, este valor es lo único que hay que cambiar, y
/// solo si además cambian las rutas (hoy son distintas a propósito, ver
/// docs/LARAVEL_BACKEND_PLAN.md sección 3).
///
/// Se puede sobrescribir al compilar con `--dart-define=API_BASE_URL=...`
/// (ej. un servidor de mentira local) para probar flujos que ESCRIBEN datos,
/// como guardar resultados de un test, sin tocar producción. Sin el
/// define, el valor es siempre producción.
const String kProductionBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://ikmfgrader.xyz',
);

/// Cliente HTTP único de la app. Agrega el Bearer token automáticamente a
/// toda request a /api/*, igual que el HTTP Interceptor del cliente Angular
/// original (docs/API.md líneas 35-48) — mismo comportamiento, reescrito.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(BaseOptions(baseUrl: kProductionBaseUrl));
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final context = SecurityContext(withTrustedRoots: true);
        context.setTrustedCertificatesBytes(utf8.encode(_kSectigoRootR46Pem));
        return HttpClient(context: context);
      },
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Los endpoints de login (/token, /FBGoogle/token) y
          // forgetPassword NO llevan token — igual que el original.
          final isAuthEndpoint =
              options.path.contains('/token') ||
              options.path.contains('forgetPassword');

          if (!isAuthEndpoint) {
            final token = await SecureStorage.instance.token;
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }

          handler.next(options);
        },
        onError: (error, handler) {
          // TODO: reportar a Firebase Crashlytics acá una vez configurado
          // el proyecto real (ver HANDOFF.md — requiere acceso a la cuenta
          // de Google/Firebase del cliente, no se puede crear sin eso).
          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;

  Dio get dio => _dio;
}
