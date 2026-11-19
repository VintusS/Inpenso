import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode, Color, IconData;
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'theme.dart';

late SharedPreferences _prefs;

Future<void> initStorage() async => _prefs = await SharedPreferences.getInstance();

/// Port of StorageService: same keys and JSON shapes as the iOS app.
class Storage {
  static const _expenses = 'expenses', _budgets = 'budgets';
  static const _catalog = 'categoryCatalogState', _custom = 'customCategories';

  static T? _read<T>(String key, T Function(dynamic) decode) {
    final s = _prefs.getString(key);
    if (s == null) return null;
    try {
      return decode(jsonDecode(s));
    } catch (_) {
      return null;
    }
  }

  static List<Expense> loadExpenses() =>
      _read(_expenses, (d) => [for (final e in d as List) Expense.fromJson(e)]) ?? [];
  static void saveExpenses(List<Expense> e) =>
      _prefs.setString(_expenses, jsonEncode([for (final x in e) x.toJson()]));

  static Map<String, double> loadBudgets() =>
      _read(_budgets, (d) => {for (final e in (d as Map).entries) e.key as String: (e.value as num).toDouble()}) ??
      {};
  static void saveBudgets(Map<String, double> b) => _prefs.setString(_budgets, jsonEncode(b));

  static List<FinanceCategory> loadCustomCategories() =>
      _read(_custom, (d) => [for (final c in d as List) FinanceCategory.fromJson(c)]) ?? [];
  static void saveCustomCategories(List<FinanceCategory> c) =>
      _prefs.setString(_custom, jsonEncode([for (final x in c) x.toJson()]));

  static CategoryCatalogState? loadCatalog() => _read(_catalog, (d) => CategoryCatalogState.fromJson(d));
  static void saveCatalog(CategoryCatalogState s) => _prefs.setString(_catalog, jsonEncode(s.toJson()));
}

const availableCurrencies = [
  ('USD', r'$', 'US Dollar'),
  ('EUR', '€', 'Euro'),
  ('MDL', 'L', 'Moldovan Leu'),
  ('GBP', '£', 'British Pound'),
  ('JPY', '¥', 'Japanese Yen'),
  ('CAD', r'$', 'Canadian Dollar'),
  ('AUD', r'$', 'Australian Dollar'),
  ('CHF', 'Fr', 'Swiss Franc'),
  ('CNY', '¥', 'Chinese Yuan'),
  ('INR', '₹', 'Indian Rupee'),
  ('RUB', '₽', 'Russian Ruble'),
];

enum AppTheme {
  light('Light', ThemeMode.light),
  dark('Dark', ThemeMode.dark),
  system('System', ThemeMode.system);

  const AppTheme(this.displayName, this.mode);
  final String displayName;
  final ThemeMode mode;
}

class SettingsStore extends ChangeNotifier {
  String _currency = _prefs.getString('selectedCurrency') ?? 'USD';
  String _defaultCategoryID = _prefs.getString('defaultCategoryID') ?? builtInID('food');
  AppTheme _theme = AppTheme.values.asNameMap()[_prefs.getString('selectedTheme')] ?? AppTheme.system;

  String get currency => _currency;
  set currency(String v) {
    _currency = v;
    _prefs.setString('selectedCurrency', v);
    notifyListeners();
  }

  String get defaultCategoryID => _defaultCategoryID;
  set defaultCategoryID(String v) {
    _defaultCategoryID = v;
    _prefs.setString('defaultCategoryID', v);
    notifyListeners();
  }

  AppTheme get theme => _theme;
  set theme(AppTheme v) {
    _theme = v;
    _prefs.setString('selectedTheme', v.name);
    notifyListeners();
  }

  String money(double v) => NumberFormat.simpleCurrency(name: _currency).format(v);
  String get currencySymbol => NumberFormat.simpleCurrency(name: _currency).currencySymbol;

  void normalizeDefaultCategory() {
    final preferred = categories.preferredCategoryID(_defaultCategoryID);
    if (preferred != _defaultCategoryID) defaultCategoryID = preferred;
  }
}

class CategoryStore extends ChangeNotifier {
  late CategoryCatalogState _state;

  CategoryStore() {
    final saved = Storage.loadCatalog();
    if (saved != null) {
      _state = _normalized(saved);
    } else {
      final custom = [for (final c in Storage.loadCustomCategories()) c..isCustom = true];
      _state = CategoryCatalogState(
        orderedCategoryIDs: [for (final c in FinanceCategory.builtIns) c.id, for (final c in custom) c.id],
        customCategories: custom,
      );
      _save();
    }
  }

  static final _builtInIDs = {for (final c in FinanceCategory.builtIns) c.id};

  Map<String, FinanceCategory> get _map => {
        for (final c in FinanceCategory.builtIns) c.id: _state.builtInOverrides[c.id] ?? c,
        for (final c in _state.customCategories) c.id: c,
      };

  List<FinanceCategory> _ordered(bool includeHidden) {
    final m = _map;
    return [
      for (final id in _state.orderedCategoryIDs)
        if ((includeHidden || !_state.hiddenCategoryIDs.contains(id)) && m[id] != null) m[id]!,
    ];
  }

  List<FinanceCategory> get visible => _ordered(false);
  List<FinanceCategory> visibleFor(TransactionType t) => visible.where((c) => c.type == t).toList();
  List<FinanceCategory> get hidden =>
      _ordered(true).where((c) => _state.hiddenCategoryIDs.contains(c.id)).toList();

  FinanceCategory category(String id) => _map[id] ?? FinanceCategory.fallback;

  List<FinanceCategory> forPicker(String? including, TransactionType type) {
    final list = visibleFor(type);
    final c = including == null || including.isEmpty ? null : _map[including];
    if (c != null && !list.any((x) => x.id == including)) list.add(c);
    return list;
  }

  List<FinanceCategory> forFilter(Set<String> usedIDs) {
    final v = visible;
    final extra = usedIDs.difference({for (final c in v) c.id});
    final m = _map;
    return [...v, for (final id in orderedIDs(extra)) if (m[id] != null) m[id]!];
  }

  List<String> orderedIDs(Set<String> ids) {
    final ordered = _state.orderedCategoryIDs.where(ids.contains).toList();
    final rest = ids.difference(ordered.toSet()).toList()
      ..sort((a, b) => category(a).displayName.toLowerCase().compareTo(category(b).displayName.toLowerCase()));
    return [...ordered, ...rest];
  }

  String preferredCategoryID(String? id, [TransactionType type = TransactionType.expense]) {
    if (id != null && !_state.hiddenCategoryIDs.contains(id) && _map[id]?.type == type) return id;
    final v = visibleFor(type);
    return v.isNotEmpty ? v.first.id : FinanceCategory.fallback.id;
  }

  void add(String name, String icon, String colorHex, [TransactionType type = TransactionType.expense]) {
    final c = FinanceCategory(
        id: 'custom-${newUUID()}', name: name.trim(), iconName: icon, colorHex: colorHex, isCustom: true, type: type);
    _state.customCategories.add(c);
    _state.orderedCategoryIDs.add(c.id);
    _save();
  }

  void update(FinanceCategory c) {
    if (c.isCustom) {
      final i = _state.customCategories.indexWhere((x) => x.id == c.id);
      if (i < 0) return;
      _state.customCategories[i] = c.copy()..isCustom = true;
    } else if (_builtInIDs.contains(c.id)) {
      _state.builtInOverrides[c.id] = c.copy()
        ..isCustom = false
        ..type = _map[c.id]!.type; // built-ins keep their type
    } else {
      return;
    }
    _save();
  }

  void hide(FinanceCategory c) {
    // Keep at least one visible category per type so each picker has a choice.
    if (_map[c.id] == null || _state.hiddenCategoryIDs.contains(c.id) || visibleFor(c.type).length <= 1) return;
    _state.hiddenCategoryIDs.add(c.id);
    _save();
  }

  void restore(FinanceCategory c) {
    if (_map[c.id] == null) return;
    _state.hiddenCategoryIDs.remove(c.id);
    if (!_state.orderedCategoryIDs.contains(c.id)) _state.orderedCategoryIDs.add(c.id);
    _save();
  }

  void move(String source, String dest) {
    final ids = _state.orderedCategoryIDs;
    if (source == dest || !ids.contains(source) || !ids.contains(dest)) return;
    ids.remove(source);
    ids.insert(ids.indexOf(dest), source);
    _save();
  }

  void resetOverride(String id) {
    if (!_builtInIDs.contains(id)) return;
    _state.builtInOverrides.remove(id);
    _save();
  }

  bool isHidden(String id) => _state.hiddenCategoryIDs.contains(id);
  bool hasOverride(String id) => _state.builtInOverrides.containsKey(id);

  void _save() {
    _state = _normalized(_state);
    Storage.saveCatalog(_state);
    Storage.saveCustomCategories(_state.customCategories);
    notifyListeners();
  }

  static CategoryCatalogState _normalized(CategoryCatalogState s) {
    final seen = <String>{};
    final custom = [
      for (final c in s.customCategories)
        if (!_builtInIDs.contains(c.id) && seen.add(c.id)) c..isCustom = true,
    ];
    final overrides = {
      for (final e in s.builtInOverrides.entries)
        if (_builtInIDs.contains(e.key))
          e.key: e.value
            ..id = e.key
            ..isCustom = false,
    };
    final known = [for (final c in FinanceCategory.builtIns) c.id, for (final c in custom) c.id];
    final knownSet = known.toSet();
    final ordered = <String>[];
    for (final id in s.orderedCategoryIDs) {
      if (knownSet.contains(id) && !ordered.contains(id)) ordered.add(id);
    }
    for (final id in known) {
      if (!ordered.contains(id)) ordered.add(id);
    }
    return CategoryCatalogState(
      orderedCategoryIDs: ordered,
      customCategories: custom,
      builtInOverrides: overrides,
      hiddenCategoryIDs: s.hiddenCategoryIDs.intersection(knownSet),
    );
  }
}

class ExpenseStore extends ChangeNotifier {
  List<Expense> expenses = Storage.loadExpenses();

  void add(Expense e) {
    expenses.add(e);
    save();
  }

  void remove(String id) {
    expenses.removeWhere((e) => e.id == id);
    save();
  }

  void save() {
    Storage.saveExpenses(expenses);
    notifyListeners();
  }

  void reload() {
    expenses = Storage.loadExpenses();
    notifyListeners();
  }

  /// PocketBase is the source of truth for synced rows: replace them all, keep manual ones.
  void replaceRemote(List<Expense> remote) {
    expenses = [...expenses.where((e) => !e.id.startsWith(pbPrefix)), ...remote];
    save();
  }
}

// ---------------------------------------------------------------- PocketBase bank sync

const pbPrefix = 'pb-';

/// Maps a finance-tracker `transactions` row (bank data from Enable Banking) to an Expense.
/// [catNames] maps PocketBase category id -> name; matched to a local category by name, else Others.
Expense? expenseFromPb(RecordModel r, Map<String, String> catNames) {
  final booked = DateTime.tryParse(r.getStringValue('bookingDate'));
  if (booked == null) return null;
  final cents = r.getIntValue('amountCents');
  final title = r.getStringValue('title');
  final type = cents > 0 ? TransactionType.income : TransactionType.expense;
  final catName = catNames[r.getStringValue('category')]?.toLowerCase();
  final local = categories.visibleFor(type).where((c) => c.displayName.toLowerCase() == catName);
  final bank = r.getStringValue('expand.account.bank');
  return Expense(
    id: '$pbPrefix${r.id}',
    title: title.isNotEmpty ? title : r.getStringValue('description'),
    // shortcut: ignores the row's currency (assumes it matches the app currency); convert if accounts differ.
    price: cents.abs() / 100,
    date: DateTime(booked.year, booked.month, booked.day),
    type: type,
    categoryID: local.isEmpty ? categories.preferredCategoryID(null, type) : local.first.id,
    notes: bank.isEmpty ? null : bank,
  );
}

class PocketBaseStore extends ChangeNotifier {
  late PocketBase pb = _client(url);
  String? error;
  bool syncing = false;

  String get url => _prefs.getString('pbUrl') ?? '';
  bool get connected => url.isNotEmpty && pb.authStore.isValid;
  String get email => pb.authStore.record?.getStringValue('email') ?? '';

  // Only the auth token is persisted, never the password.
  static PocketBase _client(String url) => PocketBase(url,
      authStore: AsyncAuthStore(
        initial: _prefs.getString('pbAuth'),
        save: (s) => _prefs.setString('pbAuth', s),
        clear: () => _prefs.remove('pbAuth'),
      ));

  /// Throws ClientException on bad URL/credentials so the login form can show it.
  Future<void> connect(String serverUrl, String email, String password) async {
    final client = _client(serverUrl.trim());
    await client.collection('users').authWithPassword(email.trim(), password);
    await _prefs.setString('pbUrl', serverUrl.trim());
    pb = client;
    await sync();
  }

  void disconnect() {
    pb.authStore.clear();
    expenseStore.replaceRemote([]);
    notifyListeners();
  }

  Future<void> sync() async {
    if (!connected || syncing) return;
    syncing = true;
    notifyListeners();
    try {
      await pb.collection('users').authRefresh(); // keeps the token alive while the app is used
      final cats = {
        for (final c in await pb.collection('categories').getFullList()) c.id: c.getStringValue('name'),
      };
      final rows = await pb.collection('transactions').getFullList(expand: 'account');
      expenseStore.replaceRemote([for (final r in rows) ?expenseFromPb(r, cats)]);
      error = null;
    } on ClientException catch (e) {
      if (e.statusCode == 401) pb.authStore.clear();
      error = (e.response['message'] as String?) ?? 'Cannot reach the server.';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }
}

// ---------------------------------------------------------------- Analytics

enum InsightType { positive, neutral, negative }

class SpendingInsight {
  final InsightType type;
  final String title, description;
  final IconData icon;
  final Color color;
  const SpendingInsight(this.type, this.title, this.description, this.icon, this.color);
}

class DailySpending {
  final DateTime date;
  final double amount;
  int get dayOfMonth => date.day;
  String get weekday => DateFormat('EEE').format(date);
  const DailySpending(this.date, this.amount);
}

class MonthlyTrend {
  final int month, year;
  final double amount;
  String get shortMonthName => DateFormat('MMM').format(DateTime(year, month));
  const MonthlyTrend(this.month, this.year, this.amount);
}

class CategoryTrend {
  final String categoryID;
  final double previousAmount, currentAmount;
  double get percentChange =>
      previousAmount > 0 ? (currentAmount - previousAmount) / previousAmount * 100 : (currentAmount > 0 ? 100 : 0);
  bool get isIncreasing => currentAmount > previousAmount;
  const CategoryTrend(this.categoryID, this.previousAmount, this.currentAmount);
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
int _daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
String budgetKey(int month, int year) => '${month.toString().padLeft(2, '0')}-$year';

/// Port of AnalyticsViewModel. Shared by Home and Analytics, like on iOS.
class AnalyticsStore extends ChangeNotifier {
  double totalSpent = 0, totalIncome = 0, netCashflow = 0;
  Map<String, double> spendingByCategory = {}, incomeByCategory = {};
  List<DailySpending> dailySpending = [];
  List<MonthlyTrend> monthlyTrends = [];
  List<CategoryTrend> categoryTrends = [];
  List<SpendingInsight> insights = [];
  double averageDailySpend = 0, projectedMonthlySpend = 0;
  (String, double)? biggestExpenseCategory, fastestGrowingCategory;

  int selectedMonth = DateTime.now().month, selectedYear = DateTime.now().year;
  Map<String, double> monthlyBudgets = Storage.loadBudgets();
  double currentBudget = 0, budgetRemainingPerDay = 0;
  int daysRemainingInMonth = 0;

  AnalyticsStore() {
    expenseStore.addListener(calculate);
    categories.addListener(calculate);
    settings.addListener(calculate);
    calculate();
  }

  List<Expense> get _all => expenseStore.expenses;

  Map<String, double> _totals(Iterable<Expense> list) {
    final t = <String, double>{};
    for (final e in list) {
      t[e.categoryID] = (t[e.categoryID] ?? 0) + e.price;
    }
    return t;
  }

  Iterable<Expense> _inMonth(int m, int y, TransactionType? type) =>
      _all.where((e) => e.date.month == m && e.date.year == y && (type == null || e.type == type));

  void changeMonth(int month, int year) {
    selectedMonth = month;
    selectedYear = year;
    calculate();
  }

  void reloadBudgets() {
    monthlyBudgets = Storage.loadBudgets();
    calculate();
  }

  void saveBudget(double amount) {
    currentBudget = amount;
    monthlyBudgets[budgetKey(selectedMonth, selectedYear)] = amount;
    Storage.saveBudgets(monthlyBudgets);
    calculate();
  }

  void calculate() {
    final exp = _inMonth(selectedMonth, selectedYear, TransactionType.expense).toList();
    final inc = _inMonth(selectedMonth, selectedYear, TransactionType.income).toList();
    totalSpent = exp.fold(0, (s, e) => s + e.price);
    totalIncome = inc.fold(0, (s, e) => s + e.price);
    netCashflow = totalIncome - totalSpent;
    spendingByCategory = _totals(exp);
    incomeByCategory = _totals(inc);
    biggestExpenseCategory = spendingByCategory.isEmpty
        ? null
        : spendingByCategory.entries.reduce((a, b) => b.value > a.value ? b : a).toRecord();

    // Daily spending
    final byDay = <DateTime, double>{};
    for (final e in exp) {
      byDay[_day(e.date)] = (byDay[_day(e.date)] ?? 0) + e.price;
    }
    final daysInMonth = DateTime(selectedYear, selectedMonth + 1, 0).day;
    dailySpending = [
      for (var d = 1; d <= daysInMonth; d++)
        DailySpending(DateTime(selectedYear, selectedMonth, d), byDay[DateTime(selectedYear, selectedMonth, d)] ?? 0),
    ];
    final active = dailySpending.where((d) => d.amount > 0);
    averageDailySpend = active.isEmpty ? 0 : active.fold(0.0, (s, d) => s + d.amount) / active.length;
    projectedMonthlySpend = averageDailySpend > 0 ? averageDailySpend * dailySpending.length : totalSpent;

    // Monthly trends: the last 6 months counted from today
    final now = DateTime.now();
    monthlyTrends = [
      for (var i = 5; i >= 0; i--)
        () {
          final d = DateTime(now.year, now.month - i);
          return MonthlyTrend(d.month, d.year,
              _inMonth(d.month, d.year, TransactionType.expense).fold(0.0, (s, e) => s + e.price));
        }(),
    ];

    // Category trends vs previous month
    final prev = DateTime(selectedYear, selectedMonth - 1);
    final cur = _totals(exp);
    final prv = _totals(_inMonth(prev.month, prev.year, TransactionType.expense));
    categoryTrends = [
      for (final id in {...cur.keys, ...prv.keys})
        if ((cur[id] ?? 0) > 0 || (prv[id] ?? 0) > 0) CategoryTrend(id, prv[id] ?? 0, cur[id] ?? 0),
    ];
    final growing = categoryTrends.where((t) => t.previousAmount > 0 && t.currentAmount > t.previousAmount);
    fastestGrowingCategory = growing.isEmpty
        ? null
        : () {
            final t = growing.reduce((a, b) => b.percentChange > a.percentChange ? b : a);
            return (t.categoryID, t.percentChange);
          }();

    currentBudget = monthlyBudgets[budgetKey(selectedMonth, selectedYear)] ?? 0;
    _daysRemaining();
    _insights();
    notifyListeners();
  }

  void _daysRemaining() {
    final today = _day(DateTime.now());
    final start = DateTime(selectedYear, selectedMonth, 1);
    final end = DateTime(selectedYear, selectedMonth + 1, 0);
    if (end.isBefore(today)) {
      daysRemainingInMonth = 0;
      budgetRemainingPerDay = 0;
    } else if (start.isAfter(today)) {
      daysRemainingInMonth = end.day;
      budgetRemainingPerDay = currentBudget / daysRemainingInMonth;
    } else {
      daysRemainingInMonth = _daysBetween(today, end);
      final remaining = max(0.0, currentBudget - totalSpent);
      budgetRemainingPerDay = daysRemainingInMonth > 0 ? remaining / daysRemainingInMonth : 0;
    }
  }

  void _insights() {
    final out = <SpendingInsight>[];
    if (currentBudget > 0) {
      final pct = totalSpent / currentBudget * 100;
      if (pct >= 90) {
        out.add(SpendingInsight(InsightType.negative, 'Budget Alert',
            "You've used ${pct.toInt()}% of your monthly budget.", IconDataRef.warning, SysColor.red));
      } else if (pct >= 75) {
        out.add(SpendingInsight(InsightType.neutral, 'Budget Notice',
            "You've used ${pct.toInt()}% of your monthly budget.", IconDataRef.bell, SysColor.orange));
      } else if (daysRemainingInMonth < 7 && pct < 60) {
        out.add(SpendingInsight(InsightType.positive, 'Under Budget', "Great job! You're under budget this month.",
            IconDataRef.checkCircle, SysColor.green));
      }
    }
    final fg = fastestGrowingCategory;
    if (fg != null && fg.$2 > 30) {
      out.add(SpendingInsight(
          InsightType.negative,
          'Spending Increase',
          '${categories.category(fg.$1).displayName} spending increased by ${fg.$2.toInt()}% from last month.',
          IconDataRef.arrowUpRight,
          SysColor.red));
    }
    final reduced = categoryTrends
        .where((t) => t.previousAmount > 0 && t.currentAmount < t.previousAmount && t.percentChange.abs() > 20);
    if (reduced.isNotEmpty) {
      final best = reduced.reduce((a, b) => b.percentChange < a.percentChange ? b : a);
      out.add(SpendingInsight(
          InsightType.positive,
          'Spending Decrease',
          'You reduced ${categories.category(best.categoryID).displayName} spending by ${best.percentChange.abs().toInt()}%.',
          IconDataRef.arrowDownRight,
          SysColor.green));
    }
    if (projectedMonthlySpend > currentBudget && currentBudget > 0) {
      out.add(SpendingInsight(
          InsightType.negative,
          'Projected Overspending',
          'At this rate, you might exceed your budget by ${settings.money(projectedMonthlySpend - currentBudget)}.',
          IconDataRef.trendingUp,
          SysColor.red));
    }
    insights = out;
  }
}

extension on MapEntry<String, double> {
  (String, double) toRecord() => (key, value);
}

// App-wide singletons (the iOS app injects these as environment objects).
late final SettingsStore settings;
late final CategoryStore categories;
late final ExpenseStore expenseStore;
late final AnalyticsStore analytics;
late final PocketBaseStore pocketBase;

Future<void> initStores() async {
  await initStorage();
  settings = SettingsStore();
  categories = CategoryStore();
  expenseStore = ExpenseStore();
  analytics = AnalyticsStore();
  pocketBase = PocketBaseStore();
  pocketBase.sync(); // background; no-op when not connected
}

/// Export payload in the iOS format (pretty-printed array of expenses).
Uint8List exportJson() => Uint8List.fromList(
    utf8.encode(const JsonEncoder.withIndent('  ').convert([for (final e in Storage.loadExpenses()) e.toJson()])));

bool importJson(List<int> bytes) {
  try {
    final list = [for (final e in jsonDecode(utf8.decode(bytes)) as List) Expense.fromJson(e)];
    Storage.saveExpenses(list);
    expenseStore.reload();
    return true;
  } catch (_) {
    return false;
  }
}

void resetAllData() {
  Storage.saveExpenses([]);
  Storage.saveBudgets({});
  expenseStore.reload();
  analytics.reloadBudgets();
}
