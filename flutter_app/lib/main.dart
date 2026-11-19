import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'screens/analytics.dart';
import 'screens/home.dart';
import 'screens/settings.dart';
import 'screens/transactions.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initStores();
  runApp(const InpensoApp());
}

class InpensoApp extends StatelessWidget {
  const InpensoApp({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: settings,
        builder: (_, _) => MaterialApp(
          title: 'Inpenso',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: settings.theme.mode,
          home: const MainTabView(),
        ),
      );
}

class MainTabView extends StatefulWidget {
  const MainTabView({super.key});
  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView> {
  final controller = CupertinoTabController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoTabScaffold(
        controller: controller,
        tabBar: CupertinoTabBar(
          backgroundColor: context.bg2.withValues(alpha: 0.94),
          activeColor: context.accent,
          items: const [
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.house_fill), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.chart_pie_fill), label: 'Analytics'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.list_bullet), label: 'Transactions'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.gear_solid), label: 'Settings'),
          ],
        ),
        tabBuilder: (_, i) => CupertinoTabView(
          builder: (_) => switch (i) {
            0 => HomeView(onViewAll: () => controller.index = 2),
            1 => const AnalyticsView(),
            2 => const TransactionsView(),
            _ => const SettingsView(),
          },
        ),
      );
}
