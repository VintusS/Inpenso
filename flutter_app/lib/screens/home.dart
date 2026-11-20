import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../charts.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../ui.dart';
import 'transaction_form.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key, required this.onViewAll});
  final VoidCallback onViewAll;
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  static const recentDays = 7;

  @override
  Widget build(BuildContext context) => StoreBuilder(
        builder: (context) => LargeTitlePage(
          title: 'Home',
          slivers: [
            SliverToBoxAdapter(
              child: constrained(Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                child: Column(children: [
                  _FadeIn(offset: -50, child: _header(context)),
                  gap(20),
                  _FadeIn(offset: -30, child: _recentSpending(context)),
                  gap(20),
                  _FadeIn(offset: -20, child: _categoryBreakdown(context)),
                  gap(20),
                  _FadeIn(offset: -10, child: _uncategorized(context)),
                ]),
              )),
            ),
          ],
        ),
      );

  Widget _metric(BuildContext context, String title, double amount, Color color) => Expanded(
        child: Column(children: [
          Sec(title, style: Font.caption),
          gap(4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(settings.money(amount),
                style: Font.subheadline.copyWith(fontWeight: semibold, color: context.c(color))),
          ),
        ]),
      );

  Widget _vDivider() => const SizedBox(height: 36, child: VerticalDivider(width: 1));

  Widget _header(BuildContext context) {
    final a = analytics;
    final netColor = a.netCashflow >= 0 ? SysColor.green : SysColor.red;
    return Box(
      radius: 20,
      shadow: true,
      child: Column(children: [
        const Sec('Monthly Cashflow', style: Font.headline),
        gap(4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(settings.money(a.netCashflow),
              style: TextStyle(fontSize: 42, fontWeight: bold, color: context.c(netColor))),
        ),
        gap(16),
        Row(children: [
          _metric(context, 'Income', a.totalIncome, SysColor.green),
          _vDivider(),
          _metric(context, 'Spent', a.totalSpent, CupertinoColors.label),
          _vDivider(),
          _metric(context, 'Net', a.netCashflow, netColor),
        ]),
        if (a.currentBudget > 0) ...[
          gap(16),
          () {
            final p = (a.totalSpent / a.currentBudget).clamp(0.0, 1.0);
            return Column(children: [
              ProgressBar(progress: p, color: context.c(budgetColor(p))),
              gap(8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Sec('${(p * 100).toInt()}% of budget', style: Font.caption),
                Sec('${a.daysRemainingInMonth} days left', style: Font.caption),
              ]),
            ]);
          }(),
        ],
      ]),
    );
  }

  List<DailySpending> _recentData() {
    final today = DateTime.now();
    final out = <DailySpending>[];
    for (var i = recentDays - 1; i >= 0; i--) {
      final d = DateTime(today.year, today.month, today.day - i);
      for (final s in analytics.dailySpending) {
        if (s.date.year == d.year && s.date.month == d.month && s.date.day == d.day) out.add(s);
      }
    }
    return out;
  }

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Sec(text, style: Font.body)),
      );

  Widget _recentSpending(BuildContext context) {
    final data = _recentData();
    final total = data.fold(0.0, (s, d) => s + d.amount);
    return Box(
      radius: 20,
      shadow: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Recent Spending', style: Font.headline),
        gap(16),
        if (analytics.dailySpending.isEmpty)
          _empty('No recent spending data')
        else if (total <= 0)
          _empty('No spending in the last $recentDays days')
        else ...[
          SizedBox(
            height: 180,
            child: Bars(
              values: [for (final d in data) d.amount],
              label: (i) => i < data.length ? data[i].weekday : '',
              rule: analytics.averageDailySpend,
              radius: 6,
            ),
          ),
          gap(8),
          const Center(child: Sec('Showing spending for the last $recentDays days', style: Font.caption)),
        ],
      ]),
    );
  }

  Widget _categoryBreakdown(BuildContext context) {
    final sorted = analytics.spendingByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    return Box(
      radius: 20,
      shadow: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Spending by Category', style: Font.headline),
        gap(16),
        if (top.isEmpty)
          _empty('No category data available')
        else
          for (final (i, e) in top.indexed) ...[
            Row(children: [
              IconBadge(categories.category(e.key)),
              gap(8),
              Expanded(
                child: Text(categories.category(e.key).displayName,
                    style: Font.subheadline.copyWith(fontWeight: medium)),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(settings.money(e.value), style: Font.subheadline.copyWith(fontWeight: semibold)),
                if (analytics.totalSpent > 0)
                  Sec('${(e.value / analytics.totalSpent * 100).toInt()}%', style: Font.caption),
              ]),
            ]),
            if (i < top.length - 1) const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider()),
          ],
      ]),
    );
  }

  /// Bank rows waiting for a category (both types); they stay out of the figures above until then.
  Widget _uncategorized(BuildContext context) {
    final list = [for (final e in expenseStore.expenses) if (e.categoryID.isEmpty && !e.transfer) e]
      ..sort((a, b) => b.date.compareTo(a.date));
    return Box(
      radius: 20,
      shadow: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Uncategorized', style: Font.headline)),
          if (list.isNotEmpty) Sec('${list.length}', style: Font.subheadline),
        ]),
        gap(12),
        if (list.isEmpty)
          const Center(child: Sec('All transactions have a category', style: Font.body))
        else
          for (final (i, e) in list.indexed) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showSheet(context, TransactionForm(key: ValueKey(e.id), expense: e)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  IconBadge(FinanceCategory.uncategorized, size: 34, iconSize: 18, radius: 7),
                  gap(12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.title, style: Font.subheadline.copyWith(fontWeight: medium)),
                      gap(2),
                      Row(children: [
                        Flexible(child: Sec([DateFormat.yMMMMd().format(e.date), ?e.account].join('  •  '), style: Font.caption)),
                        if (e.account != null) ...[gap(6), BankBadge(e.account!, size: 14)],
                      ]),
                    ]),
                  ),
                  Text(amountText(e),
                      style: Font.subheadline.copyWith(fontWeight: semibold, color: amountColor(context, e))),
                ]),
              ),
            ),
            if (i < list.length - 1) const Padding(padding: EdgeInsets.only(left: 40), child: Divider()),
          ],
        gap(8),
        GestureDetector(
          onTap: widget.onViewAll,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: context.accent, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text('View All Transactions',
                  style: Font.subheadline.copyWith(fontWeight: medium, color: context.accent)),
            ),
          ),
        ),
      ]),
    );
  }
}

String amountText(Expense e) => '${e.type == TransactionType.income ? '+' : ''}${settings.money(e.price)}';
Color amountColor(BuildContext context, Expense e) =>
    e.transfer ? context.secondaryLabel : e.type == TransactionType.income ? context.c(SysColor.green) : context.label;

/// Slide + fade in on first appearance, like the iOS card animation.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.offset, required this.child});
  final double offset;
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        builder: (_, t, c) =>
            Opacity(opacity: t, child: Transform.translate(offset: Offset(0, offset * (1 - t)), child: c)),
        child: child,
      );
}
