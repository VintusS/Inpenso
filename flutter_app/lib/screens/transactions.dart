import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../ui.dart';
import 'home.dart' show amountText, amountColor;
import 'transaction_form.dart';

enum SortOption {
  dateDescending('Newest First'),
  dateAscending('Oldest First'),
  amountDescending('Highest Amount'),
  amountAscending('Lowest Amount'),
  titleAscending('Title A-Z');

  const SortOption(this.label);
  final String label;
}

enum TransactionFilter {
  all('All'),
  expenses('Expenses'),
  incomes('Incomes');

  const TransactionFilter(this.label);
  final String label;
  bool matches(Expense e) =>
      this == all || (this == expenses ? e.type == TransactionType.expense : e.type == TransactionType.income);
}

class TransactionsView extends StatefulWidget {
  const TransactionsView({super.key});
  @override
  State<TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<TransactionsView> {
  int month = DateTime.now().month, year = DateTime.now().year;
  SortOption sort = SortOption.dateDescending;
  TransactionFilter typeFilter = TransactionFilter.all;
  String search = '';
  Set<String>? selectedCategoryIDs;
  List<String> _lastFilterIDs = [];
  List<Expense> _deleted = [];
  Timer? _undoTimer;

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  List<FinanceCategory> get filterCategories =>
      categories.forFilter({for (final e in expenseStore.expenses) e.categoryID});

  /// Keep the selection in sync when categories appear or disappear (new ones start selected).
  Set<String> _syncSelection() {
    final ids = [for (final c in filterCategories) c.id];
    final sel = selectedCategoryIDs ??= ids.toSet();
    sel.addAll(ids.toSet().difference(_lastFilterIDs.toSet()));
    sel.retainAll(ids);
    _lastFilterIDs = ids;
    return sel;
  }

  List<Expense> _filtered(Set<String> sel) {
    final q = search.toLowerCase();
    final list = expenseStore.expenses.where((e) {
      final cat = categories.category(e.categoryID);
      return e.date.month == month &&
          e.date.year == year &&
          (q.isEmpty ||
              e.title.toLowerCase().contains(q) ||
              cat.displayName.toLowerCase().contains(q) ||
              (e.notes?.toLowerCase().contains(q) ?? false)) &&
          sel.contains(e.categoryID) &&
          typeFilter.matches(e);
    }).toList();
    switch (sort) {
      case SortOption.dateDescending:
        list.sort((a, b) => b.date.compareTo(a.date));
      case SortOption.dateAscending:
        list.sort((a, b) => a.date.compareTo(b.date));
      case SortOption.amountDescending:
        list.sort((a, b) => b.price.compareTo(a.price));
      case SortOption.amountAscending:
        list.sort((a, b) => a.price.compareTo(b.price));
      case SortOption.titleAscending:
        list.sort((a, b) => a.title.compareTo(b.title));
    }
    return list;
  }

  void _delete(Expense e) {
    _deleted = [e];
    expenseStore.remove(e.id);
    _undoTimer?.cancel();
    _undoTimer = Timer(const Duration(seconds: 3), () => setState(() => _deleted = []));
    setState(() {});
  }

  void _undo() {
    _undoTimer?.cancel();
    expenseStore.expenses.addAll(_deleted);
    expenseStore.save();
    setState(() => _deleted = []);
  }

  void _add() => showSheet(context, const TransactionForm());
  void _edit(Expense e) => showSheet(context, TransactionForm(key: ValueKey(e.id), expense: e));

  @override
  Widget build(BuildContext context) => StoreBuilder(builder: (context) {
        final sel = _syncSelection();
        final items = _filtered(sel);
        final grouped = <String, List<Expense>>{};
        for (final e in items) {
          grouped.putIfAbsent(e.categoryID, () => []).add(e);
        }
        final spent = items.where((e) => e.type == TransactionType.expense).fold(0.0, (s, e) => s + e.price);
        final income = items.where((e) => e.type == TransactionType.income).fold(0.0, (s, e) => s + e.price);
        final budget = analytics.monthlyBudgets[budgetKey(month, year)] ?? 0;

        return Stack(children: [
          LargeTitlePage(
            title: 'Transactions',
            background: context.groupedBg,
            onRefresh: () => pocketBase.sync(),
            leading: _toolbarFilters(context),
            trailing: CupertinoButton(padding: EdgeInsets.zero, onPressed: _add, child: const Icon(CupertinoIcons.add)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: CupertinoSearchTextField(
                  placeholder: 'Search transactions',
                  onChanged: (v) => setState(() => search = v),
                ),
              ),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: constrained(Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: MonthYearPicker(
                    month: month,
                    year: year,
                    monthsToShow: 61,
                    onChanged: (m, y) => setState(() {
                      month = m;
                      year = y;
                    }),
                  ),
                )),
              ),
              if (items.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _emptyState(context, sel))
              else ...[
                SliverToBoxAdapter(
                  child: constrained(Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _summary(context, income, spent, items.length, budget),
                  )),
                ),
                for (final id in categories.orderedIDs(grouped.keys.toSet()))
                  SliverToBoxAdapter(child: constrained(_section(context, id, grouped[id]!))),
                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            ],
          ),
          if (_deleted.isNotEmpty) _snackbar(context),
        ]);
      });

  Widget _toolbarFilters(BuildContext context) {
    final color = context.accent;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      MenuPicker<SortOption>(
        items: [for (final o in SortOption.values) (o, Text(o.label))],
        selected: sort,
        onSelected: (o) => setState(() => sort = o),
        child: Icon(CupertinoIcons.arrow_up_arrow_down, color: color, size: 22),
      ),
      gap(16),
      MenuPicker<TransactionFilter>(
        items: [for (final o in TransactionFilter.values) (o, Text(o.label))],
        selected: typeFilter,
        onSelected: (o) => setState(() => typeFilter = o),
        child: Icon(CupertinoIcons.line_horizontal_3_decrease, color: color, size: 22),
      ),
      gap(16),
      GestureDetector(
        onTap: () async {
          final result = await showModalBottomSheet<Set<String>>(
            context: context,
            useRootNavigator: true,
            backgroundColor: context.groupedBg,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
            builder: (_) => _FilterSheet(selected: selectedCategoryIDs!, categories: filterCategories),
          );
          if (result != null) setState(() => selectedCategoryIDs = result);
        },
        child: Icon(CupertinoIcons.line_horizontal_3_decrease_circle, color: color, size: 22),
      ),
    ]);
  }

  Widget _summary(BuildContext context, double income, double spent, int count, double budget) {
    final net = income - spent;
    Widget metric(String t, double v, Color c) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Sec(t),
            gap(4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(settings.money(v), style: Font.title3.copyWith(fontWeight: bold, color: context.c(c))),
            ),
          ]),
        );
    const div = Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: SizedBox(height: 44, child: VerticalDivider(width: 1)));
    final p = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.bg2,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Row(children: [
          metric('Income', income, SysColor.green),
          div,
          metric('Spent', spent, CupertinoColors.label),
          div,
          metric('Net', net, net >= 0 ? SysColor.green : SysColor.red),
          div,
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Sec('Items'),
            gap(4),
            Text('$count', style: Font.title3.copyWith(fontWeight: bold)),
          ]),
        ]),
        if (budget > 0) ...[
          gap(),
          Row(children: [
            const Expanded(child: Sec('Monthly Budget', style: Font.caption)),
            Sec('${settings.money(spent)} of ${settings.money(budget)}', style: Font.caption),
          ]),
          gap(6),
          ProgressBar(progress: p, height: 6, radius: 4, color: context.c(budgetColor(p))),
        ],
      ]),
    );
  }

  Widget _section(BuildContext context, String id, List<Expense> list) {
    final cat = categories.category(id);
    final total = list.fold(0.0, (s, e) => s + (e.type == TransactionType.income ? e.price : -e.price));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
          child: Row(children: [
            IconBadge(cat, size: 28, iconSize: 12, circle: true),
            gap(8),
            Expanded(child: Text(cat.displayName, style: Font.headline)),
            Text(settings.money(total),
                style: Font.subheadline.copyWith(color: total >= 0 ? context.c(SysColor.green) : context.secondaryLabel)),
          ]),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: context.groupedBg2,
            child: Column(children: [
              for (final (i, e) in list.indexed) ...[
                if (i > 0) const Padding(padding: EdgeInsets.only(left: 68), child: Divider()),
                _row(context, e),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, Expense e) {
    Future<void> menu(Offset pos) async {
      final choice = await showMenu<String>(
        context: context,
        color: context.bg2,
        position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
        items: [
          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(CupertinoIcons.pencil), SizedBox(width: 8), Text('Edit')])),
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(CupertinoIcons.trash, color: context.c(SysColor.red)),
              gap(8),
              Text('Delete', style: TextStyle(color: context.c(SysColor.red))),
            ]),
          ),
        ],
      );
      if (choice == 'edit') _edit(e);
      if (choice == 'delete') _delete(e);
    }

    Widget swipeBg(Color c, IconData icon, String label, Alignment a) => Container(
          color: c,
          alignment: a,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ]),
        );

    return Dismissible(
      key: ValueKey(e.id),
      // Leading swipe deletes, trailing swipe edits (as on iOS).
      background: swipeBg(context.c(SysColor.red), CupertinoIcons.trash, 'Delete', Alignment.centerLeft),
      secondaryBackground: swipeBg(context.accent, CupertinoIcons.pencil, 'Edit', Alignment.centerRight),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.endToStart) {
          _edit(e);
          return false;
        }
        return true;
      },
      onDismissed: (_) => _delete(e),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _edit(e),
        onLongPressStart: (d) => menu(d.globalPosition),
        onSecondaryTapDown: (d) => menu(d.globalPosition),
        child: _ExpenseRow(e),
      ),
    );
  }

  Widget _emptyState(BuildContext context, Set<String> sel) {
    final allIDs = filterCategories.length;
    Widget msg(String t) =>
        Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Sec(t, style: Font.body, align: TextAlign.center));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Icon(CupertinoIcons.doc_text_search, size: 70, color: Colors.grey.withValues(alpha: 0.6)),
        ),
        gap(20),
        Text('No Transactions Found', style: Font.title2.copyWith(fontWeight: bold)),
        gap(20),
        if (search.isNotEmpty)
          msg('Try adjusting your search or filters')
        else if (sel.length < allIDs) ...[
          msg('Try selecting more categories in the filter'),
          gap(28),
          GestureDetector(
            onTap: () => setState(() => selectedCategoryIDs = {for (final c in filterCategories) c.id}),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(border: Border.all(color: context.accent), borderRadius: BorderRadius.circular(8)),
              child: Text('Reset Filters', style: TextStyle(color: context.accent)),
            ),
          ),
        ] else ...[
          msg('Add your first transaction for ${DateFormat.MMMM().format(DateTime(year, month))} $year'),
          gap(28),
          GestureDetector(
            onTap: _add,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(color: context.accent, borderRadius: BorderRadius.circular(10)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(CupertinoIcons.add, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text('Add Transaction', style: TextStyle(color: Colors.white, fontSize: 17)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _snackbar(BuildContext context) => Positioned(
        left: 16,
        right: 16,
        bottom: 8 + MediaQuery.paddingOf(context).bottom,
        child: constrained(TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: 0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          builder: (_, t, c) => Transform.translate(offset: Offset(0, 60 * t), child: Opacity(opacity: 1 - t, child: c)),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 5, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Icon(CupertinoIcons.checkmark_circle_fill, color: context.c(SysColor.green)),
              gap(8),
              const Expanded(child: Text('Transaction deleted', style: TextStyle(color: Colors.white, fontSize: 17))),
              GestureDetector(
                onTap: _undo,
                child: const Text('Undo', style: TextStyle(color: Colors.yellow, fontWeight: bold, fontSize: 17)),
              ),
            ]),
          ),
        )),
      );
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow(this.e);
  final Expense e;
  @override
  Widget build(BuildContext context) {
    final cat = categories.category(e.categoryID);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
          width: 40,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: context.bg3, borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            Text('${e.date.day}', style: const TextStyle(fontSize: 18, fontWeight: semibold)),
            gap(2),
            Sec(DateFormat.MMM().format(e.date).toUpperCase(), style: Font.caption2),
          ]),
        ),
        gap(12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Font.headline),
            gap(4),
            Row(children: [
              Icon(sfIcon(cat.iconName), size: 11, color: cat.color),
              gap(6),
              Flexible(
                child: Sec('${cat.displayName}  •  ${DateFormat('E, d MMM yyyy').format(e.date)}',
                    style: Font.caption),
              ),
            ]),
          ]),
        ),
        gap(8),
        Text(amountText(e), style: Font.headline.copyWith(fontWeight: bold, color: amountColor(context, e))),
      ]),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.selected, required this.categories});
  final Set<String> selected;
  final List<FinanceCategory> categories;
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final temp = {...widget.selected};

  @override
  Widget build(BuildContext context) => InlinePage(
        title: 'Filter',
        leading: NavText('Cancel', () => Navigator.pop(context)),
        trailing: NavText('Apply', () => Navigator.pop(context, temp), bold: true),
        body: ListView(children: [
          CupertinoListSection.insetGrouped(
            header: SectionLabel('CATEGORIES'),
            footer: SectionLabel('Select which categories to display'),
            children: [
              for (final c in widget.categories)
                CupertinoListTile(
                  leading: IconBadge(c, size: 28, iconSize: 12, circle: true),
                  title: Text(c.displayName),
                  trailing: temp.contains(c.id) ? Icon(CupertinoIcons.checkmark, color: context.accent) : null,
                  onTap: () => setState(() {
                    if (temp.contains(c.id)) {
                      if (temp.length > 1) temp.remove(c.id);
                    } else {
                      temp.add(c.id);
                    }
                  }),
                ),
            ],
          ),
        ]),
      );
}
