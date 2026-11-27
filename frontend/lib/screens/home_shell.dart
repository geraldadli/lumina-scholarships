import 'package:material_ui/material_ui.dart';

import '../design/customize_panel.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../widgets/layout.dart';
import '../widgets/loading.dart';
import '../widgets/motion.dart';
import 'browse_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'saved_screen.dart';

typedef _Tab = ({IconData icon, IconData active, String label});

/// The four tabs: a bottom bar on phones, a left sidebar on wide screens.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static const List<_Tab> _tabs = [
    (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Home'),
    (icon: Icons.search_rounded, active: Icons.search_rounded, label: 'Browse'),
    (icon: Icons.bookmark_border_rounded, active: Icons.bookmark_rounded, label: 'Saved'),
    (icon: Icons.person_outline_rounded, active: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// Keeps the tabs' state (search text, scroll position) when the layout switches.
  final _body = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final body = PageSwitch(
      key: _body,
      page: c.tab,
      child: IndexedStack(
        index: c.tab,
        children: const [HomeScreen(), BrowseScreen(), SavedScreen(), ProfileScreen()],
      ),
    );
    return PopScope(
      canPop: c.tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) c.setTab(0);
      },
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= LBreak.sidebar
            ? Scaffold(
                body: SafeArea(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Sidebar(current: c.tab, onSelect: c.setTab),
                      Expanded(child: Padding(padding: const EdgeInsets.only(top: 16), child: body)),
                    ],
                  ),
                ),
              )
            : Scaffold(
                body: SafeArea(bottom: false, child: body),
                bottomNavigationBar: _BottomBar(current: c.tab, onSelect: c.setTab),
              ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        width: 232,
        decoration: BoxDecoration(
          color: LColors.white,
          border: Border(right: BorderSide(color: LColors.line)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 22, 14, 16),
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 6,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 0, 6, 18),
                        child: Row(
                          children: [
                            const LuminaLogo(size: 38),
                            const SizedBox(width: 12),
                            Expanded(child: Text('Lumina', style: ts(22, weight: FontWeight.w700))),
                          ],
                        ),
                      ),
                      for (var i = 0; i < HomeShell._tabs.length; i++)
                        _SideItem(
                          icon: current == i ? HomeShell._tabs[i].active : HomeShell._tabs[i].icon,
                          label: HomeShell._tabs[i].label,
                          selected: current == i,
                          onTap: () => onSelect(i),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _SideItem(
                      icon: Icons.palette_outlined,
                      label: 'Customize look',
                      selected: false,
                      onTap: () => openCustomize(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _SideItem extends StatelessWidget {
  const _SideItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? LColors.soft : Colors.transparent,
          borderRadius: BorderRadius.circular(L.r(12)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: selected ? LColors.ink : LColors.text2),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: ts(
                        15,
                        weight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? LColors.ink : LColors.text2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: LColors.white,
          border: Border(top: BorderSide(color: LColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                for (var i = 0; i < HomeShell._tabs.length; i++)
                  Expanded(
                    child: Semantics(
                      selected: current == i,
                      button: true,
                      label: HomeShell._tabs[i].label,
                      child: InkWell(
                        onTap: () => onSelect(i),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 4,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 58,
                              height: 30,
                              decoration: BoxDecoration(
                                color: current == i ? LColors.soft : Colors.transparent,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(
                                current == i ? HomeShell._tabs[i].active : HomeShell._tabs[i].icon,
                                size: 24,
                                color: current == i ? LColors.ink : LColors.text2,
                              ),
                            ),
                            ExcludeSemantics(
                              child: Text(
                                HomeShell._tabs[i].label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ts(
                                  13,
                                  weight: current == i ? FontWeight.w700 : FontWeight.w500,
                                  color: current == i ? LColors.ink : LColors.text2,
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
      );
}
