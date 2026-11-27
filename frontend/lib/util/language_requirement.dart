/// Splits the free-text `languageRequirement` into lines for the details page.
///
/// The research team writes it as one sentence, for example
/// `TOEFL ITP 550, TOEFL iBT 80 or IELTS 6.5 (minimum varies by field)`, or with one list
/// per level: `Masters: IELTS 6.0 / TOEFL iBT 80. PhD: IELTS 6.5 / iBT 88`. Only the layout
/// changes: no wording is added or dropped, and text that is not a list of scores stays whole.
library;

/// One part of a requirement: optionally titled ("PhD"), with its lines and remarks.
class LanguageBlock {
  const LanguageBlock({this.title, this.lines = const [], this.anyOne = false, this.notes = const [], this.nested = false});

  final String? title;

  /// One requirement each, or a single sentence.
  final List<String> lines;

  /// The lines are alternatives: meeting any one of them is enough.
  final bool anyOne;

  /// Remarks that apply to the whole block.
  final List<String> notes;

  /// Belongs to the block above it, like a special group within one level.
  final bool nested;

  @override
  String toString() => 'LanguageBlock($title, $lines, anyOne: $anyOne, notes: $notes)';
}

final _sentence = RegExp(r'\.\s+(?=[A-Z])');
final _clause = RegExp(r';\s*');
final _option = RegExp(r',\s+(?:or\s+)?|\s+/\s+|\s+or\s+');
final _alternatives = RegExp(r'\s+or\s+|\s+/\s+');
final _titled = RegExp(r'^([^:(),/;]{2,60}):\s+(.+)$');
final _remark = RegExp(r'^(.*?)\s*\(([^()]*)\)$');
final _score = RegExp(r'\d');

List<LanguageBlock> parseLanguageRequirement(String text) => [
      for (final sentence in _split(text.trim().replaceAll(RegExp(r'\.$'), ''), _sentence))
        for (final clause in _split(sentence, _clause)) ..._parseClause(clause),
    ];

List<LanguageBlock> _parseClause(String clause, {bool nested = false}) {
  final titled = _titled.firstMatch(clause);
  final title = titled == null ? null : _capitalise(titled[1]!);
  final body = titled == null ? clause : titled[2]!;

  var lines = _split(body, _option);
  // A list only when every part is a score; ordinary prose with commas stays one sentence.
  final isList = lines.length > 1 && lines.every(_score.hasMatch);
  if (!isList) lines = [body];

  // A remark after the last score only is about the whole list. When the other scores
  // carry their own ("IELTS 6.5 (no band below 6.0), ..."), each stays where it is.
  String? remark;
  final last = _remark.firstMatch(lines.last);
  if (isList && last != null && !lines.take(lines.length - 1).any(_remark.hasMatch)) {
    lines[lines.length - 1] = last[1]!;
    remark = last[2];
  }

  final notes = <String>[];
  final others = <LanguageBlock>[];
  for (final part in remark == null ? const <String>[] : _split(remark, _clause)) {
    // "(equity target groups: IELTS 4.5 / iBT 33)" is a list of its own.
    if (_titled.hasMatch(part)) {
      // Nested only under a titled level; otherwise it is a list in its own right.
      others.addAll(_parseClause(part, nested: title != null));
    } else {
      notes.add(_capitalise(part));
    }
  }

  return [
    LanguageBlock(
      title: title,
      lines: isList ? lines : [_capitalise(lines.single)],
      anyOne: isList && _alternatives.hasMatch(_outsideBrackets(body)),
      notes: notes,
      nested: nested,
    ),
    ...others,
  ];
}

/// Splits at [separator], ignoring anything inside brackets.
List<String> _split(String text, RegExp separator) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  var i = 0;
  while (i < text.length) {
    if (text[i] == '(') depth++;
    if (text[i] == ')' && depth > 0) depth--;
    final match = depth == 0 ? separator.matchAsPrefix(text, i) : null;
    if (match != null && match.end > i) {
      parts.add(text.substring(start, i));
      start = i = match.end;
    } else {
      i++;
    }
  }
  parts.add(text.substring(start));
  return [for (final p in parts) if (p.trim().isNotEmpty) p.trim()];
}

String _outsideBrackets(String text) => text.replaceAll(RegExp(r'\([^()]*\)'), '');

String _capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
