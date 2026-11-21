import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'router.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // reads android/app/google-services.json
  final state = AppState();
  await state.init();
  runApp(LuminaApp(state: state));
}

class LuminaApp extends StatelessWidget {
  const LuminaApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: state,
      child: MaterialApp.router(
        title: 'Lumina',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: buildRouter(state),
      ),
    );
  }
}

/// Gives every screen access to [AppState] and rebuilds it on changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required super.notifier, required super.child});

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: LColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
}
