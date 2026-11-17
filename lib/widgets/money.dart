import 'package:intl/intl.dart';

import '../config/env.dart';

String formatInr(num value) {
  final f = NumberFormat.currency(
    locale: 'en_IN',
    symbol: Env.currencySymbol,
    decimalDigits: 2,
  );
  return f.format(value);
}

String formatGrams(num grams) {
  if (grams == 0) return '0.0000 g';
  return '${grams.toStringAsFixed(4)} g';
}
