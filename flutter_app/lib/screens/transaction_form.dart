import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../ui.dart';
import 'home.dart' show amountText, amountColor;

/// Edits a bank transaction: title, date, category, notes and the transfer flag. Amount, sign and account are fixed.
class TransactionForm extends StatefulWidget {
  const TransactionForm({super.key, required this.expense});
  final Expense expense;
  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  late final Expense e = widget.expense;
  late final title = TextEditingController(text: e.title);
  late final notes = TextEditingController(text: e.notes ?? '');
  late DateTime date = e.date;
  late String categoryID = e.categoryID;
  late bool transfer = e.transfer;

  void _save() {
    final t = title.text.trim(), n = notes.text.trim();
    e
      ..title = t.isEmpty ? e.title : t
      ..date = date
      ..categoryID = categoryID
      ..transfer = transfer
      ..notes = n.isEmpty ? null : n;
    expenseStore.save();
    Haptic.success();
    Navigator.pop(context);
  }

  Widget _button(String label, IconData icon, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 18),
            gap(6),
            Text(label, style: Font.body.copyWith(color: Colors.white)),
          ]),
        ),
      );

  Widget _info(String label, Widget value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [Expanded(child: Sec(label, style: Font.subheadline)), value]),
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
          TextFormFieldIOS(label: 'Title', controller: title, placeholder: 'Title'),
          gap(),
          _info('Amount',
              Text(amountText(e), style: Font.headline.copyWith(fontWeight: bold, color: amountColor(context, e)))),
          _info('Type', Text(transfer ? 'Transfer' : e.type.displayName, style: Font.subheadline)),
          _info('Transfer between my accounts',
              CupertinoSwitch(value: transfer, onChanged: (v) => setState(() => transfer = v))),
          _info(
              'Account',
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (e.account != null) ...[BankBadge(e.account!, size: 18), gap(6)],
                Text(e.account ?? '—', style: Font.subheadline),
              ])),
        ]),
      ),
    );
    final category = CardView(
      title: 'Category',
      child: ListenableBuilder(
        listenable: categories,
        builder: (_, _) => CategoryGrid(
          selectedID: categoryID,
          categories: categories.forPicker(categoryID, e.type),
          onSelected: (id) => setState(() => categoryID = id),
        ),
      ),
    );

    return InlinePage(
      title: 'Edit Transaction',
      leading: NavText('Cancel', () => Navigator.pop(context)),
      trailing: keyboard ? NavText('Done', () => FocusScope.of(context).unfocus(), bold: true) : null,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            constrained(Column(children: [
              details,
              gap(20),
              if (!transfer) ...[category, gap(20)],
              DatePickerCard(date: date, onChanged: (d) => setState(() => date = d)),
              gap(20),
              NotesCard(controller: notes),
              gap(30),
              _button('Save Changes', CupertinoIcons.checkmark_circle_fill, context.accent.withValues(alpha: 0.8), _save),
            ])),
          ],
        ),
      ),
    );
  }
}
