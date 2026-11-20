import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:inpenso/models.dart';
import 'package:inpenso/state.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initStores();
  });

  test('decodes an iOS export (Apple-epoch dates, legacy category only)', () {
    final json = '[{"id":"ABC","title":"Lunch","price":12.5,"date":0,"category":"eatingOut"}]';
    expect(importJson(utf8.encode(json)), isTrue);
    final e = expenseStore.expenses.single;
    expect(e.date.toUtc(), DateTime.utc(2001, 1, 1));
    expect(e.categoryID, 'builtin-eatingOut');
    expect(e.type, TransactionType.expense);
    final back = jsonDecode(utf8.decode(exportJson())) as List;
    expect(back.single['date'], 0);
    expect(back.single['category'], 'eatingOut');
  });

  test('rejects malformed import and keeps data', () {
    expect(importJson(utf8.encode('[{"title":"x"}]')), isFalse);
    expect(expenseStore.expenses, hasLength(1));
  });

  test('category catalog: hide keeps at least one, move reorders, custom maps to others', () {
    categories.add('Pets', 'pawprint.fill', '#A2845E');
    final pets = categories.visible.last;
    expect(pets.isCustom, isTrue);
    expect(legacyRaw(pets.id), 'others');
    categories.move(pets.id, 'builtin-food');
    expect(categories.visible.first.id, pets.id);
    for (final c in [...categories.visible]) {
      categories.hide(c);
    }
    expect(categories.visible, hasLength(2)); // one per type
    final lastExpense = categories.visibleFor(TransactionType.expense).single.id;
    expect(categories.preferredCategoryID('builtin-food'), lastExpense);
    for (final c in [...categories.hidden]) {
      categories.restore(c);
    }
    expect(categories.hidden, isEmpty);
  });

  test('analytics totals, net and budget insight for the selected month', () {
    final now = DateTime.now();
    expenseStore.expenses
      ..clear()
      ..addAll([
        Expense(title: 'Rent', price: 900, date: now, categoryID: 'builtin-rent'),
        Expense(title: 'Salary', price: 2000, date: now, type: TransactionType.income, categoryID: 'builtin-others'),
      ]);
    expenseStore.save();
    analytics.changeMonth(now.month, now.year);
    analytics.saveBudget(1000);
    expect(analytics.totalSpent, 900);
    expect(analytics.totalIncome, 2000);
    expect(analytics.netCashflow, 1100);
    expenseStore.add(Expense(title: 'New bank row', price: 50, date: now, categoryID: ''));
    expect(analytics.totalSpent, 900); // uncategorized rows stay out of the figures
    expenseStore.add(Expense(title: 'To Revolut', price: 100, date: now, categoryID: 'builtin-others', transfer: true));
    expect((analytics.totalSpent, analytics.totalIncome), (900, 2000)); // transfers stay out too
    expect(analytics.biggestExpenseCategory, ('builtin-rent', 900.0));
    expect(analytics.insights.first.title, 'Budget Alert');
    expect(analytics.dailySpending.length, DateTime(now.year, now.month + 1, 0).day);
  });

  test('category catalog round-trips through PocketBase rows', () {
    categories.add('Pets', 'pawprint.fill', '#A2845E');
    categories.update(categories.category('builtin-food').copy()..name = 'Groceries');
    categories.hide(categories.category('builtin-rent'));
    final rows = categories.rows;
    final records = [
      for (final r in rows.values.toList().reversed) RecordModel.fromJson({'id': 'r${r['sortOrder']}', ...r}),
      RecordModel.fromJson({'id': 'legacy123456789', 'name': 'Imported', 'color': 0xFF0000}), // no key
    ];
    categories.replaceFromRows(records);
    expect(categories.rows.values.take(rows.length), rows.values);
    expect(categories.hasOverride('builtin-food'), isTrue);
    expect(categories.hasOverride('builtin-eatingOut'), isFalse);
    expect(categories.isHidden('builtin-rent'), isTrue);
    expect(categories.category('legacy123456789').colorHex, '#FF0000');
  });

  test('deleting a category uncategorizes its transactions and survives a server round-trip', () {
    categories.add('Temp', 'tag.fill', '#FF0000');
    final temp = categories.visible.last;
    final food = categories.category('builtin-shopping');
    expenseStore.add(Expense(title: 'T', price: 1, date: DateTime.now(), categoryID: temp.id));
    expect(categories.delete(temp), isTrue);
    expect(categories.delete(food), isTrue);
    expect(expenseStore.expenses.last.categoryID, '');
    expect(categories.rows.keys, isNot(contains('builtin-shopping')));
    categories.replaceFromRows([
      for (final r in categories.rows.values) RecordModel.fromJson({'id': 'x${r['sortOrder']}', ...r}),
    ]);
    expect(categories.category('builtin-shopping').id, isNot('builtin-shopping')); // still deleted
    expect(categories.visible.any((c) => c.id == temp.id), isFalse);
  });

  test('maps PocketBase rows both ways', () {
    RecordModel row(String id, int cents, {String title = '', String cat = ''}) => RecordModel.fromJson({
      'id': id,
      'bookingDate': '2026-11-03 00:00:00.000Z',
      'amountCents': cents,
      'currency': 'EUR',
      'description': 'POS ESSELUNGA',
      'title': title,
      'categoryID': cat,
      'notes': '',
      'expand': {
        'account': {'id': 'a1', 'bank': 'Fineco'},
      },
    });
    final out = expenseFromPb(row('r1', -1250, cat: 'builtin-food'))!;
    expect(
      (out.id, out.title, out.price, out.type, out.categoryID, out.notes, out.account),
      ('r1', 'POS ESSELUNGA', 12.5, TransactionType.expense, 'builtin-food', null, 'Fineco'),
    );
    expect(out.date, DateTime(2026, 11, 3)); // booking day, whatever the time zone
    final salary = expenseFromPb(row('r2', 200000, title: 'Salary'))!;
    expect((salary.title, salary.type, salary.categoryID), ('Salary', TransactionType.income, '')); // uncategorized
    expect(Expense.fromJson(salary.toJson()).categoryID, ''); // the local cache keeps it uncategorized
    expect(expenseFromPb(RecordModel.fromJson({'id': 'x', 'bookingDate': ''})), isNull);

    final gift = Expense(
        title: 'Gift',
        price: 20.1,
        date: DateTime(2026, 5, 1, 18, 30),
        type: TransactionType.income,
        categoryID: 'builtin-otherIncome',
        notes: 'n');
    expect(pbBody(gift)['amountCents'], 2010);
    final back = expenseFromPb(RecordModel.fromJson({'id': 'abc', ...pbBody(gift)}))!;
    expect((back.title, back.price, back.date, back.type, back.categoryID, back.notes),
        (gift.title, gift.price, gift.date, gift.type, gift.categoryID, gift.notes));
    final moved = Expense(title: 'To Revolut', price: 100, date: DateTime(2026, 5, 1), categoryID: '', transfer: true);
    expect(pbBody(moved)['transfer'], isTrue);
    expect(expenseFromPb(RecordModel.fromJson({'id': 'm', ...pbBody(moved)}))!.transfer, isTrue);
    expect(Expense.fromJson(moved.toJson()).transfer, isTrue); // the local cache keeps it
    expect(RegExp(r'^[a-z0-9]{15}$').hasMatch(newPbId()), isTrue);
  });

  test('expense and income categories are separate', () {
    final inc = TransactionType.income;
    expect(categories.visibleFor(inc).map((c) => c.id), containsAll(['builtin-salary', 'builtin-otherIncome']));
    expect(categories.visibleFor(TransactionType.expense).any((c) => c.type == inc), isFalse);
    expect(legacyRaw('builtin-salary'), 'others'); // iOS export stays decodable

    categories.add('Freelance', 'briefcase.fill', '#007AFF', inc);
    final free = categories.visibleFor(inc).last;
    expect((free.name, FinanceCategory.fromJson(free.toJson()).type), ('Freelance', inc));
    expect(categories.preferredCategoryID('builtin-food', inc), 'builtin-salary');
    expect(categories.forPicker('builtin-food', inc).last.id, 'builtin-food'); // old row keeps its category

    for (final c in categories.visibleFor(inc)) {
      categories.hide(c);
    }
    expect(categories.visibleFor(inc), hasLength(1)); // one income category always stays
  });
}
