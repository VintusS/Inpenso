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
  static void saveBudgets(Map<String, double> b) => put(_budgets, jsonEncode(b));

  static List<FinanceCategory> loadCustomCategories() =>
      _read(_custom, (d) => [for (final c in d as List) FinanceCategory.fromJson(c)]) ?? [];
  static void saveCustomCategories(List<FinanceCategory> c) =>
      _prefs.setString(_custom, jsonEncode([for (final x in c) x.toJson()]));

  static CategoryCatalogState? loadCatalog() => _read(_catalog, (d) => CategoryCatalogState.fromJson(d));
  static void saveCatalog(CategoryCatalogState s) => _prefs.setString(_catalog, jsonEncode(s.toJson()));

  /// Writes a synced preference locally and to PocketBase (when connected).
  static void put(String key, String value) {
    _prefs.setString(key, value);
    _remote?.putPref(key, value);
  }
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
  late String _currency, _defaultCategoryID;
  late AppTheme _theme;

  SettingsStore() {
    _load();
  }

  void _load() {
    _currency = _prefs.getString('selectedCurrency') ?? 'USD';
    _defaultCategoryID = _prefs.getString('defaultCategoryID') ?? builtInID('food');
    _theme = AppTheme.values.asNameMap()[_prefs.getString('selectedTheme')] ?? AppTheme.system;
  }

  void reload() {
    _load();
    notifyListeners();
  }

  String get currency => _currency;
  set currency(String v) {
    _currency = v;
    Storage.put('selectedCurrency', v);
    notifyListeners();
  }

  String get defaultCategoryID => _defaultCategoryID;
  set defaultCategoryID(String v) {
    _defaultCategoryID = v;
    Storage.put('defaultCategoryID', v);
    notifyListeners();
  }

  AppTheme get theme => _theme;
  set theme(AppTheme v) {
    _theme = v;
    Storage.put('selectedTheme', v.name);
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

  void reload() {
    final saved = Storage.loadCatalog();
    if (saved == null) return;
    _state = _normalized(saved);
    notifyListeners();
  }

  void addAll(List<FinanceCategory> custom) {
    if (custom.isEmpty) return;
    _state.customCategories.addAll(custom);
    _state.orderedCategoryIDs.addAll([for (final c in custom) c.id]);
    _save();
  }

  static final _builtInIDs = {for (final c in FinanceCategory.builtIns) c.id};

  /// One PocketBase `categories` row per category, built-ins included (key = Inpenso id).
  Map<String, Map<String, dynamic>> get rows {
    final m = _map;
    var i = 0;
    return {
      for (final id in _state.orderedCategoryIDs)
        if (m[id] != null) id: categoryRow(m[id]!, i++, _state.hiddenCategoryIDs.contains(id)),
    };
  }

  /// Replaces the catalog with the server's `categories` rows (no push back).
  void replaceFromRows(List<RecordModel> rows) {
    int order(RecordModel r) => r.getStringValue('key').isEmpty ? 1 << 30 : r.getIntValue('sortOrder'); // new ones last
    final sorted = [...rows]..sort((a, b) => order(a).compareTo(order(b)));
    // A built-in with no row was deleted.
    final s = CategoryCatalogState(deletedBuiltInIDs: _builtInIDs.difference({for (final r in rows) categoryKey(r)}));
    for (final r in sorted) {
      final key = categoryKey(r), icon = r.getStringValue('icon');
      final c = FinanceCategory(
          id: key,
          name: r.getStringValue('name'),
          iconName: icon.isEmpty ? 'tag.fill' : icon,
          colorHex: '#${(r.getIntValue('color') & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
          isCustom: !_builtInIDs.contains(key),
          type: r.getStringValue('type') == 'income' ? TransactionType.income : TransactionType.expense);
      s.orderedCategoryIDs.add(key);
      if (r.getBoolValue('hidden')) s.hiddenCategoryIDs.add(key);
      if (c.isCustom) {
        s.customCategories.add(c);
      } else {
        final d = FinanceCategory.builtIns.firstWhere((x) => x.id == key);
        // Only an edited built-in is an override (keeps "reset to default" meaningful).
        if (c.name != d.name || c.iconName != d.iconName || c.colorHex != d.colorHex.toUpperCase()) {
          s.builtInOverrides[key] = c;
        }
      }
    }
    _state = _normalized(s);
    _save(push: false);
  }

  Map<String, FinanceCategory> get _map => {
        for (final c in FinanceCategory.builtIns)
          if (!_state.deletedBuiltInIDs.contains(c.id)) c.id: _state.builtInOverrides[c.id] ?? c,
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

  FinanceCategory category(String id) =>
      id.isEmpty
          ? FinanceCategory.uncategorized
          : id == FinanceCategory.transferID
              ? FinanceCategory.transfer
              : _map[id] ?? FinanceCategory.fallback;

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
    return [
      ...v,
      for (final id in orderedIDs(extra)) if (m[id] != null) m[id]!,
      if (usedIDs.contains('')) FinanceCategory.uncategorized,
    ];
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

  /// Deletes the category; its transactions become uncategorized. Returns false for the last visible one of its type.
  bool delete(FinanceCategory c) {
    if (_map[c.id] == null) return false;
    if (!isHidden(c.id) && visibleFor(c.type).length <= 1) return false;
    if (c.isCustom) {
      _state.customCategories.removeWhere((x) => x.id == c.id);
    } else {
      _state.deletedBuiltInIDs.add(c.id);
      _state.builtInOverrides.remove(c.id);
    }
    _save();
    var changed = false;
    for (final e in expenseStore.expenses) {
      if (e.categoryID == c.id) {
        e.categoryID = '';
        changed = true;
      }
    }
    if (changed) expenseStore.save();
    return true;
  }

  int usage(String id) => expenseStore.expenses.where((e) => e.categoryID == id).length;

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

  void _save({bool push = true}) {
    _state = _normalized(_state);
    Storage.saveCatalog(_state);
    Storage.saveCustomCategories(_state.customCategories);
    if (push) _remote?.pushCategories();
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
    final deleted = s.deletedBuiltInIDs.intersection(_builtInIDs);
    final known = [
      for (final c in FinanceCategory.builtIns)
        if (!deleted.contains(c.id)) c.id,
      for (final c in custom) c.id,
    ];
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
      builtInOverrides: {for (final e in overrides.entries) if (!deleted.contains(e.key)) e.key: e.value},
      hiddenCategoryIDs: s.hiddenCategoryIDs.intersection(knownSet),
      deletedBuiltInIDs: deleted,
    );
  }
}

class ExpenseStore extends ChangeNotifier {
  List<Expense> expenses = Storage.loadExpenses();

  void add(Expense e) {
    expenses.add(e);
    save();
  }

  /// Caches locally and pushes the changes to PocketBase (when connected).
  void save() {
    replaceAll(expenses);
    _remote?.pushExpenses();
  }

  /// Sets the list (e.g. from the server) without pushing it back.
  void replaceAll(List<Expense> list) {
    expenses = list;
    Storage.saveExpenses(expenses);
    notifyListeners();
  }
}

// ---------------------------------------------------------------- PocketBase (source of truth)

/// Set once the PocketBase store exists; stores push their writes through it.
PocketBaseStore? _remote;

/// Preferences that live on the server (key = SharedPreferences key).
/// Categories are not here: they are rows of the `categories` collection.
const syncedPrefs = ['budgets', 'selectedCurrency', 'defaultCategoryID', 'selectedTheme'];

final _pbId = RegExp(r'^[a-z0-9]{15}$');

/// A PocketBase record id, so a new row keeps the same id locally and on the server.
String newPbId() {
  const a = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random.secure();
  return String.fromCharCodes([for (var i = 0; i < 15; i++) a.codeUnitAt(r.nextInt(a.length))]);
}

/// `transactions` row (bank from finance-tracker, or manual) -> Expense.
/// Dates are wall-clock time tagged as UTC, so a bank booking day stays the same day in any time zone.
Expense? expenseFromPb(RecordModel r) {
  final d = DateTime.tryParse(r.getStringValue('bookingDate'));
  if (d == null) return null;
  final cents = r.getIntValue('amountCents');
  final type = cents > 0 ? TransactionType.income : TransactionType.expense;
  final title = r.getStringValue('title'), notes = r.getStringValue('notes'), cat = r.getStringValue('categoryID');
  final bank = r.getStringValue('expand.account.bank');
  return Expense(
    id: r.id,
    title: title.isNotEmpty ? title : r.getStringValue('description'),
    // shortcut: ignores the row's currency (assumes it matches the app currency); convert if accounts differ.
    price: cents.abs() / 100,
    date: DateTime(d.year, d.month, d.day, d.hour, d.minute, d.second),
    type: type,
    categoryID: cat, // '' = uncategorized until the user picks one
    notes: notes.isNotEmpty ? notes : null,
    account: bank.isEmpty ? null : bank,
    transfer: r.getBoolValue('transfer'),
  );
}

/// A row added outside the app (e.g. the Notion import) has no key yet: its record id becomes it.
String categoryKey(RecordModel r) => r.getStringValue('key').isEmpty ? r.id : r.getStringValue('key');

/// FinanceCategory -> `categories` row (color as a 0xRRGGBB number, like the finance-tracker rows).
Map<String, dynamic> categoryRow(FinanceCategory c, int sortOrder, bool hidden) => {
      'key': c.id,
      'name': c.name,
      'icon': c.iconName,
      'color': c.color.toARGB32() & 0xFFFFFF,
      'type': c.type.name,
      'sortOrder': sortOrder,
      'hidden': hidden,
    };

/// Expense -> the `transactions` fields Inpenso owns (bank fields like description are never touched).
Map<String, dynamic> pbBody(Expense e) => {
      'title': e.title,
      'amountCents': (e.price * 100).round() * (e.type == TransactionType.income ? 1 : -1),
      'bookingDate':
          DateTime.utc(e.date.year, e.date.month, e.date.day, e.date.hour, e.date.minute, e.date.second).toIso8601String(),
      'categoryID': e.categoryID,
      'notes': e.notes ?? '',
      'transfer': e.transfer,
    };

class PocketBaseStore extends ChangeNotifier {
  late PocketBase pb = _client(url);
  String? error;
  bool syncing = false;
  final _pushed = <String, String>{}; // transaction id -> jsonEncode(pbBody) last known on the server
  final _prefIds = <String, String>{}; // pref key -> record id
  final _catPushed = <String, (String, String)>{}; // category key -> (record id, jsonEncode(row) on the server)
  Future<void> _queue = Future.value();

  PocketBaseStore() {
    _remote = this;
  }

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
    _pushed.clear();
    _prefIds.clear();
    _catPushed.clear();
    expenseStore.replaceAll([]); // the data lives on the server
    notifyListeners();
  }

  /// Runs server work one at a time, in order (a delete and its undo must not race).
  Future<void> _enqueue(Future<void> Function() f) => _queue = _queue.then((_) async {
        try {
          await f();
          error = null;
        } on ClientException catch (e) {
          if (e.statusCode == 401) pb.authStore.clear();
          error = (e.response['message'] as String?) ?? 'Cannot reach the server.';
        } catch (e) {
          error = '$e';
        } finally {
          notifyListeners();
        }
      });

  Future<void> sync() async {
    if (!connected || syncing) return;
    syncing = true;
    notifyListeners();
    await _enqueue(_pull);
    syncing = false;
    notifyListeners();
  }

  /// Server wins. Data that exists only on this device (first connect) is uploaded.
  Future<void> _pull() async {
    await pb.collection('users').authRefresh(); // keeps the token alive while the app is used
    final server = {for (final r in await pb.collection('prefs').getFullList()) r.getStringValue('key'): r};
    final rows = await pb.collection('transactions').getFullList(expand: 'account');
    final catRows = await pb.collection('categories').getFullList();
    // Rows without a key are old finance-tracker categories: the catalog has not been moved here yet.
    final migrated = catRows.any((r) => r.getStringValue('key').isNotEmpty);
    _catPushed
      ..clear()
      ..addAll({
        for (final r in catRows)
          if (migrated)
            categoryKey(r): (r.id, jsonEncode(_rowOf(r)))
          else
            r.id: (r.id, '') // adopted ones keep their id as key and get rewritten, the rest are deleted
      });

    _prefIds
      ..clear()
      ..addAll({for (final e in server.entries) e.key: e.value.id});
    for (final k in syncedPrefs) {
      final local = _prefs.getString(k);
      if (server[k] != null) {
        await _prefs.setString(k, server[k]!.getStringValue('value'));
      } else if (local != null) {
        _prefIds[k] = (await pb.collection('prefs').create(body: {'key': k, 'value': local})).id;
      }
    }
    var remap = <String, String>{};
    if (migrated) {
      categories.replaceFromRows(catRows);
    } else if (server['categoryCatalogState'] != null) {
      // Catalog from the old `prefs` blob.
      await _prefs.setString('categoryCatalogState', server['categoryCatalogState']!.getStringValue('value'));
      categories.reload();
    } else {
      remap = _adoptLegacyCategories(catRows, rows);
    }
    await _pushCategories(); // no-op unless migrating or a row lacks its key
    settings.reload();
    analytics.reloadBudgets();

    final remote = [for (final r in rows) ?expenseFromPb(r)];
    _pushed
      ..clear()
      ..addAll({for (final e in remote) e.id: jsonEncode(pbBody(e))});
    // Applied after the snapshot, so the remapped rows get pushed below.
    for (final e in remote) {
      e.categoryID = remap[e.categoryID] ?? e.categoryID;
    }
    // Added before connecting (not a PocketBase id; 'pb-' rows are the old read-only bank cache).
    final localOnly = [
      for (final e in expenseStore.expenses)
        if (!_pbId.hasMatch(e.id) && !e.id.startsWith('pb-')) e
    ];
    expenseStore.replaceAll([...remote, ...localOnly]);
    if (remap.isNotEmpty || localOnly.isNotEmpty) await _pushExpenses();
  }

  /// First connect: the old finance-tracker categories become Inpenso categories (same id, so rows keep
  /// pointing at them); one named like an existing category maps to it instead. Returns old id -> new id.
  Map<String, String> _adoptLegacyCategories(List<RecordModel> legacy, List<RecordModel> rows) {
    final remap = <String, String>{}, added = <FinanceCategory>[];
    for (final c in legacy) {
      final name = c.getStringValue('name'), color = c.getIntValue('color') & 0xFFFFFF;
      final used = rows.where((r) => r.getStringValue('categoryID') == c.id);
      final type = used.isNotEmpty && used.every((r) => r.getIntValue('amountCents') > 0)
          ? TransactionType.income
          : TransactionType.expense;
      final same = categories.visibleFor(type).where((x) => x.displayName.toLowerCase() == name.toLowerCase());
      if (same.isNotEmpty) {
        remap[c.id] = same.first.id;
      } else {
        added.add(FinanceCategory(
            id: c.id,
            name: name,
            iconName: 'tag.fill',
            colorHex: color == 0 ? '#8E8E93' : '#${color.toRadixString(16).padLeft(6, '0')}',
            isCustom: true,
            type: type));
      }
    }
    categories.addAll(added);
    return remap;
  }

  void putPref(String key, String value) {
    if (!connected) return;
    _enqueue(() async {
      final id = _prefIds[key];
      if (id != null) {
        await pb.collection('prefs').update(id, body: {'value': value});
      } else {
        _prefIds[key] = (await pb.collection('prefs').create(body: {'key': key, 'value': value})).id;
      }
    });
  }

  static Map<String, dynamic> _rowOf(RecordModel r) => {
        'key': r.getStringValue('key'),
        'name': r.getStringValue('name'),
        'icon': r.getStringValue('icon'),
        'color': r.getIntValue('color'),
        'type': r.getStringValue('type'),
        'sortOrder': r.getIntValue('sortOrder'),
        'hidden': r.getBoolValue('hidden'),
      };

  void pushCategories() {
    if (connected) _enqueue(_pushCategories);
  }

  /// Same diff as transactions: creates, updates and deletes the rows that changed.
  Future<void> _pushCategories() async {
    final col = pb.collection('categories'), rows = categories.rows;
    for (final MapEntry(key: k, value: body) in rows.entries) {
      final fp = jsonEncode(body), old = _catPushed[k];
      if (old?.$2 == fp) continue;
      final id = old == null ? (await col.create(body: body)).id : (await col.update(old.$1, body: body)).id;
      _catPushed[k] = (id, fp);
    }
    for (final k in [..._catPushed.keys]) {
      if (rows.containsKey(k)) continue;
      await col.delete(_catPushed[k]!.$1);
      _catPushed.remove(k);
    }
  }

  void pushExpenses() {
    if (connected) _enqueue(_pushExpenses);
  }

  /// Diffs the local list against the last server state: creates, updates and deletes what changed.
  Future<void> _pushExpenses() async {
    final col = pb.collection('transactions'), live = <String>{};
    for (final e in [...expenseStore.expenses]) {
      if (!_pbId.hasMatch(e.id)) e.id = newPbId(); // UUIDs from the form or an iOS import
      live.add(e.id);
      final body = pbBody(e), fp = jsonEncode(body), old = _pushed[e.id];
      if (old == fp) continue;
      if (old == null) {
        await col.create(body: {...body, 'id': e.id, 'currency': settings.currency});
      } else {
        await col.update(e.id, body: body);
      }
      _pushed[e.id] = fp;
    }
    for (final id in [..._pushed.keys]) {
      if (live.contains(id)) continue;
      await col.delete(id);
      _pushed.remove(id);
    }
    Storage.saveExpenses(expenseStore.expenses); // ids may have changed
  }

  /// Bank rows have a providerId; everything else was entered by hand.
  void deleteManual() => _enqueue(() async {
        final col = pb.collection('transactions');
        for (final r in await col.getFullList(filter: 'providerId = ""', fields: 'id')) {
          await col.delete(r.id);
        }
        await _pull();
      });
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

  /// Uncategorized rows are left out of every figure until they get a category.
  List<Expense> get _all => [for (final e in expenseStore.expenses) if (e.categoryID.isNotEmpty && !e.transfer) e];

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

/// Merges an export by id: re-importing an export updates rows instead of duplicating them.
bool importJson(List<int> bytes) {
  try {
    final list = [for (final e in jsonDecode(utf8.decode(bytes)) as List) Expense.fromJson(e)];
    expenseStore.expenses = {for (final e in expenseStore.expenses) e.id: e, for (final e in list) e.id: e}.values.toList();
    expenseStore.save();
    return true;
  } catch (_) {
    return false;
  }
}

/// Deletes manual transactions and budgets; bank transactions stay (they cannot be re-downloaded).
void resetAllData() {
  Storage.saveBudgets({});
  analytics.reloadBudgets();
  if (pocketBase.connected) {
    pocketBase.deleteManual();
  } else {
    expenseStore.replaceAll([]);
  }
}
