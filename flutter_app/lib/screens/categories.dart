import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../ui.dart';

/// Touch devices drag after a long press (like iOS); mouse users drag immediately.
final _touch = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class CategoryManagementView extends StatefulWidget {
  const CategoryManagementView({super.key});
  @override
  State<CategoryManagementView> createState() => _CategoryManagementViewState();
}

class _CategoryManagementViewState extends State<CategoryManagementView> {
  String? dragged, targeted;

  void _edit(FinanceCategory? c) => showSheet(context, CategoryEditor(category: c));

  void _hide(FinanceCategory c) {
    categories.hide(c);
    settings.normalizeDefaultCategory();
  }

  @override
  Widget build(BuildContext context) => StoreBuilder(
        builder: (context) => LargeTitlePage(
          title: 'Categories',
          background: context.groupedBg,
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _edit(null),
            child: const Icon(CupertinoIcons.add),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: constrained(Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _section('Visible', categories.visible, false),
                  if (categories.hidden.isNotEmpty) ...[gap(24), _section('Hidden', categories.hidden, true)],
                ]),
              )),
            ),
          ],
        ),
      );

  Widget _section(String title, List<FinanceCategory> list, bool hidden) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Font.headline),
        gap(12),
        LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 24) / 3;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final c in list) SizedBox(width: w, child: hidden ? _tile(c, true) : _draggable(c, w)),
          ]);
        }),
      ]);

  Widget _tile(FinanceCategory c, bool hidden) => _Tile(
        category: c,
        isHidden: hidden,
        isTargeted: dragged != null && targeted == c.id,
        canReset: !c.isCustom && categories.hasOverride(c.id),
        onEdit: () => _edit(c),
        onHide: () => _hide(c),
        onRestore: () => categories.restore(c),
        onReset: () => categories.resetOverride(c.id),
      );

  Widget _draggable(FinanceCategory c, double width) {
    final feedback = Material(color: Colors.transparent, child: _DragPreview(c));
    void start() => setState(() => dragged = c.id);
    void end() => setState(() => dragged = targeted = null);
    final child = DragTarget<String>(
      onWillAcceptWithDetails: (d) {
        if (d.data == c.id) return false;
        setState(() => targeted = c.id);
        categories.move(d.data, c.id); // live reorder while hovering, like iOS dropEntered
        return true;
      },
      onLeave: (_) => setState(() => targeted = targeted == c.id ? null : targeted),
      onAcceptWithDetails: (_) => end(),
      builder: (_, _, _) => Opacity(opacity: dragged == c.id ? 0.4 : 1, child: _tile(c, false)),
    );
    return _touch
        ? LongPressDraggable<String>(
            data: c.id, feedback: feedback, onDragStarted: start, onDragEnd: (_) => end(), child: child)
        : Draggable<String>(data: c.id, feedback: feedback, onDragStarted: start, onDragEnd: (_) => end(), child: child);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.category,
    required this.isTargeted,
    required this.isHidden,
    required this.canReset,
    required this.onEdit,
    required this.onHide,
    required this.onRestore,
    required this.onReset,
  });
  final FinanceCategory category;
  final bool isTargeted, isHidden, canReset;
  final VoidCallback onEdit, onHide, onRestore, onReset;

  @override
  Widget build(BuildContext context) {
    final red = context.c(SysColor.red);
    PopupMenuItem<VoidCallback> item(IconData icon, String label, VoidCallback cb, {bool destructive = false}) =>
        PopupMenuItem(
          value: cb,
          child: Row(children: [
            Icon(icon, color: destructive ? red : null, size: 20),
            gap(8),
            Text(label, style: TextStyle(color: destructive ? red : null)),
          ]),
        );
    return GestureDetector(
      onTap: onEdit,
      child: AnimatedScale(
        scale: isTargeted ? 1.03 : 1,
        duration: const Duration(milliseconds: 220),
        child: Opacity(
          opacity: isHidden ? 0.65 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 144),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: context.groupedBg2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isTargeted ? context.accent : Colors.transparent, width: 2),
            ),
            child: Column(children: [
              Stack(clipBehavior: Clip.none, children: [
                IconBadge(category, size: 56, iconSize: 22, circle: true),
                Positioned(
                  right: -16,
                  top: -16,
                  child: PopupMenuButton<VoidCallback>(
                    tooltip: '',
                    color: context.bg2,
                    padding: EdgeInsets.zero,
                    onSelected: (cb) => cb(),
                    itemBuilder: (_) => [
                      item(CupertinoIcons.pencil, 'Edit', onEdit),
                      isHidden
                          ? item(CupertinoIcons.eye, 'Restore', onRestore)
                          : item(CupertinoIcons.eye_slash, 'Remove', onHide, destructive: true),
                      if (canReset) ...[
                        const PopupMenuDivider(),
                        item(CupertinoIcons.arrow_counterclockwise, 'Reset', onReset, destructive: true),
                      ],
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        decoration: BoxDecoration(color: context.bg, shape: BoxShape.circle),
                        child: Icon(CupertinoIcons.ellipsis_circle_fill, size: 20, color: context.secondaryLabel),
                      ),
                    ),
                  ),
                ),
              ]),
              gap(8),
              SizedBox(
                height: 32,
                child: CategoryLabel(category.displayName,
                    Font.caption.copyWith(fontWeight: medium, color: isHidden ? context.secondaryLabel : context.label)),
              ),
              gap(8),
              if (isHidden)
                GestureDetector(
                  onTap: onRestore,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(CupertinoIcons.eye, size: 12, color: context.accent),
                    gap(4),
                    Text('Restore', style: Font.caption2.copyWith(fontWeight: semibold, color: context.accent)),
                  ]),
                )
              else
                Icon(CupertinoIcons.line_horizontal_3, size: 14, color: context.secondaryLabel),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DragPreview extends StatelessWidget {
  const _DragPreview(this.c);
  final FinanceCategory c;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: context.bg, borderRadius: BorderRadius.circular(8)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          IconBadge(c, size: 52, iconSize: 20, circle: true),
          gap(6),
          Text(c.displayName, style: Font.caption.copyWith(fontWeight: semibold, color: context.label)),
        ]),
      );
}

class CategoryEditor extends StatefulWidget {
  const CategoryEditor({super.key, this.category});
  final FinanceCategory? category;
  @override
  State<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<CategoryEditor> {
  late final c = widget.category;
  late final name = TextEditingController(text: c?.name ?? '');
  late String icon = c?.iconName ?? 'tag.fill';
  late String color = c?.colorHex ?? '#007AFF';

  void _save() {
    final n = name.text.trim();
    if (n.isEmpty) {
      showAlert(context, 'Category name is required');
      return;
    }
    if (c != null) {
      categories.update(c!.copy()
        ..name = n
        ..iconName = icon
        ..colorHex = color);
    } else {
      categories.add(n, icon, color);
    }
    Navigator.pop(context);
  }

  void _act(VoidCallback f) {
    f();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final red = context.c(SysColor.red);
    Widget grid(int cols, List<Widget> children) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: LayoutBuilder(
            builder: (_, box) => Wrap(runSpacing: 12, children: [
              for (final w in children) SizedBox(width: box.maxWidth / cols, child: Center(child: w)),
            ]),
          ),
        );
    return InlinePage(
      title: c == null ? 'New Category' : 'Edit Category',
      leading: NavText('Cancel', () => Navigator.pop(context)),
      trailing: NavText('Save', _save, bold: true),
      body: ListView(children: [
        constrained(Column(children: [
          CupertinoListSection.insetGrouped(header: SectionLabel('DETAILS'), children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: CupertinoTextField.borderless(controller: name, placeholder: 'Name', padding: const EdgeInsets.all(12)),
            ),
          ]),
          CupertinoListSection.insetGrouped(header: SectionLabel('ICON'), children: [
            grid(5, [
              for (final i in editorIcons)
                GestureDetector(
                  onTap: () => setState(() => icon = i),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: icon == i ? context.accent : context.bg3, shape: BoxShape.circle),
                    child: Icon(sfIcon(i), size: 20, color: icon == i ? Colors.white : context.label),
                  ),
                ),
            ]),
          ]),
          CupertinoListSection.insetGrouped(header: SectionLabel('COLOR'), children: [
            grid(6, [
              for (final h in editorColors)
                GestureDetector(
                  onTap: () => setState(() => color = h),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: hexColor(h), shape: BoxShape.circle),
                    child: color == h ? const Icon(CupertinoIcons.checkmark, size: 14, color: Colors.white) : null,
                  ),
                ),
            ]),
          ]),
          if (c != null)
            CupertinoListSection.insetGrouped(header: SectionLabel('ACTIONS'), children: [
              categories.isHidden(c!.id)
                  ? CupertinoListTile(
                      leading: Icon(CupertinoIcons.eye, color: context.accent),
                      title: Text('Restore Category', style: TextStyle(color: context.accent)),
                      onTap: () => _act(() => categories.restore(c!)),
                    )
                  : CupertinoListTile(
                      leading: Icon(CupertinoIcons.eye_slash, color: red),
                      title: Text('Remove from Pickers', style: TextStyle(color: red)),
                      onTap: () => _act(() {
                        categories.hide(c!);
                        settings.normalizeDefaultCategory();
                      }),
                    ),
              if (!c!.isCustom && categories.hasOverride(c!.id))
                CupertinoListTile(
                  leading: Icon(CupertinoIcons.arrow_counterclockwise, color: red),
                  title: Text('Reset to Defaults', style: TextStyle(color: red)),
                  onTap: () => _act(() => categories.resetOverride(c!.id)),
                ),
            ]),
        ])),
      ]),
    );
  }
}
