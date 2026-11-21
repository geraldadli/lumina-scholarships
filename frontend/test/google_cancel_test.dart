import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:lumina/data/backend.dart';
import 'package:lumina/data/demo_backend.dart';
import 'package:lumina/screens/auth_screens.dart';
import 'package:lumina/state/app_controller.dart';
import 'package:lumina/state/app_scope.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

/// The native Google picker answers every time; this replays a chosen answer.
class _GoogleAnswers extends DemoBackend {
  _GoogleAnswers(super.catalog, this.answer);

  final AuthFailure answer;
  int calls = 0;

  @override
  Future<void> signInWithGoogle() async {
    calls++;
    throw answer;
  }
}

void main() {
  Future<_GoogleAnswers> pumpWelcome(WidgetTester tester, AuthFailure answer) async {
    final backend = _GoogleAnswers(loadCatalog(), answer);
    final c = AppController(backend: backend, ai: HybridAi(hostApi: FakeHost()), clock: () => testNow);
    await tester.pumpWidget(AppScope(controller: c, child: const MaterialApp(home: WelcomeScreen())));
    return backend;
  }

  testWidgets('closing the Google picker stops the spinner quietly and Google can be tried again', (tester) async {
    final backend = await pumpWelcome(tester, const AuthFailure('Sign-in was cancelled.', cancelled: true));

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Sign-in was cancelled.'), findsNothing); // the student did it, no error toast

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(backend.calls, 2);
  });

  testWidgets('a real Google sign-in problem is shown', (tester) async {
    await pumpWelcome(tester, const AuthFailure('Google sign-in is not set up for this app yet. Use email for now.'));

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Google sign-in is not set up for this app yet. Use email for now.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
