import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'screens/analytics.dart';
import 'screens/home.dart';
import 'screens/settings.dart';
import 'screens/transactions.dart';
import 'state.dart';
import 'theme.dart';
import 'ui.dart';

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
        tabBar: GlassTabBar(
          // Translucent, so CupertinoTabScaffold lets content scroll under the floating bar.
          backgroundColor: context.bg2.withValues(alpha: 0.7),
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

/// iOS 26-style floating "glass" capsule tab bar.
class GlassTabBar extends CupertinoTabBar {
  const GlassTabBar({super.key, required super.items, super.onTap, super.currentIndex, super.backgroundColor, super.activeColor});

  static const _barHeight = 64.0;
  static const _gap = 12.0;

  @override
  Size get preferredSize => const Size.fromHeight(_barHeight + _gap);

  // CupertinoTabScaffold rebuilds the bar through copyWith, so it must keep this subclass.
  @override
  GlassTabBar copyWith({
    Key? key,
    List<BottomNavigationBarItem>? items,
    Color? backgroundColor,
    Color? activeColor,
    Color? inactiveColor,
    double? iconSize,
    double? height,
    Border? border,
    int? currentIndex,
    ValueChanged<int>? onTap,
  }) =>
      GlassTabBar(
        key: key ?? this.key,
        items: items ?? this.items,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        activeColor: activeColor ?? this.activeColor,
        currentIndex: currentIndex ?? this.currentIndex,
        onTap: onTap ?? this.onTap,
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final active = activeColor ?? context.accent;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom > 0 ? bottom : _gap),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_barHeight / 2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_barHeight / 2),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: _barHeight,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(_barHeight / 2),
                border: Border.all(color: context.label.withValues(alpha: 0.08), width: 0.5),
              ),
              child: Row(children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: Semantics(
                      selected: i == currentIndex,
                      button: true,
                      label: items[i].label,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (i != currentIndex) Haptic.selection();
                          onTap?.call(i);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          decoration: BoxDecoration(
                            color: i == currentIndex ? context.label.withValues(alpha: 0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular((_barHeight - 8) / 2),
                          ),
                          child: ExcludeSemantics(
                            child: IconTheme(
                              data: IconThemeData(size: 24, color: i == currentIndex ? active : context.label),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                items[i].icon,
                                const SizedBox(height: 2),
                                Text(
                                  items[i].label ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  // The bar sits outside Material, so it needs a full (non-inheriting) text style.
                                  style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: i == currentIndex ? active : context.label,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
