import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../auth/auth_repository.dart';
import '../attendance/attendance_screen.dart';
import '../curriculum/curriculum_screen.dart';
import '../tests/add_test_screen.dart';

/// Porteado del `ion-menu` lateral global real (main.js:35440-35498):
/// App, Home (solo role==1 — no verificado para otros roles, se muestra
/// siempre acá), Add Test, Attendance, Curriculum, Default Email (form),
/// Logout. Confirmado contra las capturas reales de producción enviadas
/// por el usuario. Add Test/Attendance/Curriculum todavía no tienen
/// pantalla propia en esta app — se avisa "Próximamente" en vez de fallar
/// en silencio.
class GraderMenuDrawer extends StatefulWidget {
  const GraderMenuDrawer({
    super.key,
    required this.onApp,
    required this.onHome,
    required this.onLogout,
  });

  /// "App" — vuelve al hub de 4 tarjetas (Home hub screen de esta app).
  final VoidCallback onApp;

  /// "Home" en el menú real abre la selección de país/centro de Tests.
  final VoidCallback onHome;

  final VoidCallback onLogout;

  @override
  State<GraderMenuDrawer> createState() => _GraderMenuDrawerState();
}

class _GraderMenuDrawerState extends State<GraderMenuDrawer> {
  final _authRepository = AuthRepository(ApiClient.instance.dio);
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    SecureStorage.instance.defaultEmail.then((email) {
      if (email != null && mounted) _emailController.text = email;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveDefaultEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _authRepository.changeDefaultEmail(email: _emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email por defecto guardado.')),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const DrawerHeader(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text('Menu', style: TextStyle(fontSize: 22)),
              ),
            ),
            ListTile(
              title: const Text('App'),
              onTap: () {
                Navigator.of(context).pop();
                widget.onApp();
              },
            ),
            ListTile(
              title: const Text('Home'),
              onTap: () {
                Navigator.of(context).pop();
                widget.onHome();
              },
            ),
            ListTile(
              title: const Text('Add Test'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddTestScreen()),
                );
              },
            ),
            ListTile(
              title: const Text('Attendance'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                );
              },
            ),
            ListTile(
              title: const Text('Curriculum'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CurriculumScreen()),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Form(
                key: _formKey,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Default Email',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Email inválido'
                            : null,
                      ),
                    ),
                    IconButton(
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      onPressed: _saving ? null : _saveDefaultEmail,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.of(context).pop();
                widget.onLogout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
