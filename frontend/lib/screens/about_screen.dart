import 'package:material_ui/material_ui.dart';

import '../state/app_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'detail_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const version = '1.0.0 (1)';

  @override
  Widget build(BuildContext context) {
    final sources = AppScope.of(context).sources;
    Widget row(Widget left, Widget right, {VoidCallback? onTap, bool last = false}) => InkWell(
          onTap: onTap,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: LColors.soft))),
            child: Row(children: [Expanded(child: left), right]),
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const LHeader(title: 'About & data sources'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('How data is verified', style: ts(17, weight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Scholarships are collected from official provider websites and re-checked regularly. '
                    'Items not yet confirmed by a human reviewer are marked "Not yet verified". '
                    'Always confirm on the official site before applying.',
                    style: ts(14, color: LColors.text3, height: 1.55),
                  ),
                  const SizedBox(height: 24),
                  Text('Official sources', style: ts(17, weight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  LCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        if (sources.isEmpty)
                          row(Text('No sources loaded yet', style: ts(15, color: LColors.text2)), const SizedBox(), last: true),
                        for (var i = 0; i < sources.length; i++)
                          row(
                            Text(sources[i].host, style: ts(15)),
                            const Icon(Icons.open_in_new_rounded, size: 18, color: LColors.muted),
                            onTap: () => openOfficialPage(context, sources[i].url),
                            last: i == sources.length - 1,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  LCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        row(Text('App version', style: ts(15)), Text(version, style: ts(15, color: LColors.text2))),
                        row(
                          Text('Licenses', style: ts(15)),
                          const Icon(Icons.chevron_right_rounded, size: 20, color: LColors.muted),
                          onTap: () => showLicensePage(
                            context: context,
                            applicationName: 'Lumina',
                            applicationVersion: version,
                          ),
                          last: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
