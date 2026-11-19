import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../state.dart';
import '../theme.dart';
import '../ui.dart';
import 'categories.dart';

const appVersion = '1.0.7';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  Future<void> _export(BuildContext context) async {
    final name = 'iExpense_export_${DateFormat.yMMMd().format(DateTime.now())}.json';
    try {
      final uri = await FilePicker.saveFile(fileName: name, bytes: exportJson(), mimeType: 'application/json');
      if ((uri != null || kIsWeb) && context.mounted) {
        await showAlert(context, 'Export Successful', message: 'Your data has been exported successfully.');
      }
    } catch (_) {
      // ponytail: export errors are silent, matching iOS (exportData() returns nil and nothing is shown).
    }
  }

  Future<void> _import(BuildContext context) async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (files.isEmpty || !context.mounted) return;
    final ok = importJson(await files.first.readAsBytes());
    if (!context.mounted) return;
    ok
        ? showAlert(context, 'Import Successful', message: 'Your data has been imported successfully.')
        : showAlert(context, 'Import Failed',
            message: 'Failed to import data. Please check the file format and try again.');
  }

  void _reset(BuildContext context) => showAlert(
        context,
        'Data Reset',
        message: 'This will delete all your expenses and budgets. This action cannot be undone.',
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              resetAllData();
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => StoreBuilder(builder: (context) {
        settings.normalizeDefaultCategory();
        final accent = context.accent;
        final red = context.c(SysColor.red);
        Widget menuValue(String text) => Row(mainAxisSize: MainAxisSize.min, children: [
              Sec(text, style: Font.body),
              gap(4),
              Icon(CupertinoIcons.chevron_up_chevron_down, size: 14, color: context.secondaryLabel),
            ]);
        Widget action(IconData icon, String label, Color color, VoidCallback onTap) => CupertinoListTile(
              leading: Icon(icon, color: color),
              title: Text(label, style: TextStyle(color: color)),
              onTap: onTap,
            );
        final cur = availableCurrencies.firstWhere((c) => c.$1 == settings.currency, orElse: () => availableCurrencies.first);
        final defCat = categories.category(settings.defaultCategoryID);

        return LargeTitlePage(
          title: 'Settings',
          background: context.groupedBg,
          slivers: [
            SliverToBoxAdapter(
              child: constrained(Column(children: [
                CupertinoListSection.insetGrouped(header: SectionLabel('APPEARANCE'), children: [
                  CupertinoListTile(
                    title: const Text('Theme'),
                    trailing: MenuPicker<AppTheme>(
                      items: [for (final t in AppTheme.values) (t, Text(t.displayName))],
                      selected: settings.theme,
                      onSelected: (t) => settings.theme = t,
                      child: menuValue(settings.theme.displayName),
                    ),
                  ),
                ]),
                CupertinoListSection.insetGrouped(header: SectionLabel('CURRENCY'), children: [
                  CupertinoListTile(
                    title: const Text('Currency'),
                    trailing: MenuPicker<String>(
                      items: [for (final c in availableCurrencies) (c.$1, Text('${c.$2} ${c.$3} (${c.$1})'))],
                      selected: settings.currency,
                      onSelected: (c) => settings.currency = c,
                      child: menuValue('${cur.$2} ${cur.$3} (${cur.$1})'),
                    ),
                  ),
                ]),
                CupertinoListSection.insetGrouped(header: SectionLabel('DEFAULT SETTINGS'), children: [
                  CupertinoListTile(
                    title: const Text('Default Category'),
                    trailing: MenuPicker<String>(
                      items: [
                        for (final c in categories.visible)
                          (c.id, Row(children: [dot(c.color), gap(8), Text(c.displayName)])),
                      ],
                      selected: settings.defaultCategoryID,
                      onSelected: (id) => settings.defaultCategoryID = id,
                      child: menuValue(defCat.displayName),
                    ),
                  ),
                ]),
                CupertinoListSection.insetGrouped(header: SectionLabel('CATEGORIES'), children: [
                  CupertinoListTile(
                    leading: Icon(CupertinoIcons.square_grid_2x2, color: accent),
                    title: const Text('Manage Categories'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => Navigator.of(context)
                        .push(CupertinoPageRoute(builder: (_) => const CategoryManagementView())),
                  ),
                ]),
                CupertinoListSection.insetGrouped(header: SectionLabel('DATA MANAGEMENT'), children: [
                  action(CupertinoIcons.square_arrow_up, 'Export Data', accent, () => _export(context)),
                  action(CupertinoIcons.square_arrow_down, 'Import Data', accent, () => _import(context)),
                  action(CupertinoIcons.trash, 'Reset All Data', red, () => _reset(context)),
                ]),
                CupertinoListSection.insetGrouped(header: SectionLabel('ABOUT'), children: [
                  const CupertinoListTile(title: Text('Version'), additionalInfo: Text(appVersion)),
                ]),
                gap(40),
              ])),
            ),
          ],
        );
      });
}
