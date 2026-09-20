// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:math' as math;

import 'package:bogner_chess/core/ui/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/eval_verdict.dart';
import 'review_ids.dart';

/// A marked ply in the graph: a key moment, in the colour of its verdict.
@immutable
class EvalGraphMarker {
  const EvalGraphMarker(this.ply, this.color);

  final int ply;
  final Color color;
}

/// The evaluation over the game, read like an eval bar laid on its side:
/// the light area is White's share, the dark one Black's, so White's
/// advantage is up. Key moments are dots; the cursor is the ply on the board.
/// A tap or a horizontal drag jumps to the ply under the finger.
///
/// The colours are the chess colours in both themes, as on the board.
class EvalGraph extends StatelessWidget {
  const EvalGraph({
    super.key,
    required this.series,
    required this.currentPly,
    required this.onPlySelected,
    required this.semanticLabel,
    required this.semanticValueOf,
    this.markers = const [],
    this.height = defaultHeight,
  });

  static const double defaultHeight = 34;

  /// Clamped centipawns from White's point of view, index = ply (index 0 is
  /// the start position): `AnalysisDocument.evalSeries()`.
  final List<int> series;
  final int currentPly;
  final ValueChanged<int> onPlySelected;
  final List<EvalGraphMarker> markers;
  final double height;

  final String semanticLabel;

  /// The position after a ply in words ("12... Nxe4, White is winning").
  final String Function(int ply) semanticValueOf;

  int get _lastPly => series.length - 1;

  /// The ply at horizontal offset [dx] of a graph [width] wide. The plot
  /// spans the whole width: ply 0 is the left edge, the last ply the right.
  static int plyAt(double dx, double width, int lastPly) {
    if (width <= 0 || lastPly <= 0) return 0;
    return (dx / width * lastPly).round().clamp(0, lastPly);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const whiteShare = Color(0xFFF1EFEA);
    const blackShare = Color(0xFF45423E);
    final markerColors = {for (final m in markers) m.ply: m.color};

    final chart = LineChart(
      duration: Duration.zero,
      LineChartData(
        minX: 0,
        maxX: _lastPly <= 0 ? 1 : _lastPly.toDouble(),
        // A little head room, so that a dot on a mate score is not clipped.
        minY: -1.45,
        maxY: 1.45,
        backgroundColor: blackShare,
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        clipData: const FlClipData.none(),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 0,
              color: const Color(0x99909090),
              strokeWidth: 1,
            ),
          ],
          verticalLines: [
            VerticalLine(
              x: currentPly.clamp(0, _lastPly <= 0 ? 1 : _lastPly).toDouble(),
              color: scheme.primary,
              strokeWidth: 2.5,
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var ply = 0; ply < series.length; ply++)
                FlSpot(ply.toDouble(), graphValueOf(series[ply])),
            ],
            color: const Color(0xFF8C8882),
            barWidth: 1,
            belowBarData: BarAreaData(show: true, color: whiteShare),
            dotData: FlDotData(
              checkToShowDot: (spot, _) =>
                  markerColors.containsKey(spot.x.round()),
              getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                radius: 3.5,
                color: markerColors[spot.x.round()] ?? scheme.primary,
                strokeWidth: 1.5,
                strokeColor: whiteShare,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      identifier: ReviewIds.graph,
      label: semanticLabel,
      value: semanticValueOf(currentPly),
      increasedValue: semanticValueOf(math.min(currentPly + 1, _lastPly)),
      decreasedValue: semanticValueOf(math.max(currentPly - 1, 0)),
      onIncrease: () => onPlySelected(math.min(currentPly + 1, _lastPly)),
      onDecrease: () => onPlySelected(math.max(currentPly - 1, 0)),
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              void select(Offset local) => onPlySelected(
                plyAt(local.dx, constraints.maxWidth, _lastPly),
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => select(details.localPosition),
                onHorizontalDragStart: (details) =>
                    select(details.localPosition),
                onHorizontalDragUpdate: (details) =>
                    select(details.localPosition),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: IgnorePointer(child: chart),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
