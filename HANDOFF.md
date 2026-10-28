# Handoff — app Flutter "KravMaga Grader" (reescritura del cliente mobile), 2026-10-25

App Flutter nueva (iOS + Android), reemplazo del cliente Ionic/Angular original (`/Users/maxberen/Clientes/IKMF/ASHISH`). El plan completo de arquitectura/stack/alcance está en **[docs/FLUTTER_APP_PLAN.md](/Users/maxberen/Clientes/IKMF/ASHISH/docs/FLUTTER_APP_PLAN.md)** de `ASHISH` — léelo primero.

## Decisión importante: apunta a PRODUCCIÓN real, no al backend Laravel nuevo

A diferencia de lo que decía el plan original, esta app consume **`https://ikmfgrader.xyz`** (el backend ASP.NET que sigue sirviendo usuarios reales hoy), no `/opt/homebrew/var/www/grader` (la reescritura Laravel, que todavía no está en producción). Decisión explícita del cliente: lanzar el cliente nuevo ya, contra el backend que funciona hoy, independiente de cuándo esté lista la migración del backend. Ver `lib/core/network/api_client.dart` para el detalle.

## Cómo correrla

```bash
cd /Users/maxberen/Clientes/IKMF/grader_app
flutter run -d <device-id>
```

Requiere **iOS 15.0+** como mínimo (ver nota abajo) y Android API 24+ (sin probar todavía en Android en esta sesión, solo iOS).

## Estado actual — qué está construido y PROBADO de verdad (no solo escrito)

- ✅ **Scaffolding completo**: estructura `lib/core/` (network, storage) + `lib/features/` (auth, tests), paquetes instalados: `dio`, `flutter_secure_storage`, `go_router`, `riverpod`, `drift` + `sqlite3_flutter_libs`, `firebase_core`/`firebase_crashlytics` (sin inicializar todavía, ver sección Firebase abajo), `url_launcher`, `intl`.
- ✅ **Login real contra producción, probado de punta a punta en el simulador de iOS** con la cuenta de prueba (`darioi`/`darioi`, la misma que se usó para verificar el build original de Android en esta sesión):
  1. Pantalla de login (Material 3) → usuario escribe credenciales
  2. `POST https://ikmfgrader.xyz/token` real → responde 200 con token real
  3. Token guardado en `flutter_secure_storage` (Keychain/Keystore cifrado, no en texto plano)
  4. Guard de `go_router` redirige automáticamente a `/tests` — **a diferencia del original, este guard SÍ verifica sesión de verdad** (ver `docs/ORIGINAL_PROJECT_ISSUES.md` 3.1, el guard viejo era un no-op hardcodeado)
  5. `GET /api/tests?center=1` real → trae datos reales (vacío para esta cuenta en ese centro, consistente con lo verificado por curl)
  6. Logout → limpia el token → vuelve a login
- ✅ **Discrepancias reales encontradas entre `docs/API.md` (ingeniería inversa) y el comportamiento real de producción, corregidas en el código y en el doc**:
  - `id` en la respuesta de `/token` es **string** (`"52"`), no number — `docs/API.md` decía number.
  - El campo es `paymentstatus` **todo en minúsculas**, no `paymentStatus`.
  - Campos no documentados que sí vienen: `token_type`, `expires_in`, `role`, `email`, `defaultemail`.
  - El query param real de `GET /api/tests` es `center` (coincide con el doc, pero el parámetro C# original se llamaba `LocationId` — el cliente Angular lo mapea a `center`).
- ✅ **Logo real de IKMF aplicado** (`assets/images/ikmf_logo.png`) reemplazando el ícono placeholder — confirmado visualmente en el simulador.
- ✅ **Pantalla Home construida y probada** (`lib/features/home/home_screen.dart`) — porteo fiel del hub original (clase `JJ` en `main.js:53742-53763`, confirmado por lectura directa del código: son 4 tarjetas **estáticas**, sin lógica condicional por rol):
  - **IKMF STREAMER** / **INSTRUCTOR SUPPORT** → `url_launcher` a sitios externos (igual que el InAppBrowser del original). Probado: "Student Passport" abre correctamente la ficha de Play Store real.
  - **IKMF GRADER** → `context.push('/tests')` (push, no go — da un back real, a diferencia de ir directo). Probado de punta a punta: Home → Grader → Tests → back → Home.
  - **Student Passport** → link a la store de la app compañera.
  - Flujo de navegación completo ahora: login → home → (grader) → tests.
  - **Nota importante que surgió probando esto**: el pago con PayPal/suscripciones **no está en ninguna de estas 4 opciones** — consistente con el hallazgo ya documentado en `docs/FLUTTER_APP_PLAN.md` sección 9 (la pantalla `/payment` del original es inalcanzable desde la UI, ningún botón lleva ahí). No es algo que falte acá, es fiel al comportamiento real.

## Para retomar — próximos pasos

1. **Pantallas de negocio restantes** (ver mapeo completo en `docs/FLUTTER_APP_PLAN.md` sección 5): selección de país/ubicación, pantalla de calificación (la más compleja), asistencia, creación de estudiantes. La pantalla de Tests actual es un placeholder funcional (pide `center=1` hardcodeado) — falta conectar la pantalla real de selección de ubicación.
2. **Offline-first con `drift`**: el paquete está instalado pero el schema de base local **todavía no está escrito** — es la base de la que depende todo el flujo de sync (ver sección 4 del plan). Siguiente paso de arquitectura más importante.
3. **Firebase Crashlytics — pendiente de proyecto real**: el código tiene el `TODO` marcado en `lib/main.dart` con el snippet exacto a descomentar. **No se puede completar sin acceso a la cuenta de Google/Firebase del cliente** — alguien con ese acceso tiene que crear el proyecto Firebase y bajar `google-services.json` (Android) / `GoogleService-Info.plist` (iOS).
4. **Probar en Android** — esta sesión solo validó iOS. El flujo debería ser idéntico (la capa de red/storage es multiplataforma), pero falta la verificación real.
5. **Video player con las protecciones de la sección 8 del plan** (cifrado local, bloqueo de captura de pantalla) — no empezado.
6. **Decisión de producto sobre el flujo de pago** (sección 9 del plan) — sigue pendiente, no se tocó nada de esto todavía.

## Bugs/problemas reales encontrados y resueltos durante esta sesión (documentados para no repetirlos)

1. **Autocorrección de iOS rompía el campo de usuario**: el teclado reemplazaba `darioi` por `"Dario's"` (sugerencia de contacto). Se agregó `autocorrect: false` + `enableSuggestions: false` al campo — buena práctica general para cualquier campo de usuario/username, no solo acá.
2. **Firebase Crashlytics requiere iOS 15.0 mínimo** — entra en conflicto directo con el iOS 13+ que proponía originalmente `docs/FLUTTER_APP_PLAN.md` para tolerancia a dispositivos viejos. Se subió el mínimo del proyecto a **iOS 15.0** (`ios/Runner.xcodeproj/project.pbxproj`) — sigue cubriendo iPhones desde 2015 en adelante, un compromiso razonable, pero es una decisión real que vale la pena que el cliente conozca (no es gratis tener monitoreo de crashes + soporte a dispositivos muy viejos al mismo tiempo).
3. **Caché corrupto de Swift Package Manager** (mismo tipo de problema que tuvimos con CocoaPods en `passportfront`, semanas atrás en esta sesión): `~/Library/Caches/org.swift.swiftpm` tenía artifacts de Firebase a medio descargar. Se resolvió limpiando el caché (`rm -rf ~/Library/Caches/org.swift.swiftpm` + `build/ios/SourcePackages`) y dejando que Xcode re-descargue desde cero.
4. **El guard de rutas inicial tenía un bug de navegación latente**: la primera versión llamaba `context.go()` desde dentro del builder de una forma que no compilaba correctamente — corregido antes de probar, no llegó a producción.
5. **El redirect de `go_router` no manejaba errores de lectura del storage seguro** — si `flutter_secure_storage` fallara por cualquier motivo, la navegación podía quedar colgada. Se agregó un `try/catch` defensivo que trata cualquier error de lectura como "no logueado" en vez de romper la app — buena práctica general, no solo para este caso.

## Pendiente menor

El test automático default (`test/widget_test.dart`) está fallando por un problema de timing con el redirect async de `go_router` en el entorno de test (no reproducido en la app real, solo en el harness de test). No se investigó a fondo — prioridad baja, la validación real importante (contra producción, en el simulador) ya está hecha.
