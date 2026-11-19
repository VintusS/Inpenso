import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'theme.dart';

final _compact = NumberFormat.compact();

FlTitlesData _titles(BuildContext context, {required String Function(double) bottom, String Function(double)? left, double? bottomInterval}) {
  final style = Font.caption2.copyWith(color: context.secondaryLabel);
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        getTitlesWidget: (v, meta) => v == meta.max && v != meta.min
            ? const SizedBox.shrink()
            : SideTitleWidget(meta: meta, child: Text(left?.call(v) ?? _compact.format(v), style: style)),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 22,
        interval: bottomInterval,
        getTitlesWidget: (v, meta) => SideTitleWidget(meta: meta, child: Text(bottom(v), style: style)),
      ),
    ),
  );
}

FlGridData _grid(BuildContext context, {bool vertical = false}) => FlGridData(
      drawVerticalLine: vertical,
      getDrawingHorizontalLine: (_) => FlLine(color: context.separator, strokeWidth: 0.5),
      getDrawingVerticalLine: (_) => FlLine(color: context.separator, strokeWidth: 0.5),
    );

HorizontalLine _rule(BuildContext context, double y, Color color, String label, {double width = 1.5}) => HorizontalLine(
      y: y,
      color: color,
      strokeWidth: width,
      dashArray: [5, 5],
      label: HorizontalLineLabel(
        show: true,
        alignment: Alignment.topRight,
        style: Font.caption2.copyWith(color: color, backgroundColor: context.bg3),
        labelResolver: (_) => ' $label ',
      ),
    );

/// Bar chart with an optional dashed average/target rule.
class Bars extends StatelessWidget {
  const Bars({
    super.key,
    required this.values,
    required this.label,
    this.colors,
    this.rule,
    this.ruleLabel = 'Avg',
    this.ruleColor,
    this.radius = 4,
    this.labelEvery,
    this.leftLabel,
  });
  final List<double> values;
  final String Function(int index) label;
  final List<Color>? colors;
  final double? rule;
  final String ruleLabel;
  final Color? ruleColor;
  final double radius;
  final int? labelEvery;
  final String Function(double)? leftLabel;

  @override
  Widget build(BuildContext context) {
    final blue = context.c(SysColor.blue);
    final maxV = [...values, (rule ?? 0)].fold(0.0, max);
    return LayoutBuilder(builder: (context, box) {
      final barWidth = max(2.0, (box.maxWidth - 40) / values.length * 0.6);
      return BarChart(BarChartData(
        minY: 0,
        maxY: max(maxV * 1.2, 1),
        barTouchData: BarTouchData(enabled: false),
        borderData: FlBorderData(show: false),
        gridData: _grid(context),
        titlesData: _titles(context,
            left: leftLabel,
            bottom: (v) {
              final i = v.toInt();
              if (labelEvery != null && (i + 1) % labelEvery! != 0 && i != 0) return '';
              return label(i);
            }),
        extraLinesData: rule == null || rule! <= 0
            ? null
            : ExtraLinesData(horizontalLines: [_rule(context, rule!, ruleColor ?? context.c(SysColor.green), ruleLabel)]),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: values[i],
                width: barWidth,
                borderRadius: BorderRadius.vertical(top: Radius.circular(min(radius, barWidth / 2))),
                color: colors?[i],
                gradient: colors == null
                    ? LinearGradient(
                        colors: [blue.withValues(alpha: 0.7), blue],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter)
                    : null,
              ),
            ]),
        ],
      ));
    });
  }
}

class Donut extends StatelessWidget {
  const Donut({super.key, required this.values, required this.colors});
  final List<double> values;
  final List<Color> colors;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final r = min(box.maxWidth, box.maxHeight) / 2;
        return PieChart(PieChartData(
          startDegreeOffset: -90,
          sectionsSpace: 1.5,
          centerSpaceRadius: r * 0.6,
          pieTouchData: PieTouchData(enabled: false),
          sections: [
            for (var i = 0; i < values.length; i++)
              PieChartSectionData(value: values[i], color: colors[i], radius: r * 0.4, showTitle: false),
          ],
        ));
      });
}

class AreaLine extends StatelessWidget {
  const AreaLine({super.key, required this.values, required this.label});
  final List<double> values;
  final String Function(int) label;
  @override
  Widget build(BuildContext context) {
    final blue = context.c(SysColor.blue);
    return LineChart(LineChartData(
      minY: 0,
      maxY: max(values.fold(0.0, max) * 1.2, 1),
      lineTouchData: const LineTouchData(enabled: false),
      borderData: FlBorderData(show: false),
      gridData: _grid(context),
      titlesData: _titles(context, bottom: (v) => label(v.toInt()), bottomInterval: 1),
      lineBarsData: [
        LineChartBarData(
          spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
          isCurved: true,
          preventCurveOverShooting: true,
          color: blue,
          barWidth: 2,
          dotData: FlDotData(
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 3.5, color: blue, strokeWidth: 0)),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [blue.withValues(alpha: 0.3), blue.withValues(alpha: 0)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    ));
  }
}
