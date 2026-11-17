import 'package:flutter/material.dart';
import 'locale_controller.dart';

/// Mix this into any [State] to auto-rebuild whenever the user switches
/// language. No extra code is needed in the screen — just add the mixin.
///
/// ```dart
/// class _MyScreenState extends State<MyScreen> with LocaleAwareMixin {
///   // build() is automatically re-called on every locale change
/// }
/// ```
mixin LocaleAwareMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    localeController.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    localeController.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }
}
