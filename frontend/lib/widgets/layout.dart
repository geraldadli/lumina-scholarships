import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Screen widths where the layout changes, and how wide content may grow.
abstract final class LBreak {
  /// At this window width the bottom tabs become a left sidebar.
  static const sidebar = 900.0;

  /// At this content width Browse shows its filters beside the results.
  static const filterRail = 940.0;

  /// At this width the details page splits into two columns.
  static const twoColumn = 860.0;

  /// Reading width for forms, chats and checklists.
  static const reading = 680.0;

  /// Widest the card grids get.
  static const wide = 1140.0;
}

/// Gives [builder] the side padding that centres content no wider than [maxWidth], so
/// scroll views still span the whole window (the mouse wheel works anywhere).
class Gutter extends StatelessWidget {
  const Gutter({super.key, required this.builder, this.maxWidth = LBreak.reading, this.min = 20});

  final Widget Function(BuildContext context, double side) builder;
  final double maxWidth;
  final double min;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => builder(context, math.max(min, (box.maxWidth - maxWidth) / 2)),
      );
}

/// Cards in as many equal columns as fit: one on a phone, two or three on a desktop.
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.children, this.minWidth = 330});

  final List<Widget> children;
  final double minWidth;

  static int columnsFor(double width, {double minWidth = 330}) => math.max(1, math.min(3, width ~/ minWidth));

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final columns = columnsFor(box.maxWidth, minWidth: minWidth);
          final gap = L.s(14);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: gap,
            children: [
              for (var i = 0; i < children.length; i += columns)
                CardRow(columns: columns, gap: gap, children: children.skip(i).take(columns).toList()),
            ],
          );
        },
      );
}

/// One row of a card grid. Cards in a row share the tallest card's height.
class CardRow extends StatelessWidget {
  const CardRow({super.key, required this.columns, required this.children, required this.gap});

  final int columns;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (columns == 1) return children.single;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: [
          for (var i = 0; i < columns; i++) Expanded(child: i < children.length ? children[i] : const SizedBox()),
        ],
      ),
    );
  }
}
