import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:inpenso/models.dart';
import 'package:inpenso/state.dart';
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
    expect(categories.visible, hasLength(1));
    expect(categories.preferredCategoryID('builtin-food'), categories.visible.single.id);
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
    expect(analytics.biggestExpenseCategory, ('builtin-rent', 900.0));
    expect(analytics.insights.first.title, 'Budget Alert');
    expect(analytics.dailySpending.length, DateTime(now.year, now.month + 1, 0).day);
  });
}
