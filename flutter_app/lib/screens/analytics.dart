import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../charts.dart';
import '../state.dart';
import '../theme.dart';
import '../ui.dart';

enum AnalyticsTab { overview, trends, insights, budget }

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});
  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  AnalyticsTab tab = AnalyticsTab.overview;

  @override
  Widget build(BuildContext context) => StoreBuilder(builder: (context) {
        final content = switch (tab) {
          AnalyticsTab.overview => _overview(context),
          AnalyticsTab.trends => _trends(context),
          AnalyticsTab.insights => _insights(context),
          AnalyticsTab.budget => [const _BudgetTab()],
        };
        return LargeTitlePage(
          title: 'Analytics',
          slivers: [
            SliverToBoxAdapter(
              child: constrained(Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: [
                  MonthYearPicker(
                    month: analytics.selectedMonth,
                    year: analytics.selectedYear,
                    onChanged: analytics.changeMonth,
                  ),
                  gap(8),
                  Segmented(
                    values: AnalyticsTab.values,
                    label: (t) => t.name[0].toUpperCase() + t.name.substring(1),
                    selected: tab,
                    onChanged: (t) => setState(() => tab = t),
                  ),
                ]),
              )),
            ),
            SliverToBoxAdapter(
              child: constrained(Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [for (final w in content) ...[w, gap(20)]]),
              )),
            ),
          ],
        );
      });

  // ---------------------------------------------------------------- Overview

  List<Widget> _overview(BuildContext context) {
    final a = analytics;
    final used = a.currentBudget > 0 ? (a.totalSpent / a.currentBudget * 100).clamp(0, 100).toDouble() : 0.0;
    final cards = [
      _Summary('Total Spent', settings.money(a.totalSpent), CupertinoIcons.money_dollar_circle_fill, SysColor.blue),
      _Summary('Income', settings.money(a.totalIncome), CupertinoIcons.arrow_down_circle_fill, SysColor.green),
      _Summary('Net', settings.money(a.netCashflow), CupertinoIcons.equal_circle_fill,
          a.netCashflow >= 0 ? SysColor.green : SysColor.red),
      _Summary('Daily Average', settings.money(a.averageDailySpend), CupertinoIcons.calendar_today, SysColor.green),
      a.currentBudget > 0
          ? _Summary('Budget Used', '${used.toInt()}%', CupertinoIcons.chart_pie_fill,
              used >= 90 ? SysColor.red : (used >= 75 ? SysColor.orange : SysColor.blue),
              valueColor: used >= 90 ? SysColor.red : (used >= 75 ? SysColor.orange : null))
          : const _Summary('Budget', 'Not Set', CupertinoIcons.chart_pie_fill, SysColor.gray, valueColor: SysColor.gray),
      a.currentBudget > 0 && a.daysRemainingInMonth > 0
          ? _Summary('Per Day Left', settings.money(a.budgetRemainingPerDay), CupertinoIcons.calendar_today,
              SysColor.purple)
          : _Summary('Days Left', '${a.daysRemainingInMonth} days', CupertinoIcons.calendar, SysColor.purple),
    ];
    final byCat = a.spendingByCategory.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
    return [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 110,
        children: cards,
      ),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Daily Spending', style: Font.headline),
          gap(8),
          if (a.dailySpending.isEmpty)
            const _NoData()
          else
            SizedBox(
              height: 170,
              child: Bars(
                values: [for (final d in a.dailySpending) d.amount],
                label: (i) => '${i + 1}',
                labelEvery: 5,
                rule: a.averageDailySpend,
              ),
            ),
        ]),
      ),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Spending by Category', style: Font.headline),
          gap(8),
          if (byCat.isEmpty)
            const _NoData()
          else ...[
            SizedBox(
              height: 200,
              child: Donut(
                values: [for (final e in byCat) e.value],
                colors: [for (final e in byCat) categories.category(e.key).color],
              ),
            ),
            gap(8),
            for (final e in byCat)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  dot(categories.category(e.key).color),
                  gap(8),
                  Expanded(child: Text(categories.category(e.key).displayName, style: Font.subheadline)),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(settings.money(e.value), style: Font.subheadline),
                    if (a.totalSpent > 0) Sec('${(e.value / a.totalSpent * 100).toInt()}%', style: Font.caption),
                  ]),
                ]),
              ),
          ],
        ]),
      ),
    ];
  }

  // ---------------------------------------------------------------- Trends

  List<Widget> _trends(BuildContext context) {
    final a = analytics;
    final t = a.monthlyTrends;
    final first = t.isEmpty ? null : t.first, last = t.isEmpty ? null : t.last;
    final changes = a.categoryTrends.where((c) => c.previousAmount > 0).toList()
      ..sort((x, y) => y.percentChange.abs().compareTo(x.percentChange.abs()));
    return [
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Monthly Spending', style: Font.headline),
          gap(12),
          if (t.isEmpty)
            const _NoData()
          else ...[
            SizedBox(
                height: 180,
                child: AreaLine(values: [for (final m in t) m.amount], label: (i) => t[i].shortMonthName)),
            if (first!.amount > 0 && last!.amount > 0)
              () {
                final pct = (last.amount - first.amount) / first.amount * 100;
                final up = pct >= 0;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    Icon(up ? CupertinoIcons.arrow_up_right : CupertinoIcons.arrow_down_right,
                        size: 16, color: context.c(up ? SysColor.red : SysColor.green)),
                    gap(6),
                    Sec('${pct.toInt().abs()}% ${up ? 'increase' : 'decrease'} over ${t.length} months',
                        style: Font.caption),
                  ]),
                );
              }(),
          ],
        ]),
      ),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Category Changes', style: Font.headline),
          gap(12),
          if (a.categoryTrends.isEmpty)
            const _NoData('No data available for comparison')
          else
            for (final c in changes.take(4))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  dot(categories.category(c.categoryID).color),
                  gap(8),
                  Expanded(child: Text(categories.category(c.categoryID).displayName, style: Font.subheadline)),
                  Icon(c.isIncreasing ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
                      size: 14, color: context.c(c.isIncreasing ? SysColor.red : SysColor.green)),
                  gap(4),
                  Text('${c.percentChange.abs().toInt()}%',
                      style: Font.caption.copyWith(
                          fontWeight: semibold, color: context.c(c.isIncreasing ? SysColor.red : SysColor.green))),
                  gap(8),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(settings.money(c.currentAmount), style: Font.caption),
                    Sec(settings.money(c.previousAmount), style: Font.caption2),
                  ]),
                ]),
              ),
        ]),
      ),
      if (a.projectedMonthlySpend > 0) _projection(context),
    ];
  }

  Widget _projection(BuildContext context) {
    final a = analytics;
    final diff = a.projectedMonthlySpend - a.currentBudget;
    final over = a.projectedMonthlySpend > a.currentBudget;
    Widget col(String t, String v, {Color? color, bool end = false}) => Expanded(
          child: Column(crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
            Sec(t),
            gap(8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(v, style: Font.title3.copyWith(fontWeight: bold, color: color == null ? null : context.c(color))),
            ),
          ]),
        );
    const div = Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: SizedBox(height: 50, child: VerticalDivider(width: 1)));
    return Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Monthly Projection', style: Font.headline),
        gap(12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          col('Projected', settings.money(a.projectedMonthlySpend)),
          if (a.currentBudget > 0) ...[
            div,
            col('Budget', settings.money(a.currentBudget)),
            div,
            col('Difference', settings.money(diff.abs()), color: diff > 0 ? SysColor.red : SysColor.green, end: true),
          ],
        ]),
        if (a.currentBudget > 0) ...[
          gap(4),
          Text(over ? 'You are projected to exceed your budget' : 'You are projected to stay under budget',
              style: Font.subheadline.copyWith(color: context.c(over ? SysColor.red : SysColor.green))),
        ],
      ]),
    );
  }

  // ---------------------------------------------------------------- Insights

  List<Widget> _insights(BuildContext context) {
    final a = analytics;
    final big = a.biggestExpenseCategory;
    final active = _mostActiveWeekday();
    final week = _weekdayVsWeekend(), month = _monthlyPattern();
    return [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Key Statistics', style: Font.headline),
        gap(),
        if (big != null) ...[
          Box(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Sec('Top Spending Category'),
                  gap(4),
                  Row(children: [
                    dot(categories.category(big.$1).color, 10),
                    gap(8),
                    Flexible(
                        child: Text(categories.category(big.$1).displayName,
                            style: const TextStyle(fontSize: 18, fontWeight: bold))),
                  ]),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (a.totalSpent > 0) Sec('${(big.$2 / a.totalSpent * 100).toInt()}% of total', style: Font.caption),
                gap(4),
                Text(settings.money(big.$2), style: const TextStyle(fontSize: 18, fontWeight: bold)),
              ]),
            ]),
          ),
          gap(),
        ],
        if (active != null)
          Box(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Sec('Most Active Days'),
                  gap(4),
                  Text(active, style: const TextStyle(fontSize: 18, fontWeight: bold)),
                ]),
              ),
              Icon(CupertinoIcons.calendar_today, size: 24, color: context.accent),
            ]),
          ),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Smart Insights', style: Font.headline),
        gap(12),
        if (a.insights.isEmpty)
          const Box(child: Center(child: Sec('No insights available yet', style: Font.body)))
        else
          for (final i in a.insights) ...[
            Box(
              child: Row(children: [
                SizedBox(width: 36, child: Icon(i.icon, size: 28, color: context.c(i.color))),
                gap(),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i.title, style: Font.headline),
                    gap(4),
                    Sec(i.description),
                  ]),
                ),
              ]),
            ),
            gap(12),
          ],
      ]),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Spending Patterns', style: Font.headline),
          gap(12),
          if (week == null && month == null)
            const _NoData('Not enough data')
          else ...[
            if (week != null) _pattern(context, 'Weekday vs Weekend', week),
            if (week != null && month != null) gap(12),
            if (month != null) _pattern(context, 'Monthly Pattern', month),
          ],
        ]),
      ),
    ];
  }

  Widget _pattern(BuildContext context, String heading, _Pattern p) => Box(
        color: context.bg3,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Sec(heading),
              gap(4),
              Text(p.title, style: const TextStyle(fontSize: 16, fontWeight: semibold)),
              gap(4),
              Sec(p.description, style: Font.caption),
            ]),
          ),
          Icon(p.icon, size: 24, color: context.c(p.color)),
        ]),
      );

  String? _mostActiveWeekday() {
    final days = analytics.dailySpending.where((d) => d.amount > 0);
    if (days.isEmpty) return null;
    final groups = <String, List<double>>{};
    for (final d in days) {
      groups.putIfAbsent(DateFormat.EEEE().format(d.date), () => []).add(d.amount);
    }
    double avg(List<double> l) => l.reduce((a, b) => a + b) / l.length;
    return groups.entries.reduce((a, b) => avg(b.value) > avg(a.value) ? b : a).key;
  }

  _Pattern? _weekdayVsWeekend() {
    final d = analytics.dailySpending;
    if (d.isEmpty) return null;
    final wd = [for (final x in d) if (x.date.weekday < 6) x.amount];
    final we = [for (final x in d) if (x.date.weekday >= 6) x.amount];
    final wdAvg = wd.fold(0.0, (a, b) => a + b) / (wd.isEmpty ? 1 : wd.length);
    final weAvg = we.fold(0.0, (a, b) => a + b) / (we.isEmpty ? 1 : we.length);
    final ratio = wdAvg > 0 ? weAvg / wdAvg : 0.0;
    if (ratio > 1.5) {
      return _Pattern('Weekend Spender', 'You spend ${(ratio * 100).toInt()}% more on weekends compared to weekdays',
          Icons.celebration, SysColor.orange);
    } else if (ratio > 1.1) {
      return const _Pattern('Slightly Higher Weekend Spending', 'Your weekend spending is moderately higher than weekdays',
          CupertinoIcons.calendar_badge_plus, SysColor.blue);
    } else if (ratio < 0.7) {
      return const _Pattern('Weekday Focused', 'You spend significantly more on weekdays than weekends',
          CupertinoIcons.briefcase, SysColor.purple);
    }
    return const _Pattern('Balanced Spending', 'Your spending is fairly consistent throughout the week',
        CupertinoIcons.equal_circle, SysColor.green);
  }

  _Pattern? _monthlyPattern() {
    final d = analytics.dailySpending;
    if (d.isEmpty) return null;
    double avg(Iterable<double> l) => l.fold(0.0, (a, b) => a + b) / (l.isEmpty ? 1 : l.length);
    final early = avg([for (final x in d) if (x.dayOfMonth <= 10) x.amount]);
    final mid = avg([for (final x in d) if (x.dayOfMonth > 10 && x.dayOfMonth <= 20) x.amount]);
    final late = avg([for (final x in d) if (x.dayOfMonth > 20) x.amount]);
    final m = [early, mid, late].reduce((a, b) => a > b ? a : b);
    if (m == early && early > mid * 1.3 && early > late * 1.3) {
      return const _Pattern('Early Month Spender', 'You tend to spend more in the first part of the month',
          CupertinoIcons.calendar_badge_plus, SysColor.green);
    } else if (m == late && late > early * 1.3 && late > mid * 1.3) {
      return const _Pattern('End of Month Spender', 'Your spending increases toward the end of the month',
          Icons.event_busy, SysColor.red);
    } else if (m == mid && mid > early * 1.3 && mid > late * 1.3) {
      return const _Pattern('Mid-Month Spike', 'Your spending peaks in the middle of the month',
          CupertinoIcons.waveform_path_ecg, SysColor.orange);
    }
    return const _Pattern('Consistent Throughout Month', 'Your spending is fairly evenly distributed throughout the month',
        CupertinoIcons.equal_circle, SysColor.blue);
  }
}

class _Pattern {
  final String title, description;
  final IconData icon;
  final Color color;
  const _Pattern(this.title, this.description, this.icon, this.color);
}

class _NoData extends StatelessWidget {
  const _NoData([this.text = 'No data available']);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(16), child: Center(child: Sec(text, style: Font.body)));
}

class _Summary extends StatelessWidget {
  const _Summary(this.title, this.value, this.icon, this.color, {this.valueColor});
  final String title, value;
  final IconData icon;
  final Color color;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: context.c(color)),
            gap(6),
            Expanded(child: Sec(title)),
          ]),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: Font.title3.copyWith(fontWeight: bold, color: valueColor == null ? null : context.c(valueColor!))),
          ),
        ]),
      );
}

// ---------------------------------------------------------------- Budget tab

class _BudgetTab extends StatefulWidget {
  const _BudgetTab();
  @override
  State<_BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<_BudgetTab> {
  final field = TextEditingController();
  final focus = FocusNode();
  String? _shownFor;

  double _parse() => double.tryParse(field.text.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '')) ?? 0;

  @override
  void initState() {
    super.initState();
    focus.addListener(() {
      if (!focus.hasFocus) field.text = settings.money(_parse());
    });
  }

  @override
  void dispose() {
    field.dispose();
    focus.dispose();
    super.dispose();
  }

  void _save() {
    focus.unfocus();
    analytics.saveBudget(_parse());
    Haptic.success();
    showAlert(context, 'Budget Saved', message: 'Your monthly budget has been saved successfully.');
  }

  double _suggested() {
    final t = analytics.monthlyTrends;
    if (t.length >= 3) {
      final recent = t.sublist(t.length - 3);
      return (recent.fold(0.0, (s, m) => s + m.amount) / 3 * 1.1 / 10).ceil() * 10.0;
    }
    if (analytics.projectedMonthlySpend > 0) return (analytics.projectedMonthlySpend * 1.05 / 10).ceil() * 10.0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    // Refresh the field when the month (and so the stored budget) changes.
    final key = '${budgetKey(a.selectedMonth, a.selectedYear)}|${settings.currency}';
    if (_shownFor != key && !focus.hasFocus) {
      _shownFor = key;
      field.text = settings.money(a.currentBudget);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Set Monthly Budget', style: Font.headline),
      gap(12),
      Box(
        child: Column(children: [
          Row(children: [
            const Expanded(child: Text('Budget Amount', style: Font.subheadline)),
            Container(
              width: 150,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.centerRight,
              decoration: BoxDecoration(color: context.bg3, borderRadius: BorderRadius.circular(8)),
              child: TextField(
                controller: field,
                focusNode: focus,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onTap: () => field.text = _parse() == 0 ? '' : _parse().toStringAsFixed(2),
                decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: '0'),
              ),
            ),
          ]),
          gap(),
          GestureDetector(
            onTap: _save,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(12)),
              child: const Center(
                child: Text('Save Budget', style: TextStyle(fontWeight: semibold, color: Colors.white, fontSize: 17)),
              ),
            ),
          ),
        ]),
      ),
      if (a.currentBudget > 0) ...[gap(20), _status(context), gap(20), _recommendations(context)],
      gap(20),
      _history(context),
    ]);
  }

  Widget _status(BuildContext context) {
    final a = analytics;
    final p = (a.totalSpent / a.currentBudget).clamp(0.0, 1.0);
    Widget pair(String l, String v, TextStyle s, {bool end = false}) => Column(
          crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [Sec(l, style: Font.caption), gap(4), Text(v, style: s)],
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Budget Status', style: Font.headline),
      gap(12),
      Box(
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Sec('${(p * 100).toInt()}% Used'),
            Sec('${((1 - p) * 100).toInt()}% Remaining'),
          ]),
          gap(8),
          ProgressBar(progress: p, height: 12, color: context.c(budgetColor(p))),
          gap(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            pair('Spent', settings.money(a.totalSpent), Font.title3.copyWith(fontWeight: bold)),
            pair('Remaining', settings.money((a.currentBudget - a.totalSpent).clamp(0, double.infinity)),
                Font.title3.copyWith(fontWeight: bold),
                end: true),
          ]),
          if (a.daysRemainingInMonth > 0) ...[
            gap(),
            const Divider(),
            gap(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              pair('Days Remaining', '${a.daysRemainingInMonth} days', Font.subheadline.copyWith(fontWeight: semibold)),
              pair('Daily Budget Left', settings.money(a.budgetRemainingPerDay),
                  Font.subheadline.copyWith(fontWeight: semibold),
                  end: true),
            ]),
          ],
        ]),
      ),
    ]);
  }

  Widget _recommendations(BuildContext context) {
    final a = analytics;
    final big = a.biggestExpenseCategory;
    final suggested = _suggested();
    const s15 = TextStyle(fontSize: 15, fontWeight: semibold);
    final items = <Widget>[
      if (big != null && a.totalSpent > a.currentBudget)
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Consider Reducing', style: Font.subheadline),
              gap(4),
              Row(children: [
                dot(categories.category(big.$1).color, 8),
                gap(8),
                Text(categories.category(big.$1).displayName, style: s15),
              ]),
            ]),
          ),
          Text(settings.money(big.$2), style: s15),
        ]),
      if (a.totalSpent > a.currentBudget && a.daysRemainingInMonth > 0)
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('To Get Back on Track', style: Font.subheadline),
          gap(4),
          Sec('You need to spend ${settings.money(a.currentBudget * 0.9 - a.totalSpent)} less than budgeted for the rest of the month.',
              style: Font.caption),
        ]),
      if (suggested > 0 && (suggested - a.currentBudget).abs() / a.currentBudget > 0.1)
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Suggested Next Month', style: Font.subheadline),
          gap(4),
          Row(children: [
            Text(settings.money(suggested), style: s15),
            gap(8),
            suggested > a.currentBudget
                ? Text('(+${((suggested - a.currentBudget) / a.currentBudget * 100).toInt()}%)',
                    style: Font.caption.copyWith(color: context.c(SysColor.orange)))
                : Text('(-${((a.currentBudget - suggested) / a.currentBudget * 100).toInt()}%)',
                    style: Font.caption.copyWith(color: context.c(SysColor.green))),
          ]),
        ]),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Recommendations', style: Font.headline),
      gap(12),
      Box(child: Column(children: [for (final (i, w) in items.indexed) ...[if (i > 0) gap(), w]])),
    ]);
  }

  Widget _history(BuildContext context) {
    final a = analytics;
    final data = <(String, double, Color)>[];
    for (final t in a.monthlyTrends.take(a.monthlyTrends.length - 1)) {
      final b = a.monthlyBudgets[budgetKey(t.month, t.year)];
      if (b != null && b > 0) {
        final pct = t.amount / b * 100;
        data.add((
          t.shortMonthName,
          pct,
          pct <= 90 ? SysColor.green : (pct <= 100 ? SysColor.blue : (pct <= 110 ? SysColor.orange : SysColor.red))
        ));
      }
    }
    final onBudget = data.where((d) => d.$2 <= 100).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Budget History', style: Font.headline),
      gap(12),
      if (data.isEmpty)
        const Box(child: Center(child: Sec('Not enough budget history yet', style: Font.body)))
      else
        Box(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.only(right: 30),
              child: SizedBox(
                height: 200,
                child: Bars(
                  values: [for (final d in data) d.$2],
                  colors: [for (final d in data) context.c(d.$3)],
                  label: (i) => data[i].$1,
                  rule: 100,
                  ruleLabel: 'Budget',
                  ruleColor: context.c(SysColor.gray),
                  leftLabel: (v) => '${v.toInt()}%',
                ),
              ),
            ),
            gap(8),
            Sec('$onBudget of ${data.length} months on or under budget', style: Font.caption),
          ]),
        ),
    ]);
  }
}
