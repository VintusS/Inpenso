import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// iOS system colors (light/dark aware via CupertinoDynamicColor).
abstract final class SysColor {
  static const blue = CupertinoColors.systemBlue;
  static const green = CupertinoColors.systemGreen;
  static const red = CupertinoColors.systemRed;
  static const orange = CupertinoColors.systemOrange;
  static const purple = CupertinoColors.systemPurple;
  static const gray = CupertinoColors.systemGrey;
  static const yellow = CupertinoColors.systemYellow;
}

extension Ctx on BuildContext {
  Color c(Color color) => CupertinoDynamicColor.resolve(color, this);
  Color get label => c(CupertinoColors.label);
  Color get secondaryLabel => c(CupertinoColors.secondaryLabel);
  Color get bg => c(CupertinoColors.systemBackground);
  Color get bg2 => c(CupertinoColors.secondarySystemBackground);
  Color get bg3 => c(CupertinoColors.tertiarySystemBackground);
  Color get groupedBg => c(CupertinoColors.systemGroupedBackground);
  Color get groupedBg2 => c(CupertinoColors.secondarySystemGroupedBackground);
  Color get gray5 => c(CupertinoColors.systemGrey5);
  Color get gray6 => c(CupertinoColors.systemGrey6);
  Color get accent => c(SysColor.blue);
  Color get separator => c(CupertinoColors.separator);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// iOS Dynamic Type sizes at the default content size.
abstract final class Font {
  static const largeTitle = TextStyle(fontSize: 34, fontWeight: FontWeight.bold);
  static const title2 = TextStyle(fontSize: 22);
  static const title3 = TextStyle(fontSize: 20);
  static const headline = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 17);
  static const callout = TextStyle(fontSize: 16);
  static const subheadline = TextStyle(fontSize: 15);
  static const caption = TextStyle(fontSize: 12);
  static const caption2 = TextStyle(fontSize: 11);
}

const bold = FontWeight.bold, semibold = FontWeight.w600, medium = FontWeight.w500;

/// Icons used by insights and pattern analysis.
abstract final class IconDataRef {
  static const warning = CupertinoIcons.exclamationmark_triangle;
  static const bell = CupertinoIcons.bell;
  static const checkCircle = CupertinoIcons.checkmark_circle;
  static const arrowUpRight = CupertinoIcons.arrow_up_right;
  static const arrowDownRight = CupertinoIcons.arrow_down_right;
  static const trendingUp = Icons.trending_up;
}

/// SF Symbol names (stored in category data for iOS compatibility) -> closest Flutter icon.
const _sfIcons = <String, IconData>{
  'cart.fill': CupertinoIcons.cart_fill,
  'fork.knife': Icons.restaurant,
  'house.fill': CupertinoIcons.house_fill,
  'bag.fill': CupertinoIcons.bag_fill,
  'tv.fill': CupertinoIcons.tv_fill,
  'car.fill': CupertinoIcons.car_fill,
  'bolt.fill': CupertinoIcons.bolt_fill,
  'repeat': CupertinoIcons.repeat,
  'heart.fill': CupertinoIcons.heart_fill,
  'book.fill': CupertinoIcons.book_fill,
  'ellipsis': CupertinoIcons.ellipsis,
  'tag.fill': CupertinoIcons.tag_fill,
  'briefcase.fill': CupertinoIcons.briefcase_fill,
  'banknote.fill': Icons.payments,
  'creditcard.fill': CupertinoIcons.creditcard_fill,
  'gift.fill': CupertinoIcons.gift_fill,
  'tram.fill': CupertinoIcons.tram_fill,
  'airplane': CupertinoIcons.airplane,
  'cross.case.fill': Icons.medical_services,
  'graduationcap.fill': Icons.school,
  'gamecontroller.fill': CupertinoIcons.game_controller_solid,
  'music.note': CupertinoIcons.music_note,
  'pawprint.fill': Icons.pets,
  'leaf.fill': Icons.eco,
  'hammer.fill': CupertinoIcons.hammer_fill,
};

IconData sfIcon(String name) => _sfIcons[name] ?? CupertinoIcons.tag_fill;

/// Icon choices offered by the category editor (same list as iOS).
const editorIcons = [
  'tag.fill', 'briefcase.fill', 'banknote.fill', 'creditcard.fill',
  'gift.fill', 'cart.fill', 'fork.knife', 'house.fill',
  'car.fill', 'tram.fill', 'airplane', 'heart.fill',
  'cross.case.fill', 'book.fill', 'graduationcap.fill', 'gamecontroller.fill',
  'music.note', 'pawprint.fill', 'leaf.fill', 'hammer.fill',
];

const editorColors = [
  '#007AFF', '#34C759', '#FF9500', '#FF3B30',
  '#AF52DE', '#FF2D55', '#5856D6', '#00C7BE',
  '#30B0C7', '#FFCC00', '#8E8E93', '#A2845E',
];

ThemeData buildTheme(Brightness b) {
  final base = ThemeData(
    brightness: b,
    useMaterial3: true,
    platform: TargetPlatform.iOS,
    colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF007AFF), brightness: b, primary: b == Brightness.dark
            ? const Color(0xFF0A84FF)
            : const Color(0xFF007AFF)),
    scaffoldBackgroundColor: b == Brightness.dark ? Colors.black : Colors.white,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerTheme: DividerThemeData(
        space: 1, thickness: 0.5, color: b == Brightness.dark ? const Color(0x99545458) : const Color(0x4A3C3C43)),
  );
  return base.copyWith(
    cupertinoOverrideTheme: CupertinoThemeData(brightness: b),
  );
}
