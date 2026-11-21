import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'app_state.dart';
import 'features/ask_ai.dart';
import 'features/browse.dart';
import 'features/detail.dart';
import 'features/email_sign_in.dart';
import 'features/home.dart';
import 'features/onboarding.dart';
import 'features/prepare.dart';
import 'features/profile.dart';
import 'features/saved.dart';
import 'features/welcome.dart';

GoRouter buildRouter(AppState state) => GoRouter(
      initialLocation: '/splash',
      refreshListenable: state,
      redirect: (context, s) {
        final loc = s.matchedLocation;
        const signedOutPages = ['/welcome', '/email'];
        if (!state.authReady) return loc == '/splash' ? null : '/splash';
        if (state.user == null) return signedOutPages.contains(loc) ? null : '/welcome';
        if (!state.profileLoaded) return loc == '/splash' ? null : '/splash';
        if (!state.profile.onboardingCompleted) return loc == '/onboarding' ? null : '/onboarding';
        if (loc == '/splash' || loc == '/onboarding' || signedOutPages.contains(loc)) return '/home';
        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
        GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
        GoRoute(path: '/email', builder: (_, _) => const EmailSignInScreen()),
        GoRoute(path: '/onboarding', builder: (_, _) => const ProfileFormScreen()),
        GoRoute(
          path: '/edit/:section',
          builder: (_, s) => ProfileFormScreen(editSection: int.parse(s.pathParameters['section']!)),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, _, shell) => _NavShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/browse', builder: (_, _) => const BrowseScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/saved', builder: (_, _) => const SavedScreen())]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen(), routes: [
                GoRoute(path: 'about', builder: (_, _) => const AboutScreen()),
              ]),
            ]),
          ],
        ),
        GoRoute(
          path: '/scholarship/:id',
          builder: (_, s) => DetailScreen(id: s.pathParameters['id']!),
          routes: [
            GoRoute(path: 'ask', builder: (_, s) => AskAiScreen(id: s.pathParameters['id']!)),
            GoRoute(path: 'prepare', builder: (_, s) => PrepareScreen(id: s.pathParameters['id']!)),
          ],
        ),
      ],
    );

class _NavShell extends StatelessWidget {
  const _NavShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Symbols.home), selectedIcon: Icon(Symbols.home, fill: 1), label: 'Home'),
          NavigationDestination(icon: Icon(Symbols.search), label: 'Browse'),
          NavigationDestination(icon: Icon(Symbols.bookmark), selectedIcon: Icon(Symbols.bookmark, fill: 1), label: 'Saved'),
          NavigationDestination(icon: Icon(Symbols.person), selectedIcon: Icon(Symbols.person, fill: 1), label: 'Profile'),
        ],
      ),
    );
  }
}
