import 'package:material_ui/material_ui.dart';

import '../data/backend.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'profile_form.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmDelete(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const _DeleteAccountDialog());

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final p = c.profile;
    final complete = p?.completeness ?? 0;
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

    final rows = <(IconData, String, String, VoidCallback)>[
      (Icons.tune_rounded, 'Edit preferences', '', () => push(const EditPreferencesScreen())),
      (Icons.shield_outlined, 'Privacy & AI', c.inferModeLabel, () => push(const PrivacyScreen())),
      (Icons.translate_rounded, 'Language', 'English', () => showToast(context, 'Bahasa Indonesia coming soon', icon: Icons.info_outline_rounded)),
      (Icons.info_outline_rounded, 'About & data sources', '', () => push(const AboutScreen())),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Row(
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: LColors.soft,
                shape: BoxShape.circle,
                border: Border.all(color: LColors.line),
              ),
              child: Text(p?.initials ?? '?', style: ts(20, weight: FontWeight.w700, color: LColors.primary)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    (p?.displayName.isNotEmpty ?? false) ? p!.displayName : 'Your name',
                    style: ts(20, weight: FontWeight.w700),
                  ),
                  if (c.user?.email != null) Text(c.user!.email!, style: ts(14, color: LColors.text2)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Profile completeness', style: ts(15, weight: FontWeight.w600))),
                  Text('${(complete * 100).round()}%', style: ts(15, weight: FontWeight.w600)),
                ],
              ),
              LProgressBar(value: complete, track: LColors.bg),
              if (complete < 1)
                LButton(
                  label: 'Complete profile',
                  height: 44,
                  radius: 12,
                  fontSize: 14,
                  onPressed: () => push(const EditPreferencesScreen()),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        LCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                InkWell(
                  onTap: rows[i].$4,
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: LColors.soft)),
                    ),
                    child: Row(
                      children: [
                        Icon(rows[i].$1, size: 22, color: LColors.text2),
                        const SizedBox(width: 12),
                        Expanded(child: Text(rows[i].$2, style: ts(15, weight: FontWeight.w500))),
                        if (rows[i].$3.isNotEmpty) Text(rows[i].$3, style: ts(13, color: LColors.text2)),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 20, color: LColors.muted),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        LButton(label: 'Sign out', kind: LButtonKind.secondary, height: 50, onPressed: c.signOut),
        const SizedBox(height: 10),
        LButton(label: 'Delete account', kind: LButtonKind.ghost, height: 50, onPressed: () => _confirmDelete(context)),
      ],
    );
  }
}

/// Confirms who the student is before anything is deleted: the password for email accounts,
/// a fresh Google sign-in otherwise. A wrong password keeps the dialog open with nothing deleted.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final c = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await c.deleteAccount(password: c.usesPassword ? _password.text : null);
      // Signed out now: the app root already closed this dialog on its way back to Welcome.
      // Popping again would remove Welcome itself, so only pop if the dialog is still on top.
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object catch (e) {
      debugPrint('Lumina: delete account failed: $e');
      if (mounted) setState(() => _error = 'Could not delete your account. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final needsPassword = c.usesPassword;
    return AlertDialog(
      backgroundColor: LColors.bg,
      title: Text('Delete account?', style: ts(18, weight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(
            'This permanently deletes your profile, saved scholarships, checklists and notes. It cannot be undone.',
            style: ts(14, color: LColors.text3, height: 1.45),
          ),
          if (needsPassword)
            TextField(
              controller: _password,
              obscureText: true,
              enabled: !_busy,
              autofocus: true,
              decoration: lInputDecoration(hint: 'Your password'),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _password.text.isEmpty || _busy ? null : _delete(),
            )
          else if (!c.backend.isDemo)
            Text('To confirm, sign in with Google again.', style: ts(14, color: LColors.text2, height: 1.45)),
          if (_error != null) Text(_error!, style: ts(13, color: const Color(0xFFB3261E), height: 1.4)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: ts(14, weight: FontWeight.w600, color: LColors.text2)),
        ),
        TextButton(
          onPressed: _busy || (needsPassword && _password.text.isEmpty) ? null : _delete,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Delete', style: ts(14, weight: FontWeight.w700, color: const Color(0xFFB3261E))),
        ),
      ],
    );
  }
}
