import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../ui.dart';

/// AddExpenseView (expense == null) and EditExpenseView in one screen.
class TransactionForm extends StatefulWidget {
  const TransactionForm({super.key, this.expense});
  final Expense? expense;
  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  late final Expense? e = widget.expense;
  bool get isEdit => e != null;
  late final title = TextEditingController(text: e?.title ?? '');
  late final price = TextEditingController(text: e?.price.toStringAsFixed(2) ?? '');
  late final notes = TextEditingController(text: e?.notes ?? '');
  late TransactionType type = e?.type ?? TransactionType.expense;
  late DateTime date = e?.date ?? DateTime.now();
  late String categoryID = e?.categoryID ?? categories.preferredCategoryID(settings.defaultCategoryID);
  bool success = false;

  @override
  void initState() {
    super.initState();
    title.addListener(() => setState(() {}));
    price.addListener(() => setState(() {}));
  }

  bool get valid => title.text.isNotEmpty && price.text.isNotEmpty;
  String? get trimmedNotes => notes.text.trim().isEmpty ? null : notes.text.trim();

  void _add() {
    FocusScope.of(context).unfocus();
    if (title.text.isEmpty) return _invalid('Please enter a title.');
    if (price.text.isEmpty) return _invalid('Please enter an amount.');
    final value = double.tryParse(price.text.replaceAll(',', '.'));
    if (value == null) return _invalid('Please enter a valid amount.');
    setState(() => success = true);
    expenseStore.add(Expense(
      title: title.text,
      price: value,
      date: date,
      type: type,
      categoryID: categories.category(categoryID).id,
      notes: trimmedNotes,
    ));
    Haptic.success();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.pop(context);
    });
  }

  void _invalid(String msg) {
    Haptic.error();
    showAlert(context, msg);
  }

  void _saveEdit() {
    final value = double.tryParse(price.text.replaceAll(',', '.'));
    if (value != null) {
      e!
        ..title = title.text
        ..price = value
        ..date = date
        ..type = type
        ..categoryID = categories.category(categoryID).id
        ..notes = trimmedNotes;
      expenseStore.save();
    }
    Haptic.success();
    Navigator.pop(context);
  }

  void _delete() {
    expenseStore.remove(e!.id);
    Haptic.impact();
    Navigator.pop(context);
  }

  Widget _button(String label, IconData? icon, Color color, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(isEdit ? 12 : 16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, color: Colors.white, size: 18), gap(6)],
            Text(label, style: Font.body.copyWith(color: Colors.white)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final details = CardView(
      title: 'Transaction Details',
      showDivider: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(children: [
          Segmented(
            values: TransactionType.values,
            label: (t) => t.displayName,
            selected: type,
            onChanged: (t) => setState(() => type = t),
          ),
          gap(),
          TextFormFieldIOS(
            label: 'Title',
            controller: title,
            placeholder: type == TransactionType.expense ? 'Expense title' : 'Income title',
            leadingIcon: isEdit ? null : CupertinoIcons.pencil,
          ),
          gap(),
          CurrencyFormField(label: 'Amount', controller: price, symbol: settings.currencySymbol),
        ]),
      ),
    );
    final category = CardView(
      title: 'Category',
      child: ListenableBuilder(
        listenable: categories,
        builder: (_, _) => CategoryGrid(
          selectedID: categoryID,
          categories: isEdit ? categories.forPicker(categoryID) : categories.visible,
          onSelected: (id) => setState(() => categoryID = id),
        ),
      ),
    );
    final dateCard = DatePickerCard(date: date, onChanged: (d) => setState(() => date = d));

    return Stack(children: [
      InlinePage(
        title: isEdit ? 'Edit Transaction' : 'Add Transaction',
        leading: NavText('Cancel', () => Navigator.pop(context)),
        trailing: keyboard ? NavText('Done', () => FocusScope.of(context).unfocus(), bold: true) : null,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, isEdit ? 16 : 10, 16, isEdit ? 40 : 24),
            children: [
              constrained(Column(children: [
                details,
                gap(20),
                if (isEdit) ...[dateCard, gap(20), category] else ...[category, gap(20), dateCard],
                gap(20),
                NotesCard(controller: notes),
                gap(20),
                if (isEdit) ...[
                  gap(10),
                  _button('Save Changes', CupertinoIcons.checkmark_circle_fill,
                      context.accent.withValues(alpha: 0.8), _saveEdit),
                  gap(12),
                  _button('Delete Transaction', CupertinoIcons.trash_fill,
                      context.c(SysColor.red).withValues(alpha: 0.8), _delete),
                ] else
                  _button('Save Transaction', null, valid ? context.accent : context.c(SysColor.gray),
                      valid ? _add : null),
              ])),
            ],
          ),
        ),
      ),
      if (success) const _SuccessOverlay(),
    ]);
  }
}

class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay();
  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.4),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (_, s, c) => Transform.scale(scale: s, child: c),
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                    color: context.bg.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(20)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(CupertinoIcons.checkmark_circle_fill, size: 80, color: context.c(SysColor.green)),
                  gap(20),
                  Text('Transaction Added!',
                      style: Font.title2.copyWith(fontWeight: bold, color: context.label, decoration: TextDecoration.none)),
                ]),
              ),
            ),
          ),
        ),
      );
}
