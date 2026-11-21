import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import 'welcome.dart';

/// "Continue with email": sign in, create account, or reset the password.
/// After success the router (authStateChanges) moves to onboarding or Home.
class EmailSignInScreen extends StatefulWidget {
  const EmailSignInScreen({super.key});
  @override
  State<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends State<EmailSignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _create = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final state = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _create
          ? await state.signUp(_email.text, _password.text)
          : await state.signIn(_email.text, _password.text);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = authMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_email.text.contains('@')) {
      setState(() => _error = 'Enter your email above first.');
      return;
    }
    try {
      await AppScope.of(context).resetPassword(_email.text);
      if (mounted) showToast(context, 'Password reset email sent to ${_email.text.trim()}');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = authMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
            const Align(alignment: Alignment.centerLeft, child: LuminaLogo(size: 56)),
            const SizedBox(height: 20),
            SectionTitle(
              _create ? 'Create your account' : 'Sign in with email',
              subtitle: _create
                  ? 'Your profile and saved scholarships are kept in your account.'
                  : 'Welcome back. Pick up where you left off.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(hintText: 'Email'),
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: [_create ? AutofillHints.newPassword : AutofillHints.password],
              decoration: InputDecoration(
                hintText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: LColors.bg))
                  : Text(_create ? 'Create account' : 'Sign in'),
            ),
            if (!_create)
              TextButton(onPressed: _busy ? null : _reset, child: const Text('Forgot password?')),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => setState(() {
                _create = !_create;
                _error = null;
              }),
              child: Text(_create ? 'I already have an account' : 'New to Lumina? Create an account'),
            ),
          ]),
        ),
      ),
    );
  }
}

String authMessage(FirebaseAuthException e) => switch (e.code) {
      'invalid-credential' || 'wrong-password' || 'user-not-found' => 'Email or password is incorrect.',
      'email-already-in-use' => 'An account with this email already exists. Sign in instead.',
      'invalid-email' => 'That email address is not valid.',
      'weak-password' => 'Choose a stronger password (at least 6 characters).',
      'too-many-requests' => 'Too many attempts. Try again in a few minutes.',
      'network-request-failed' => 'No internet connection.',
      'operation-not-allowed' => 'Email sign-in is not enabled for this Firebase project yet. Ask the project owner.',
      _ => e.message ?? 'Something went wrong (${e.code}).',
    };
