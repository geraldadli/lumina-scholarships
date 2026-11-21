import 'package:material_ui/material_ui.dart';

import '../state/app_scope.dart';
import '../theme.dart';
import 'browse_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'saved_screen.dart';

/// The four tabs with the prototype's pill-style bottom navigation.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const _tabs = [
    (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Home'),
    (icon: Icons.search_rounded, active: Icons.search_rounded, label: 'Browse'),
    (icon: Icons.bookmark_border_rounded, active: Icons.bookmark_rounded, label: 'Saved'),
    (icon: Icons.person_outline_rounded, active: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return PopScope(
      canPop: c.tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) c.setTab(0);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: c.tab,
            children: const [HomeScreen(), BrowseScreen(), SavedScreen(), ProfileScreen()],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: LColors.white,
            border: Border(top: BorderSide(color: LColors.line)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: Semantics(
                        selected: c.tab == i,
                        button: true,
                        label: _tabs[i].label,
                        child: InkWell(
                          onTap: () => c.setTab(i),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            spacing: 3,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 58,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: c.tab == i ? LColors.soft : Colors.transparent,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  c.tab == i ? _tabs[i].active : _tabs[i].icon,
                                  size: 24,
                                  color: c.tab == i ? LColors.primary : LColors.text2,
                                ),
                              ),
                              ExcludeSemantics(
                                child: Text(
                                  _tabs[i].label,
                                  style: ts(
                                    12,
                                    weight: c.tab == i ? FontWeight.w700 : FontWeight.w500,
                                    color: c.tab == i ? LColors.ink : LColors.text2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
