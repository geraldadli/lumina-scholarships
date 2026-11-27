import 'package:material_ui/material_ui.dart';

import '../design/appearance.dart';
import '../design/customize_panel.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/layout.dart';

/// Profile > Language: the list of languages. The choice is remembered on this device with
/// the rest of the look. To add a language, add an entry to [AppLanguage].
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = AppearanceScope.of(context);
    final current = appearance.value.language;

    void pick(AppLanguage l) {
      if (l == current) return;
      appearance.update(appearance.value.copyWith(language: l));
      showToast(
        context,
        l.translated ? 'Language set to ${l.nativeName}' : '${l.nativeName} selected. Translation is coming soon',
        icon: l.translated ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const LHeader(title: 'Language'),
            Expanded(
              child: Gutter(
                builder: (context, side) => ListView(
                  padding: EdgeInsets.fromLTRB(side, 20, side, 20),
                  children: [
                    LCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final (i, l) in AppLanguage.values.indexed)
                            InkWell(
                              onTap: () => pick(l),
                              child: Semantics(
                                selected: l == current,
                                button: true,
                                child: Container(
                                  constraints: const BoxConstraints(minHeight: 60),
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: L.s(10)),
                                  decoration: BoxDecoration(
                                    border: i == AppLanguage.values.length - 1
                                        ? null
                                        : Border(bottom: BorderSide(color: LColors.soft)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          spacing: 2,
                                          children: [
                                            Text(l.nativeName, style: ts(15, weight: FontWeight.w600)),
                                            Text(
                                              l.translated ? l.englishName : '${l.englishName} · coming soon',
                                              style: ts(13, color: LColors.text2),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (l == current)
                                        Icon(Icons.check_rounded, size: 22, color: LColors.primary),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Scholarship details always come from the official source and may stay in their original language.',
                      style: ts(13, color: LColors.text2, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
