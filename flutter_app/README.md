# Inpenso for Web, Linux and Android

A Flutter port of the iOS app (`../iExpense`). One codebase builds all three platforms and copies the iOS UI: large-title navigation bars, inset cards, the bottom tab bar and iOS system colors in light and dark mode.

## Features (same as iOS)
- Home: monthly cashflow, budget progress, 7-day spending chart, top categories, recent transactions
- Analytics: Overview / Trends / Insights / Budget tabs, month picker, charts, smart insights, budget history
- Transactions: search, sort, type and category filters, grouping by category, swipe to edit or delete, undo
- Add/Edit transaction (expense or income), with category grid, date picker and notes
- Settings: theme, currency, default category, category management (custom categories, hide/restore, drag to reorder), JSON export/import, reset

Not ported because they are iOS-only: home-screen widgets and Siri shortcuts.

Export/import uses the same JSON format as the iOS app, so you can move data between platforms.

## Run / build
```bash
flutter run -d linux        # or: -d chrome, or an Android device
flutter build linux --release   # build/linux/x64/release/bundle/inpenso
flutter build web --release     # build/web (serve with any static server)
flutter build apk --release     # build/app/outputs/flutter-apk/app-release.apk
flutter test
```
On Linux, the import/export file dialogs need `zenity` or `kdialog` installed.
