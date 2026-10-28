import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Porteado 1:1 del contenido real de app-about-us (main.js:46062-46143).
/// El texto es contenido propio de IKMF (no de terceros) — se reproduce
/// textual, es la copia legal/institucional real de la empresa dueña de
/// esta app, no un texto inventado.
class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  static const _privacyPolicyUrl = 'https://kravmaga-ikmf.com/privacy-policy/';

  Future<void> _openPrivacyPolicy() async {
    await launchUrl(Uri.parse(_privacyPolicyUrl), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium;

    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This mobile application was developed by Contact IKMF LTD for '
                'active IKMF instructors only, as a first class teaching tool '
                'that shows you how to perform a technique, using a '
                'demonstration video on demand, providing the tester with '
                'checkpoints to examine in each technique.',
                style: textStyle,
              ),
              const SizedBox(height: 16),
              Text(
                'Moreover, the system provides an immediate feedback to the '
                'student as well as the instructor.',
                style: textStyle,
              ),
              const SizedBox(height: 16),
              Text(
                'The Purpose of this Application is to create a unified '
                'Testing eco system among global testers and instructors '
                'ensuring all tests are conducted under the same criterions. '
                'The IKMF testing app enables a direct access to the official '
                'IKMF Curriculum for learning and training purposes.',
                style: textStyle,
              ),
              const SizedBox(height: 16),
              Text(
                'As known, Krav Maga is a self-defense fighting system that '
                'adapts and updated according to the dangers one faces. Using '
                'this technology allows the IKMF to update the instructor '
                'about every change in the curriculum or other professional '
                'updates. Also, the app provides access to the Krav Maga '
                'streamer and other instructor support materials.',
                style: textStyle,
              ),
              const SizedBox(height: 16),
              Text(
                'Upon payment you will receive full access to IKMF Streamer '
                'and once IKMF HQ confirms your IKMF instructor status you '
                'will receive full access to the grading system as well as '
                'support materials.',
                style: textStyle,
              ),
              const SizedBox(height: 16),
              Text('Notes:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'This product and videos will be available for use as long '
                'as you are an active IKMF instructor. No refunds will be '
                'issued if you are no longer an active IKMF instructor.',
                style: textStyle,
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _openPrivacyPolicy,
                child: Text(
                  'Privacy policy',
                  style: textStyle?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'If you have any questions, please contact IKMF HQ at;',
                style: textStyle,
              ),
              const SizedBox(height: 4),
              const SelectableText('hq@kravmaga.co.il'),
              const SizedBox(height: 16),
              Text('Good luck,', style: textStyle),
              Text('Avi Moyal', style: textStyle),
              Text('IKMF Chairman and Head instructor', style: textStyle),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('LOGIN'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
