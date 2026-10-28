import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../auth/auth_repository.dart';
import '../menu/grader_menu_drawer.dart';

/// Porteado del hub "app" original (clase JJ en main.js:53742-53763) — 4
/// tarjetas estáticas, siempre visibles (no hay lógica condicional por rol
/// en la plantilla original, confirmado leyendo el código: decls=13, vars=0,
/// sin data-binding). "IKMF GRADER" es la única que queda dentro de esta
/// app — las otras tres eran InAppBrowser/enlaces externos en el original;
/// acá van por url_launcher (ver docs/FLUTTER_APP_PLAN.md sección 5, fila
/// "Menú / Home").
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenGrader,
    required this.onLogout,
  });

  final VoidCallback onOpenGrader;
  final VoidCallback onLogout;

  static const _streamerUrl =
      'https://streamer.kravmaga-ikmf.com/customer/account/login/';
  static const _supportUrl =
      'https://kravmaga-ikmf.com/login/?redirect_to=https%3A%2F%2Fkravmaga-ikmf.com%2F';
  static const _passportUrl =
      'https://play.google.com/store/apps/details?id=com.app.ikmfpassport';

  Future<void> _openExternal(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IKMF')),
      drawer: GraderMenuDrawer(
        onApp: () {},
        onHome: onOpenGrader,
        onLogout: () async {
          await AuthRepository(ApiClient.instance.dio).logout();
          onLogout();
        },
      ),
      body: SafeArea(
        child: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _HubCard(
              label: 'IKMF STREAMER',
              icon: Icons.ondemand_video,
              onTap: () => _openExternal(_streamerUrl),
            ),
            _HubCard(
              label: 'IKMF GRADER',
              icon: Icons.checklist,
              onTap: onOpenGrader,
              highlighted: true,
            ),
            _HubCard(
              label: 'INSTRUCTOR SUPPORT',
              icon: Icons.support_agent,
              onTap: () => _openExternal(_supportUrl),
            ),
            _HubCard(
              label: 'Student Passport',
              icon: Icons.badge_outlined,
              onTap: () => _openExternal(_passportUrl),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: highlighted ? 4 : 1,
      color: highlighted ? scheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: highlighted ? scheme.onPrimaryContainer : scheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
