import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One row in the Notification Settings screen.
class NotificationCategoryPrefs {
  bool enabled;
  Set<String> channels; // any of: sms, push, whatsapp, email
  String? frequency; // for "Rate Summary"  (Daily / Weekly / Monthly)
  double? thresholdInr; // for "Single day increase / decrease"

  NotificationCategoryPrefs({
    this.enabled = true,
    Set<String>? channels,
    this.frequency,
    this.thresholdInr,
  }) : channels = channels ?? {'push'};

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'channels': channels.toList(),
        if (frequency != null) 'frequency': frequency,
        if (thresholdInr != null) 'thresholdInr': thresholdInr,
      };

  factory NotificationCategoryPrefs.fromJson(Map<String, dynamic> j) {
    return NotificationCategoryPrefs(
      enabled: (j['enabled'] as bool?) ?? true,
      channels: ((j['channels'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet(),
      frequency: j['frequency'] as String?,
      thresholdInr: (j['thresholdInr'] as num?)?.toDouble(),
    );
  }

  NotificationCategoryPrefs copy() => NotificationCategoryPrefs(
        enabled: enabled,
        channels: {...channels},
        frequency: frequency,
        thresholdInr: thresholdInr,
      );
}

/// Persistence layer for notification settings.
class NotificationPrefsService {
  static const _prefsKey = 'notification_prefs_v1';

  /// Built-in category keys + their friendly labels (English).
  /// The screen uses Translations for the labels at render time;
  /// these are just the storage keys.
  static const categoryKeys = [
    'rate_summary',
    'single_day_increase',
    'single_day_decrease',
    'goal_milestone',
    'offers_events',
    'transaction_reminder',
    'scheme_maturity',
    'rewards',
    'general',
  ];

  /// Sensible defaults that mirror what most users expect.
  Map<String, NotificationCategoryPrefs> defaults() {
    return {
      'rate_summary': NotificationCategoryPrefs(
        enabled: true,
        channels: {'push'},
        frequency: 'Daily',
      ),
      'single_day_increase': NotificationCategoryPrefs(
        enabled: true,
        channels: {'push'},
        thresholdInr: 50,
      ),
      'single_day_decrease': NotificationCategoryPrefs(
        enabled: true,
        channels: {'push'},
        thresholdInr: 50,
      ),
      'goal_milestone': NotificationCategoryPrefs(
        enabled: false,
        channels: {'push'},
      ),
      'offers_events': NotificationCategoryPrefs(
        enabled: true,
        channels: {'push'},
      ),
      'transaction_reminder': NotificationCategoryPrefs(
        enabled: true,
        channels: {'push'},
      ),
      'scheme_maturity': NotificationCategoryPrefs(
        enabled: true,
        channels: {'push'},
      ),
      'rewards': NotificationCategoryPrefs(
        enabled: true,
        channels: {'push'},
      ),
      'general': NotificationCategoryPrefs(
        enabled: true,
        channels: {'push'},
      ),
    };
  }

  Future<Map<String, NotificationCategoryPrefs>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final base = defaults();
    if (raw == null) return base;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final loaded = decoded.map((k, v) => MapEntry(
            k,
            NotificationCategoryPrefs.fromJson(
                v as Map<String, dynamic>),
          ));
      // Backfill any missing keys from defaults so adding new
      // categories later doesn't break old saved data.
      for (final k in categoryKeys) {
        loaded.putIfAbsent(k, () => base[k]!);
      }
      return loaded;
    } catch (_) {
      return base;
    }
  }

  Future<void> save(Map<String, NotificationCategoryPrefs> data) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(data.map((k, v) => MapEntry(k, v.toJson())));
    await prefs.setString(_prefsKey, encoded);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
