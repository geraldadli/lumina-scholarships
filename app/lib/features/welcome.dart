import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../main.dart';
import '../theme.dart';

/// Lumina mark from the prototype: navy rounded square with a white "L".
class LuminaLogo extends StatelessWidget {
  const LuminaLogo({super.key, this.size = 84});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: LColors.primary, borderRadius: BorderRadius.circular(size * 0.29)),
        child: Text(
          'L',
          style: TextStyle(fontSize: size * 0.57, height: 1, fontWeight: FontWeight.w700, color: LColors.bg),
        ),
      );
}

typedef _Logo = LuminaLogo;

/// Shown while Firebase restores the session and loads the profile; the router moves on.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _Logo(),
            SizedBox(height: 14),
            Text('Lumina', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('Scholarships, matched to you', style: TextStyle(fontSize: 15, color: LColors.text2)),
          ]),
        ),
      );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(children: [
            const Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                _Logo(),
                SizedBox(height: 14),
                Text('Lumina', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                SizedBox(
                  width: 270,
                  child: Text('Find scholarships that fit your profile, and get ready to apply.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: LColors.text2, height: 1.45)),
                ),
              ]),
            ),
            FilledButton.icon(
              onPressed: () => showToast(context, 'Google sign-in is coming soon. Use email for now.'),
              icon: const CircleAvatar(
                radius: 11,
                backgroundColor: LColors.bg,
                child: Text('G', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LColors.primary)),
              ),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.push('/email'),
              icon: const Icon(Symbols.mail),
              label: const Text('Continue with email'),
            ),
            const SizedBox(height: 12),
            const Text('By continuing you agree to the Terms and Privacy Policy.',
                style: TextStyle(fontSize: 12, color: LColors.text2)),
          ]),
        ),
      ),
    );
  }
}
