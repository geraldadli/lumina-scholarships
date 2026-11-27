import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/util/language_requirement.dart';

import 'fakes.dart';

/// One language requirement per line on the details page, with nothing lost.
void main() {
  List<LanguageBlock> parsed(String id) =>
      parseLanguageRequirement(loadCatalog().firstWhere((s) => s.id == id).languageRequirement!);

  test('a comma list becomes one line per test, with the remark below', () {
    final block = parsed('fulbright-masters-indonesia-2027').single;
    expect(block.lines, ['TOEFL ITP 550', 'TOEFL iBT 80', 'IELTS 6.5', 'Duolingo 125']);
    expect(block.anyOne, isTrue);
    expect(block.notes, ['Minimum varies by field']);
  });

  test('a remark that belongs to each score stays on its line', () {
    final block = parsed('lpdp-australia-awards-2027').single;
    expect(block.lines, [
      'IELTS 6.5 (no band below 6.0)',
      'TOEFL iBT 84 (no section below 21)',
      'PTE Academic 58 (no skill below 50)',
    ]);
    expect(block.notes, isEmpty);
  });

  test('levels get their own titled lists, and so do special groups', () {
    final blocks = parsed('australia-awards-2028');
    expect(blocks.map((b) => b.title), [
      null,
      'Masters',
      'Equity target groups',
      'PhD',
      'Government of Indonesia and equity target groups',
    ]);
    expect(blocks.map((b) => b.nested), [false, false, true, false, true]);
    expect(blocks.first.lines, ['Required at application']);
    expect(blocks[1].lines, ['IELTS 6.0', 'TOEFL iBT 80', 'TOEFL ITP 552', 'PTE 56']);
    expect(blocks[2].lines, ['IELTS 4.5', 'iBT 33', 'ITP 425', 'PTE 32']);
  });

  test('several remarks are listed one by one', () {
    final blocks = parsed('mext-research-student-2027');
    expect(blocks.single.lines, ['TOEFL iBT 72', 'IELTS 5.5', 'TOEIC L&R 785', 'TOEIC S&W 310', 'JLPT N2']);
    expect(blocks.single.notes, [
      'Issued July 2024 or later',
      'Duolingo, TOEFL Prediction and NAT-TEST/J-TEST not accepted',
    ]);
  });

  test('plain sentences stay whole', () {
    expect(parsed('chevening-indonesia-2027').single.lines, ['Set by each UK university']);
    expect(parsed('stipendium-hungaricum-2026').map((b) => b.lines.single), [
      'Set by each Hungarian university',
      'Hungarian-taught programmes need B2 Hungarian',
    ]);
    final prose = parseLanguageRequirement('Proof of English, or a letter from your university').single;
    expect(prose.lines, ['Proof of English, or a letter from your university']);
    expect(prose.anyOne, isFalse);
    expect(parseLanguageRequirement(''), isEmpty);
  });

  test('no word or score is lost for any scholarship in the catalog', () {
    List<String> words(String s) => s
        .toLowerCase()
        .split(RegExp(r'[\s,;:()]+|\.(?!\d)'))
        .where((w) => w.isNotEmpty && w != 'or' && w != '/')
        .toList()
      ..sort();
    for (final s in loadCatalog()) {
      final text = s.languageRequirement;
      if (text == null) continue;
      final shown = [
        for (final b in parseLanguageRequirement(text)) ...[?b.title, ...b.lines, ...b.notes],
      ].join(' ');
      expect(words(shown), words(text), reason: s.id);
    }
  });
}
