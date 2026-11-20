import 'dart:math';

import 'package:flutter/widgets.dart';

enum TransactionType {
  expense,
  income;

  String get displayName => this == expense ? 'Expense' : 'Income';
}

/// Built-in categories, mirroring the iOS `Category` enum (raw values kept for JSON compatibility).
const builtInRaw = [
  ('food', 'Food', 'cart.fill', '#34C759'),
  ('eatingOut', 'Eating Out', 'fork.knife', '#00C7BE'),
  ('rent', 'Rent', 'house.fill', '#AF52DE'),
  ('shopping', 'Shopping', 'bag.fill', '#FF9500'),
  ('entertainment', 'Entertainment', 'tv.fill', '#FF2D55'),
  ('transportation', 'Transportation', 'car.fill', '#007AFF'),
  ('utilities', 'Utilities', 'bolt.fill', '#FFCC00'),
  ('subscriptions', 'Subscriptions', 'repeat', '#30B0C7'),
  ('healthcare', 'Healthcare', 'heart.fill', '#FF3B30'),
  ('education', 'Education', 'book.fill', '#5856D6'),
  ('others', 'Others', 'ellipsis', '#8E8E93'),
];

/// Income built-ins have no iOS raw value, so legacyRaw() exports them as 'others'.
const builtInIncomeRaw = [
  ('salary', 'Salary', 'banknote.fill', '#34C759'),
  ('otherIncome', 'Other Income', 'gift.fill', '#30B0C7'),
];

String builtInID(String raw) => 'builtin-$raw';

/// Legacy raw category for a category id, or 'others' (iOS `Category.category(from:) ?? .others`).
String legacyRaw(String categoryID) {
  if (!categoryID.startsWith('builtin-')) return 'others';
  final raw = categoryID.substring(8);
  return builtInRaw.any((c) => c.$1 == raw) ? raw : 'others';
}

Color hexColor(String hex) {
  final s = hex.trim().replaceAll('#', '');
  final v = s.length == 6 ? int.tryParse(s, radix: 16) : null;
  return v == null ? const Color(0xFF8E8E93) : Color(0xFF000000 | v);
}

class FinanceCategory {
  String id;
  String name;
  String iconName;
  String colorHex;
  bool isCustom;
  TransactionType type;

  FinanceCategory({
    required this.id,
    required this.name,
    required this.iconName,
    required this.colorHex,
    required this.isCustom,
    this.type = TransactionType.expense,
  });

  String get displayName => name;
  Color get color => hexColor(colorHex);

  FinanceCategory copy() =>
      FinanceCategory(id: id, name: name, iconName: iconName, colorHex: colorHex, isCustom: isCustom, type: type);

  static final List<FinanceCategory> builtIns = [
    for (final c in builtInRaw)
      FinanceCategory(id: builtInID(c.$1), name: c.$2, iconName: c.$3, colorHex: c.$4, isCustom: false),
    for (final c in builtInIncomeRaw)
      FinanceCategory(
          id: builtInID(c.$1),
          name: c.$2,
          iconName: c.$3,
          colorHex: c.$4,
          isCustom: false,
          type: TransactionType.income),
  ];

  /// What a bank transaction has until the user picks a category (categoryID ''); kept out of analytics.
  static FinanceCategory get uncategorized => FinanceCategory(
      id: '', name: 'Uncategorized', iconName: 'questionmark.circle.fill', colorHex: '#8E8E93', isCustom: false);

  /// Section/icon for transfers between own accounts (not a real category; kept out of analytics).
  static const transferID = 'transfer';
  static FinanceCategory get transfer => FinanceCategory(
      id: transferID, name: 'Transfers', iconName: 'arrow.left.arrow.right', colorHex: '#8E8E93', isCustom: false);

  static FinanceCategory get fallback => builtIns.firstWhere((c) => c.id == builtInID('others')).copy();

  factory FinanceCategory.fromJson(Map<String, dynamic> j) => FinanceCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        iconName: j['iconName'] as String,
        colorHex: j['colorHex'] as String,
        isCustom: j['isCustom'] as bool? ?? false,
        type: j['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'iconName': iconName, 'colorHex': colorHex, 'isCustom': isCustom, 'type': type.name};
}

class CategoryCatalogState {
  List<String> orderedCategoryIDs;
  List<FinanceCategory> customCategories;
  Map<String, FinanceCategory> builtInOverrides;
  Set<String> hiddenCategoryIDs;
  Set<String> deletedBuiltInIDs; // built-ins the user deleted (they are code constants, so they need a tombstone)

  CategoryCatalogState({
    List<String>? orderedCategoryIDs,
    List<FinanceCategory>? customCategories,
    Map<String, FinanceCategory>? builtInOverrides,
    Set<String>? hiddenCategoryIDs,
    Set<String>? deletedBuiltInIDs,
  })  : deletedBuiltInIDs = deletedBuiltInIDs ?? {},
        orderedCategoryIDs = orderedCategoryIDs ?? [],
        customCategories = customCategories ?? [],
        builtInOverrides = builtInOverrides ?? {},
        hiddenCategoryIDs = hiddenCategoryIDs ?? {};

  factory CategoryCatalogState.fromJson(Map<String, dynamic> j) {
    // Swift encodes [String: T] as a dictionary, so this matches the iOS format.
    final overrides = (j['builtInOverrides'] as Map?) ?? {};
    return CategoryCatalogState(
      orderedCategoryIDs: [...?(j['orderedCategoryIDs'] as List?)?.cast<String>()],
      customCategories: [
        for (final c in (j['customCategories'] as List?) ?? []) FinanceCategory.fromJson(c),
      ],
      builtInOverrides: {
        for (final e in overrides.entries) e.key as String: FinanceCategory.fromJson(e.value),
      },
      hiddenCategoryIDs: {...?(j['hiddenCategoryIDs'] as List?)?.cast<String>()},
      deletedBuiltInIDs: {...?(j['deletedBuiltInIDs'] as List?)?.cast<String>()},
    );
  }

  Map<String, dynamic> toJson() => {
        'orderedCategoryIDs': orderedCategoryIDs,
        'customCategories': [for (final c in customCategories) c.toJson()],
        'builtInOverrides': {for (final e in builtInOverrides.entries) e.key: e.value.toJson()},
        'hiddenCategoryIDs': hiddenCategoryIDs.toList(),
        'deletedBuiltInIDs': deletedBuiltInIDs.toList(),
      };
}

/// Seconds between 1970-01-01 and 2001-01-01: Swift's JSONEncoder stores dates relative to 2001.
const _appleEpochOffset = 978307200;

String newUUID() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0F) | 0x40;
  b[8] = (b[8] & 0x3F) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class Expense {
  String id;
  String title;
  double price;
  DateTime date;
  TransactionType type;
  String categoryID;
  String? notes;
  String? account; // bank the row comes from (read-only, from the `accounts` relation)
  bool transfer; // between own accounts: the sign still says in/out, but it's out of every total

  Expense({
    String? id,
    required this.title,
    required this.price,
    required this.date,
    this.type = TransactionType.expense,
    required this.categoryID,
    this.notes,
    this.account,
    this.transfer = false,
  }) : id = id ?? newUUID();

  String get groupID => transfer ? FinanceCategory.transferID : categoryID;

  /// Decodes the iOS export format; throws on missing required fields like Swift's Decodable.
  factory Expense.fromJson(Map<String, dynamic> j) {
    final category = (j['category'] as String?) ?? 'others';
    final categoryID = j['categoryID'] as String?;
    return Expense(
      id: j['id'] as String?,
      title: j['title'] as String,
      price: (j['price'] as num).toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(
          (((j['date'] as num).toDouble() + _appleEpochOffset) * 1000).round()),
      type: j['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      categoryID: categoryID ?? builtInID(category), // '' = uncategorized
      notes: j['notes'] as String?,
      account: j['account'] as String?,
      transfer: j['transfer'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'price': price,
        'date': date.millisecondsSinceEpoch / 1000 - _appleEpochOffset,
        'category': legacyRaw(categoryID),
        'type': type.name,
        'categoryID': categoryID,
        if (notes != null) 'notes': notes,
        if (account != null) 'account': account,
        if (transfer) 'transfer': true,
      };
}
