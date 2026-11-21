import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'detail.dart';
import 'email_sign_in.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.profile;

    Widget row(IconData icon, String title, String value, VoidCallback onTap) => ListTile(
          leading: Icon(icon, color: LColors.primary),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: LColors.text2)),
          trailing: const Icon(Symbols.chevron_right, color: LColors.muted),
          onTap: onTap,
        );

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
          const Text('Profile', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          LCard(
            child: Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: LColors.soft,
                child: Text(p.displayName.isEmpty ? '?' : p.displayName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: LColors.primary)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.displayName.isEmpty ? 'Student' : p.displayName,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Profile completeness ${(p.completeness * 100).round()}%',
                      style: const TextStyle(fontSize: 13, color: LColors.text2)),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: p.completeness, color: LColors.primary, backgroundColor: LColors.soft),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          LCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              row(Symbols.person, 'About you',
                  [p.citizenship, p.currentEducationLevel].whereType<String>()
                      .map((v) => v.length == 2 ? countryName(v) : levelName(v)).join(' · '),
                  () => context.push('/edit/0')),
              row(Symbols.flag, 'Study goals',
                  [if (p.educationLevel != null) levelName(p.educationLevel!), ...p.fieldsOfStudy].join(' · '),
                  () => context.push('/edit/1')),
              row(Symbols.school, 'Academics', p.gpa == null ? 'Not set' : 'GPA ${p.gpa}',
                  () => context.push('/edit/2')),
              row(Symbols.shield_lock, 'Privacy & AI', p.cloudAiAllowed ? 'Cloud AI allowed' : 'On-device only',
                  () => context.push('/edit/3')),
              row(Symbols.info, 'About & data sources', 'How data is verified', () => context.go('/profile/about')),
            ]),
          ),
          const SizedBox(height: 16),
          if (state.user?.email != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Signed in as ${state.user!.email}',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: LColors.text2)),
            ),
          OutlinedButton(onPressed: state.signOut, child: const Text('Sign out')),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _deleteAccount(context),
            child: const Text('Delete account', style: TextStyle(color: Color(0xFFB3261E))),
          ),
        ]),
      ),
    );
  }
}

Future<void> _deleteAccount(BuildContext context) async {
  final state = AppScope.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete account?'),
      content: const Text('This permanently deletes your profile, saved scholarships and checklists.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await state.deleteAccount();
  } on FirebaseAuthException catch (e) {
    if (e.code != 'requires-recent-login' || !context.mounted) {
      if (context.mounted) showToast(context, authMessage(e));
      return;
    }
    // Firebase needs a fresh sign-in before deleting: ask for the password once.
    final ctrl = TextEditingController();
    final pw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm your password'),
        content: TextField(controller: ctrl, obscureText: true, decoration: const InputDecoration(hintText: 'Password')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Delete')),
        ],
      ),
    );
    if (pw == null || pw.isEmpty) return;
    try {
      await state.deleteAccount(password: pw);
    } on FirebaseAuthException catch (e) {
      if (context.mounted) showToast(context, authMessage(e));
    }
  } catch (_) {
    if (context.mounted) showToast(context, 'Could not delete your account. Check your connection.');
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About & data sources', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        const Text('How data is verified', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
          'Every scholarship comes from its official website. Our research team checks each record, and the backend '
          'watches the official pages for changes. Records not yet checked by a person are labelled "Not yet verified". '
          'Always confirm details on the official website before applying.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 24),
        const Text('Official sources', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final s in state.scholarships)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(s.sourceHost, style: const TextStyle(fontSize: 12, color: LColors.text2)),
            trailing: const Icon(Symbols.open_in_new, size: 18),
            onTap: () => openOfficial(context, s.sourceUrl),
          ),
        const Divider(height: 32),
        const ListTile(contentPadding: EdgeInsets.zero, title: Text('App version'), trailing: Text('1.0.0 (1)')),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Licenses'),
          trailing: const Icon(Symbols.chevron_right),
          onTap: () => showLicensePage(context: context, applicationName: 'Lumina'),
        ),
      ]),
    );
  }
}
