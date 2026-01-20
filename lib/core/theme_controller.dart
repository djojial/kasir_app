import 'package:flutter/material.dart';

class ThemeController extends InheritedNotifier<ValueNotifier<ThemeMode>> {
  const ThemeController({
    super.key,
    required ValueNotifier<ThemeMode> notifier,
    required Widget child,
  }) : super(notifier: notifier, child: child);

  static ThemeMode mode(BuildContext context) {
    final controller =
        context.dependOnInheritedWidgetOfExactType<ThemeController>();
    return controller?.notifier?.value ?? ThemeMode.light;
  }

  static void toggle(BuildContext context) {
    final controller =
        context.dependOnInheritedWidgetOfExactType<ThemeController>();
    final notifier = controller?.notifier;
    if (notifier == null) return;
    notifier.value =
        notifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}
