/// Environment / runtime configuration for GoldVault.
///
/// In production, prefer passing these via `--dart-define` so secrets
/// don't end up in source control:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=...
class Env {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR-PROJECT.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );

  /// Currency code displayed in the UI. Override per-region as needed.
  static const String currencyCode = 'INR';
  static const String currencySymbol = '₹';
}

// ignore_for_file: constant_identifier_names

/// Payment gateway — Razorpay
///
/// Replace with your live key before publishing:
///   flutter run --dart-define=RAZORPAY_KEY_ID=rzp_live_XXXX
class PaymentConfig {
  /// Razorpay Key ID (starts with rzp_test_ for testing, rzp_live_ for prod).
  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_REPLACE_WITH_YOUR_KEY',
  );

  static const String appName     = 'Gold Century';
  static const String description = 'Gold Century Wallet Top-Up';
}
