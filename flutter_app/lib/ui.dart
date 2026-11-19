import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';

// ------------------------------------------------------------------ Layout

/// Rounded background box (the RoundedRectangle().fill(...) pattern used everywhere on iOS).
class Box extends StatelessWidget {
  const Box({super.key, required this.child, this.radius = 12, this.color, this.padding = 16, this.shadow = false});
  final Widget child;
  final double radius;
  final Color? color;
  final double padding;
  final bool shadow;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: color ?? context.bg2,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: shadow
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))]
              : null,
        ),
        child: child,
      );
}

/// Card with a headline title, like the iOS `CardView`.
class CardView extends StatelessWidget {
  const CardView({super.key, required this.title, required this.child, this.showDivider = false});
  final String title;
  final Widget child;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: context.bg2, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(title, style: Font.headline)),
          const SizedBox(height: 12),
          if (showDivider) ...[
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider()),
            const SizedBox(height: 12),
          ],
          child,
        ]),
      );
}

Widget gap([double h = 16]) => SizedBox(height: h, width: h);

/// Text that resolves the secondary label color in context.
class Sec extends StatelessWidget {
  const Sec(this.text, {super.key, this.style = Font.subheadline, this.align});
  final String text;
  final TextStyle style;
  final TextAlign? align;
  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: align, style: style.copyWith(color: context.secondaryLabel));
}

/// Small grey header/footer text for inset-grouped list sections.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: context.secondaryLabel));
}

/// Large-title page with a collapsing iOS navigation bar.
class LargeTitlePage extends StatelessWidget {
  const LargeTitlePage({
    super.key,
    required this.title,
    required this.slivers,
    this.leading,
    this.trailing,
    this.background,
    this.bottom,
    this.onRefresh,
  });
  final String title;
  final List<Widget> slivers;
  final Widget? leading, trailing;
  final Color? background;
  final PreferredSizeWidget? bottom;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? context.bg;
    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: Text(title),
          leading: leading,
          trailing: trailing,
          backgroundColor: bg.withValues(alpha: 0.92),
          border: null,
          bottom: bottom,
          bottomMode: bottom == null ? null : NavigationBarBottomMode.always,
          transitionBetweenRoutes: false,
        ),
        if (onRefresh != null) CupertinoSliverRefreshControl(onRefresh: onRefresh),
        ...slivers,
        // CustomScrollView ignores the inset the floating tab bar reserves, so add it explicitly.
        SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
      ]),
    );
  }
}

/// Sheet / pushed page with an inline nav bar (Cancel / Title / Action).
class InlinePage extends StatelessWidget {
  const InlinePage({super.key, required this.title, required this.body, this.leading, this.trailing, this.background});
  final String title;
  final Widget body;
  final Widget? leading, trailing;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? context.groupedBg;
    return Scaffold(
      backgroundColor: bg,
      appBar: CupertinoNavigationBar(
        middle: Text(title),
        leading: leading,
        trailing: trailing,
        backgroundColor: bg.withValues(alpha: 0.92),
        border: null,
        transitionBetweenRoutes: false,
      ),
      body: body,
    );
  }
}

/// Plain text nav-bar button ("Cancel", "Save", "Apply", "Done").
class NavText extends StatelessWidget {
  const NavText(this.label, this.onPressed, {super.key, this.bold = false});
  final String label;
  final VoidCallback? onPressed;
  final bool bold;
  @override
  Widget build(BuildContext context) => CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        onPressed: onPressed,
        child: Text(label, style: TextStyle(fontSize: 17, fontWeight: bold ? semibold : null)),
      );
}

/// Content width cap so the phone layout stays readable on desktop/web windows.
Widget constrained(Widget child) =>
    Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 700), child: child));

Future<T?> showSheet<T>(BuildContext context, Widget page) =>
    showCupertinoSheet<T>(context: context, scrollableBuilder: (_, _) => page);

Future<void> showAlert(BuildContext context, String title, {String? message, List<CupertinoDialogAction>? actions}) =>
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: actions ??
            [CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );

// ------------------------------------------------------------------ Haptics

abstract final class Haptic {
  static void impact() => HapticFeedback.mediumImpact();
  static void success() => HapticFeedback.lightImpact();
  static void error() => HapticFeedback.heavyImpact();
  static void selection() => HapticFeedback.selectionClick();
}

// ------------------------------------------------------------------ Controls

class Segmented<T extends Object> extends StatelessWidget {
  const Segmented({super.key, required this.values, required this.label, required this.selected, required this.onChanged});
  final List<T> values;
  final String Function(T) label;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<T>(
          groupValue: selected,
          children: {for (final v in values) v: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(label(v)))},
          onValueChanged: (v) => v == null ? null : onChanged(v),
        ),
      );
}

/// A pull-down menu picker (SwiftUI `Picker` with `.menu` style / `Menu { Picker }`).
class MenuPicker<T> extends StatelessWidget {
  const MenuPicker({super.key, required this.items, required this.selected, required this.onSelected, required this.child});
  final List<(T, Widget)> items;
  final T selected;
  final ValueChanged<T> onSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
        tooltip: '',
        color: context.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: onSelected,
        itemBuilder: (_) => [
          for (final (v, w) in items)
            PopupMenuItem(
              value: v,
              child: Row(children: [
                SizedBox(width: 24, child: v == selected ? const Icon(CupertinoIcons.checkmark, size: 16) : null),
                Expanded(child: w),
              ]),
            ),
        ],
        child: child,
      );
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.progress, this.height = 8, this.radius = 6, required this.color});
  final double progress, height, radius;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(color: context.gray5, borderRadius: BorderRadius.circular(radius)),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0, 1),
          child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius))),
        ),
      );
}

Color budgetColor(double progress) => progress < 0.75 ? SysColor.blue : (progress < 0.9 ? SysColor.orange : SysColor.red);

/// White icon on a colored rounded square or circle.
class IconBadge extends StatelessWidget {
  const IconBadge(this.category, {super.key, this.size = 30, this.iconSize = 16, this.radius = 8, this.circle = false});
  final FinanceCategory category;
  final double size, iconSize, radius;
  final bool circle;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: category.color,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(radius),
        ),
        child: Icon(sfIcon(category.iconName), size: iconSize, color: Colors.white),
      );
}

Widget dot(Color color, [double size = 12]) =>
    Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));

// ------------------------------------------------------------------ Form fields

class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Sec(label),
        gap(8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
          decoration: BoxDecoration(color: context.bg3, borderRadius: BorderRadius.circular(10)),
          child: child,
        ),
      ]);
}

InputDecoration _plain(String hint, BuildContext context) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.c(CupertinoColors.placeholderText)),
      border: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    );

class TextFormFieldIOS extends StatelessWidget {
  const TextFormFieldIOS({super.key, required this.label, required this.controller, this.placeholder = '', this.leadingIcon});
  final String label, placeholder;
  final TextEditingController controller;
  final IconData? leadingIcon;
  @override
  Widget build(BuildContext context) => _FieldBox(
        label: label,
        child: Row(children: [
          if (leadingIcon != null) ...[
            SizedBox(width: 20, child: Icon(leadingIcon, size: 18, color: context.secondaryLabel)),
            gap(8),
          ],
          Expanded(
              child: TextField(controller: controller, style: Font.body, decoration: _plain(placeholder, context))),
        ]),
      );
}

class CurrencyFormField extends StatefulWidget {
  const CurrencyFormField({super.key, required this.label, required this.controller, required this.symbol});
  final String label, symbol;
  final TextEditingController controller;
  @override
  State<CurrencyFormField> createState() => _CurrencyFormFieldState();
}

class _CurrencyFormFieldState extends State<CurrencyFormField> {
  /// Same rules as the iOS formatter: comma -> dot, one decimal point, max two decimals.
  static String format(String input) {
    var s = input.replaceAll(',', '.');
    final parts = s.split('.');
    if (parts.length > 2) s = '${parts[0]}.${parts[1]}';
    final i = s.indexOf('.');
    if (i >= 0 && s.length > i + 3) s = s.substring(0, i + 3);
    return s;
  }

  @override
  Widget build(BuildContext context) => _FieldBox(
        label: widget.label,
        child: Row(children: [
          Text(widget.symbol, style: Font.title3.copyWith(fontWeight: medium, color: context.secondaryLabel)),
          gap(8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                TextInputFormatter.withFunction((_, v) {
                  final f = format(v.text);
                  return TextEditingValue(text: f, selection: TextSelection.collapsed(offset: f.length));
                }),
              ],
              onChanged: (_) => setState(() {}),
              style: Font.title2.copyWith(fontWeight: semibold),
              decoration: _plain('0.00', context),
            ),
          ),
          if (widget.controller.text.isNotEmpty)
            GestureDetector(
              onTap: () => setState(widget.controller.clear),
              child: Icon(CupertinoIcons.xmark_circle_fill, color: context.secondaryLabel, size: 20),
            ),
        ]),
      );
}

class NotesCard extends StatelessWidget {
  const NotesCard({super.key, required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => CardView(
        title: 'Notes (Optional)',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 100),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: context.isDark ? context.gray6 : context.bg, borderRadius: BorderRadius.circular(10)),
            child: TextField(
              controller: controller,
              maxLines: null,
              minLines: 4,
              style: Font.body,
              decoration: _plain('', context),
            ),
          ),
        ),
      );
}

// ------------------------------------------------------------------ Category grid

class CategoryButton extends StatelessWidget {
  const CategoryButton({super.key, required this.category, required this.isSelected, required this.onTap});
  final FinanceCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: isSelected ? 1.05 : 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          child: SizedBox(
            width: 80,
            child: Column(children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: category.color,
                  shape: BoxShape.circle,
                  border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                  boxShadow: isSelected
                      ? [BoxShadow(color: category.color.withValues(alpha: 0.6), blurRadius: 10)]
                      : null,
                ),
                child: Icon(sfIcon(category.iconName), size: 22, color: Colors.white),
              ),
              gap(6),
              SizedBox(
                height: 32,
                child: CategoryLabel(
                  category.displayName,
                  Font.caption.copyWith(
                    fontWeight: isSelected ? bold : medium,
                    color: isSelected ? context.label : context.secondaryLabel,
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
}

/// Two-line category name; a single long word shrinks to fit (like SwiftUI minimumScaleFactor) instead of breaking.
class CategoryLabel extends StatelessWidget {
  const CategoryLabel(this.text, this.style, {super.key});
  final String text;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => text.trim().contains(' ')
      ? Text(text, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: style)
      : Align(
          alignment: Alignment.topCenter,
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1, style: style)),
        );
}

class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key, required this.selectedID, required this.categories, required this.onSelected});
  final String selectedID;
  final List<FinanceCategory> categories;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth / 3;
          return Wrap(runSpacing: 15, children: [
            for (final c in categories)
              SizedBox(
                width: w,
                child: Center(
                  child: CategoryButton(
                    category: c,
                    isSelected: c.id == selectedID,
                    onTap: () {
                      Haptic.impact();
                      onSelected(c.id);
                    },
                  ),
                ),
              ),
          ]);
        }),
      );
}

// ------------------------------------------------------------------ Date picker card

class DatePickerCard extends StatefulWidget {
  const DatePickerCard({super.key, required this.date, required this.onChanged});
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  @override
  State<DatePickerCard> createState() => _DatePickerCardState();
}

class _DatePickerCardState extends State<DatePickerCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      decoration: BoxDecoration(color: context.bg2, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Date', style: Font.headline)),
        gap(8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () => setState(() => expanded = !expanded),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: context.bg3, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(CupertinoIcons.calendar, color: context.accent),
                gap(8),
                Expanded(child: Text(DateFormat.yMMMd().format(widget.date), style: Font.headline)),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(CupertinoIcons.chevron_down, color: context.secondaryLabel, size: 18),
                ),
              ]),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CalendarDatePicker(
                    initialDate: widget.date.isAfter(today) ? today : widget.date,
                    firstDate: DateTime(2000),
                    lastDate: today,
                    onDateChanged: (d) {
                      Haptic.selection();
                      // Keep the original time of day, like the iOS date-only picker.
                      widget.onChanged(DateTime(d.year, d.month, d.day, widget.date.hour, widget.date.minute));
                    },
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ Month / year picker

class MonthYearPicker extends StatefulWidget {
  const MonthYearPicker({super.key, required this.month, required this.year, required this.onChanged, this.monthsToShow = 36});
  final int month, year, monthsToShow;
  final void Function(int month, int year) onChanged;
  @override
  State<MonthYearPicker> createState() => _MonthYearPickerState();
}

class _MonthYearPickerState extends State<MonthYearPicker> {
  late final List<DateTime> list;
  late final PageController pager;
  late int index;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    list = [for (var i = widget.monthsToShow - 1; i >= 0; i--) DateTime(now.year, now.month - i)];
    index = list.indexWhere((d) => d.month == widget.month && d.year == widget.year);
    if (index < 0) index = list.length - 1;
    pager = PageController(initialPage: index);
  }

  @override
  void dispose() {
    pager.dispose();
    super.dispose();
  }

  void go(int i) => pager.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

  @override
  Widget build(BuildContext context) {
    Widget arrow(IconData icon, bool enabled, VoidCallback onTap) => CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          onPressed: enabled ? onTap : null,
          child: Icon(icon, size: 24, color: enabled ? context.label : Colors.transparent),
        );
    return Row(children: [
      if (index > 0) arrow(CupertinoIcons.chevron_left, true, () => go(index - 1)),
      Expanded(
        child: Column(children: [
          SizedBox(
            height: 50,
            child: PageView.builder(
              controller: pager,
              itemCount: list.length,
              onPageChanged: (i) {
                setState(() => index = i);
                Haptic.selection();
                widget.onChanged(list[i].month, list[i].year);
              },
              itemBuilder: (_, i) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(DateFormat.MMMM().format(list[i]), style: Font.title2.copyWith(fontWeight: bold)),
                gap(8),
                Sec('${list[i].year}', style: Font.title3),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var m = 1; m <= 12; m++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: dot(m == list[index].month ? context.accent : Colors.grey.withValues(alpha: 0.3), 6),
                ),
            ]),
          ),
        ]),
      ),
      arrow(CupertinoIcons.chevron_right, index < list.length - 1, () => go(index + 1)),
    ]);
  }
}

/// Rebuilds when any of the app stores change.
class StoreBuilder extends StatelessWidget {
  const StoreBuilder({super.key, required this.builder});
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([settings, categories, expenseStore, analytics, pocketBase]),
        builder: (context, _) => builder(context),
      );
}
