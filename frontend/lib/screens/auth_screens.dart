import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../data/backend.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/layout.dart';
import '../widgets/loading.dart';

class DemoModeBanner extends StatelessWidget {
  const DemoModeBanner({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: LColors.white,
          borderRadius: BorderRadius.circular(L.r(12)),
          border: Border.all(color: LColors.line),
        ),
        child: Row(
          children: [
            Icon(Icons.science_outlined, size: 18, color: LColors.text2),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                kIsWeb
                    ? 'Demo mode: sample data only. Reloading the page starts over.'
                    : 'Demo mode: Firebase is not configured, so data stays on this phone.',
                style: ts(13, color: LColors.text2, height: 1.4),
              ),
            ),
          ],
        ),
      );
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _busy = false;

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await AppScope.read(context).backend.signInWithGoogle();
    } on AuthFailure catch (e) {
      if (mounted && !e.cancelled) showToast(context, e.message, icon: Icons.error_outline_rounded);
    } on Object catch (e) {
      debugPrint('Lumina: Google sign-in failed: $e');
      if (mounted) showToast(context, 'Google sign-in failed. Try again.', icon: Icons.error_outline_rounded);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _email() {
    final backend = AppScope.read(context).backend;
    if (backend.isDemo) {
      backend.signInWithEmail('', '');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EmailSignInScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final demo = AppScope.of(context).backend.isDemo;
    return Scaffold(
      body: SafeArea(
        child: Gutter(
          maxWidth: 420,
          min: 24,
          builder: (context, side) => LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(side, 24, side, 24),
              child: ConstrainedBox(
                // Logo in the middle and buttons at the bottom; scrolls when it cannot fit.
                constraints: BoxConstraints(minHeight: box.maxHeight - 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(),
                    Column(
                      children: [
                        const LuminaLogo(),
                        const SizedBox(height: 18),
                        Text('Lumina', style: ts(32, weight: FontWeight.w700, spacing: -0.6)),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Text(
                            'Find scholarships that fit your profile, and get ready to apply.',
                            textAlign: TextAlign.center,
                            style: ts(17, color: LColors.text2, height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (demo) ...[const DemoModeBanner(), const SizedBox(height: 14)],
                        LButton(
                          label: 'Continue with Google',
                          height: 54,
                          fontSize: 16,
                          busy: _busy,
                          leading: Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: LColors.bg, shape: BoxShape.circle),
                            child: Text('G', style: ts(14, weight: FontWeight.w700, color: LColors.primary)),
                          ),
                          onPressed: _google,
                        ),
                        const SizedBox(height: 10),
                        LButton(
                          label: 'Continue with email',
                          kind: LButtonKind.secondary,
                          icon: Icons.mail_outline_rounded,
                          height: 54,
                          fontSize: 16,
                          onPressed: _busy ? null : _email,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'By continuing you agree to the Terms and Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: ts(13, color: LColors.text2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EmailSignInScreen extends StatefulWidget {
  const EmailSignInScreen({super.key});

  @override
  State<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends State<EmailSignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _create = false;
  bool _busy = false;
  String? _error;

  /// Confirmation after a reset email was requested.
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() {
        _info = null;
        _error = 'Enter your email above, then tap "Forgot password?" again.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await AppScope.read(context).backend.sendPasswordReset(email);
      // Same wording whether or not the account exists, so emails can't be probed.
      if (mounted) setState(() => _info = 'If an account uses $email, a reset link is on its way. Check your inbox and spam.');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object catch (e) {
      debugPrint('Lumina: password reset failed: $e');
      if (mounted) setState(() => _error = 'Could not send the reset email. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final backend = AppScope.read(context).backend;
    final nav = Navigator.of(context);
    try {
      if (_create) {
        await backend.createAccountWithEmail(_email.text, _password.text);
      } else {
        await backend.signInWithEmail(_email.text, _password.text);
      }
      // The root gate swaps to onboarding / home; drop this page.
      if (mounted) nav.popUntil((r) => r.isFirst);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              LHeader(title: _create ? 'Create account' : 'Sign in with email', border: false),
              Expanded(
                child: Form(
                  key: _form,
                  child: Gutter(
                    builder: (context, side) => ListView(
                      padding: EdgeInsets.fromLTRB(side, 12, side, 20),
                      children: [
                        LField(
                          label: 'Email',
                          child: TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: lInputDecoration(hint: 'you@example.com'),
                            validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email.',
                          ),
                        ),
                        const SizedBox(height: 18),
                        LField(
                          label: 'Password',
                          child: TextFormField(
                            controller: _password,
                            obscureText: true,
                            autofillHints: [_create ? AutofillHints.newPassword : AutofillHints.password],
                            decoration: lInputDecoration(hint: 'At least 6 characters'),
                            validator: (v) => (v ?? '').length >= 6 ? null : 'Use at least 6 characters.',
                            onFieldSubmitted: (_) => _submit(),
                          ),
                        ),
                        if (!_create)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy ? null : _sendReset,
                              child: Text('Forgot password?', style: ts(14, weight: FontWeight.w600, color: LColors.primary)),
                            ),
                          ),
                        if (_info != null) ...[
                          const SizedBox(height: 6),
                          Text(_info!, style: ts(14, color: LColors.text2, height: 1.4)),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(_error!, style: ts(14, color: LColors.danger, height: 1.4)),
                        ],
                        const SizedBox(height: 24),
                        LButton(label: _create ? 'Create account' : 'Sign in', busy: _busy, onPressed: _submit),
                        const SizedBox(height: 8),
                        LButton(
                          label: _create ? 'I already have an account' : 'Create a new account',
                          kind: LButtonKind.ghost,
                          onPressed: () => setState(() {
                            _create = !_create;
                            _error = null;
                            _info = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
