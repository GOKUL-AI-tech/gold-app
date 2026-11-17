import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/notification_prefs.dart';
import '../../services/translations.dart';
import '../../services/locale_aware_mixin.dart';
import '../../theme/app_theme.dart';

/// Notification Settings — dark "Gold Century" theme.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen>
    with LocaleAwareMixin {
  final _service = NotificationPrefsService();
  Map<String, NotificationCategoryPrefs> _data = {};
  bool _loading = true;
  bool _dirty = false;

  List<(String, String)> get _channels => [
    ('sms', Translations.of('notif.sms')),
    ('push', Translations.of('notif.push')),
    ('whatsapp', Translations.of('notif.whatsapp')),
    ('email', Translations.of('notif.email')),
  ];

  List<String> get _frequencies => [
    Translations.of('notif.daily'),
    Translations.of('notif.weekly'),
    Translations.of('notif.monthly'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await _service.load();
    if (!mounted) return;
    setState(() {
      _data = loaded;
      _loading = false;
      _dirty = false;
    });
  }

  Future<void> _save() async {
    await _service.save(_data);
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(Translations.of('notif.saved'))),
    );
  }

  Future<void> _reset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.of('notif.resetConfirm')),
        content:
            Text(Translations.of('notif.resetContent')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Translations.of('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(Translations.of('common.reset')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _service.reset();
    await _load();
  }

  void _markDirty() => setState(() => _dirty = true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Translations.of('notif.title')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    _categoryCard(
                      key: 'rate_summary',
                      title: Translations.of('notif.rateSummary'),
                      highlight: true,
                      trailing: _frequencyDropdown('rate_summary'),
                    ),
                    _categoryCard(
                      key: 'single_day_increase',
                      title: Translations.of('notif.dayIncrease'),
                      extra: _thresholdSlider('single_day_increase'),
                      showChannels: false,
                    ),
                    _categoryCard(
                      key: 'single_day_decrease',
                      title: Translations.of('notif.dayDecrease'),
                      extra: _thresholdSlider('single_day_decrease'),
                      showChannels: false,
                    ),
                    _categoryCard(
                      key: 'goal_milestone',
                      title: Translations.of('notif.goalMilestone'),
                    ),
                    _categoryCard(
                      key: 'offers_events',
                      title: Translations.of('notif.offersEvents'),
                    ),
                    _categoryCard(
                      key: 'transaction_reminder',
                      title: Translations.of('notif.txnReminder'),
                    ),
                    _categoryCard(
                      key: 'scheme_maturity',
                      title: Translations.of('notif.schemeMaturity'),
                    ),
                    _categoryCard(
                      key: 'rewards',
                      title: Translations.of('notif.rewards'),
                    ),
                    _categoryCard(
                      key: 'general',
                      title: Translations.of('notif.general'),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border(
            top: BorderSide(
                color: AppColors.gold.withOpacity(0.15), width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : _reset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      side: const BorderSide(
                          color: AppColors.gold, width: 1.4),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(Translations.of('common.reset')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_loading || !_dirty) ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.textOnGold,
                      disabledBackgroundColor:
                          AppColors.cardElevated,
                      disabledForegroundColor: AppColors.muted,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(Translations.of('common.save'),
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Building blocks ----------

  Widget _categoryCard({
    required String key,
    required String title,
    bool highlight = false,
    Widget? trailing,
    Widget? extra,
    bool showChannels = true,
  }) {
    final cat = _data[key];
    if (cat == null) return const SizedBox.shrink();

    final enabled = cat.enabled;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled
              ? AppColors.gold.withOpacity(0.22)
              : AppColors.gold.withOpacity(0.07),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: highlight
                        ? AppColors.gold
                        : (enabled
                            ? AppColors.textOnDark
                            : AppColors.muted),
                  ),
                ),
              ),
              if (trailing != null) ...[
                trailing,
                const SizedBox(width: 8),
              ],
              _goldSwitch(
                value: enabled,
                onChanged: (v) {
                  cat.enabled = v;
                  _markDirty();
                },
              ),
            ],
          ),
          if (extra != null) ...[
            const SizedBox(height: 10),
            extra,
          ],
          if (showChannels) ...[
            const SizedBox(height: 12),
            Divider(
                height: 1,
                color: AppColors.gold.withOpacity(0.1)),
            const SizedBox(height: 10),
            _channelRow(cat),
          ],
        ],
      ),
    );
  }

  /// Custom gold-coloured Switch that looks consistent on both platforms.
  Widget _goldSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: value
              ? const LinearGradient(
                  colors: [Color(0xFFE8C36A), Color(0xFFB88A2A)],
                )
              : null,
          color: value ? null : AppColors.cardElevated,
          border: Border.all(
            color: value
                ? AppColors.gold.withOpacity(0.0)
                : AppColors.muted.withOpacity(0.3),
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? AppColors.textOnGold : AppColors.muted,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _channelRow(NotificationCategoryPrefs cat) {
    return Row(
      children: _channels.map((ch) {
        final id = ch.$1;
        final label = ch.$2;
        final selected = cat.channels.contains(id);
        final enabled = cat.enabled;

        return Expanded(
          child: GestureDetector(
            onTap: !enabled
                ? null
                : () {
                    if (selected) {
                      cat.channels.remove(id);
                    } else {
                      cat.channels.add(id);
                    }
                    _markDirty();
                  },
            child: Row(
              children: [
                // Custom dark checkbox
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: selected && enabled
                        ? AppColors.gold
                        : Colors.transparent,
                    border: Border.all(
                      color: selected && enabled
                          ? AppColors.gold
                          : AppColors.muted.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: selected && enabled
                      ? const Icon(Icons.check,
                          size: 12,
                          color: AppColors.textOnGold)
                      : null,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected && enabled
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: enabled
                          ? (selected
                              ? AppColors.gold
                              : AppColors.textOnDark)
                          : AppColors.muted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _frequencyDropdown(String key) {
    final cat = _data[key]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        border: Border.all(
            color: AppColors.gold.withOpacity(0.3), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: cat.frequency ?? 'Daily',
          dropdownColor: AppColors.cardElevated,
          style: GoogleFonts.inter(
            color: AppColors.gold,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AppColors.gold, size: 18),
          items: _frequencies
              .map((f) => DropdownMenuItem(
                    value: f,
                    child: Text(f),
                  ))
              .toList(),
          onChanged: !cat.enabled
              ? null
              : (v) {
                  if (v != null) {
                    cat.frequency = v;
                    _markDirty();
                  }
                },
        ),
      ),
    );
  }

  Widget _thresholdSlider(String key) {
    final cat = _data[key]!;
    final value = (cat.thresholdInr ?? 50).clamp(10.0, 1000.0);
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.gold,
              inactiveTrackColor: AppColors.cardElevated,
              thumbColor: AppColors.gold,
              overlayColor: AppColors.gold.withOpacity(0.15),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: 10,
              max: 1000,
              divisions: 99,
              onChanged: !cat.enabled
                  ? null
                  : (v) {
                      cat.thresholdInr = v;
                      _markDirty();
                    },
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardElevated,
            border: Border.all(
                color: AppColors.gold.withOpacity(0.3), width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '₹ ${value.toStringAsFixed(0)}',
            style: GoogleFonts.inter(
              color: AppColors.gold,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
