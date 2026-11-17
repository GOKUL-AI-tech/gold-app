import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../services/live_price_service.dart';
import '../services/locale_controller.dart';
import '../services/translations.dart';
import '../services/locale_aware_mixin.dart';
import '../theme/app_theme.dart';
import '../screens/auth/login_screen.dart';
import '../screens/user/history_screen.dart';
import '../screens/user/notification_settings_screen.dart';
import '../screens/user/profile_screen.dart';
import 'money.dart';

/// Side drawer — Gold Century dark theme. Header is a gold gradient,
/// menu items live on a charcoal background. Includes a live gold +
/// silver price strip so users see rates the moment they open the menu.
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> with LocaleAwareMixin {
  @override
  void initState() {
    super.initState();
    LivePriceService.instance.addListener(_onPriceUpdate);
    // Fetch only if we have no cached data yet (HomeScreen usually gets here first).
    if (LivePriceService.instance.goldPrice == null) {
      LivePriceService.instance.fetchAll();
    }
  }

  @override
  void dispose() {
    LivePriceService.instance.removeListener(_onPriceUpdate);
    super.dispose(); // calls LocaleAwareMixin.dispose
  }

  void _onPriceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final email = user?.email ?? 'Guest';
    final name = (user?.userMetadata?['full_name'] as String?)?.trim();

    return Drawer(
      backgroundColor: AppColors.charcoal,
      child: SafeArea(
        child: Column(
          children: [
            // ---- Header (gold gradient) ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.darkGold, AppColors.gold],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.charcoal,
                        child: Text(
                          (name?.isNotEmpty == true ? name![0] : email[0])
                              .toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name?.isNotEmpty == true
                                  ? name!
                                  : Translations.of('app.name') + ' User',
                              style: GoogleFonts.inter(
                                color: AppColors.textOnGold,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: TextStyle(
                                color: AppColors.textOnGold
                                    .withOpacity(0.8),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _miniPriceTile('GOLD', LivePriceService.instance.goldPrice)),
                      const SizedBox(width: 8),
                      Expanded(child: _miniPriceTile('SILVER', LivePriceService.instance.silverPrice)),
                    ],
                  ),
                ],
              ),
            ),

            // ---- Menu items ----
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 6),
                children: [
                  _DrawerItem(
                    icon: Icons.translate,
                    label: context.t('drawer.changeLanguage'),
                    onTap: () => _showLanguageDialog(context),
                  ),
                  _DrawerItem(
                    icon: Icons.person_outline,
                    label: context.t('drawer.myProfile'),
                    onTap: () => _push(context, const ProfileScreen()),
                  ),
                  _DrawerItem(
                    icon: Icons.password_outlined,
                    label: context.t('drawer.changePassword'),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              Translations.of('drawer.pwdDrawerTip')),
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.flag_outlined,
                    label: context.t('drawer.savingsTarget'),
                    onTap: () => _showSavingsTargetDialog(context),
                  ),
                  _DrawerItem(
                    icon: Icons.notifications_outlined,
                    label: context.t('drawer.notifications'),
                    onTap: () => _push(
                        context, const NotificationSettingsScreen()),
                  ),
                  _DrawerItem(
                    icon: Icons.card_giftcard_outlined,
                    label: context.t('drawer.referral'),
                    onTap: () =>
                        _showInfo(context, Translations.of('drawer.referralSoon')),
                  ),
                  _DrawerItem(
                    icon: Icons.history,
                    label: context.t('drawer.history'),
                    onTap: () => _push(context, const HistoryScreen()),
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: context.t('drawer.settings'),
                    onTap: () =>
                        _showInfo(context, Translations.of('drawer.settingsSoon')),
                  ),
                  _DrawerItem(
                    icon: Icons.info_outline,
                    label: context.t('drawer.about'),
                    onTap: () => _showAbout(context),
                  ),
                  _DrawerItem(
                    icon: Icons.headset_mic_outlined,
                    label: context.t('drawer.support'),
                    onTap: () => _showSupport(context),
                  ),
                  _DrawerItem(
                    icon: Icons.location_on_outlined,
                    label: context.t('drawer.storeLocator'),
                    onTap: () =>
                        _showInfo(context, Translations.of('drawer.storeLocSoon')),
                  ),
                  _DrawerItem(
                    icon: Icons.star_outline,
                    label: context.t('drawer.rating'),
                    onTap: () => _showInfo(context,
                        Translations.of('drawer.ratingTip')),
                  ),
                  _DrawerItem(
                    icon: Icons.description_outlined,
                    label: context.t('drawer.terms'),
                    onTap: () => _showTerms(context),
                  ),
                  const Divider(
                      height: 1, color: Color(0xFF333333)),
                  _DrawerItem(
                    icon: Icons.logout,
                    label: context.t('drawer.logout'),
                    danger: true,
                    onTap: () => _logout(context),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'GoldVault v1.0.0',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Header live price tile (gold/silver inside the gradient)
  Widget _miniPriceTile(String label, LivePrice? p) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.charcoal.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    color: AppColors.gold.withOpacity(0.9),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  )),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              p == null ? '—' : '${formatInr(p.inrPerGram)}/g',
              maxLines: 1,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Helpers ----------
  void _push(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _showInfo(BuildContext context, String msg) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _logout(BuildContext context) async {
    // Show confirm dialog FIRST (drawer still open) so the context is valid.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.of('drawer.signOut')),
        content: Text(Translations.of('drawer.signOutMsg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Translations.of('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(Translations.of('profile.signOut')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;

    // Close the drawer, then sign out and go to login.
    Navigator.pop(context);
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _showLanguageDialog(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => ValueListenableBuilder<Locale>(
        valueListenable: localeController,
        builder: (_, currentLocale, __) {
          return AlertDialog(
            title: Text(context.t('drawer.changeLanguage')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: LocaleController.supported.map((entry) {
                final selected =
                    entry.locale.languageCode == currentLocale.languageCode;
                return ListTile(
                  dense: true,
                  leading: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selected ? AppColors.gold : AppColors.muted,
                  ),
                  title: Text(entry.nativeName),
                  subtitle: entry.label != entry.nativeName
                      ? Text(entry.label,
                          style: const TextStyle(fontSize: 11))
                      : null,
                  onTap: () async {
                    await localeController.setLocale(entry.locale);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Language changed to ${entry.nativeName}')),
                    );
                  },
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.t('common.close')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSavingsTargetDialog(BuildContext context) {
    Navigator.pop(context);
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.of('drawer.savingsTargetTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Translations.of('drawer.savingsTargetQ'),
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: Translations.of('drawer.targetGrams'),
                prefixIcon: Icon(Icons.workspace_premium_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Translations.of('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final g = double.tryParse(ctrl.text.trim()) ?? 0;
              if (g > 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Savings target set: ${g.toStringAsFixed(2)} g'),
                  ),
                );
              }
            },
            child: Text(Translations.of('common.save')),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    Navigator.pop(context);
    showAboutDialog(
      context: context,
      applicationName: 'GoldVault',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.gold.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.diamond,
            color: AppColors.gold, size: 28),
      ),
      children: const [
        SizedBox(height: 12),
        Text(
          'GoldVault is a digital gold and silver savings app. Save '
          'money and convert it into 24K gold or 999 silver, redeemable '
          'for jewellery or sold back any time.',
        ),
      ],
    );
  }

  void _showSupport(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.of('drawer.support')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            ListTile(
              dense: true,
              leading: Icon(Icons.email_outlined,
                  color: AppColors.gold),
              title: Text('support@goldvault.app'),
              subtitle: Text('Email us anytime'),
            ),
            ListTile(
              dense: true,
              leading:
                  Icon(Icons.phone_outlined, color: AppColors.gold),
              title: Text('+91 1800 123 4567'),
              subtitle: Text('Mon–Sat, 9 AM – 7 PM'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Translations.of('common.close')),
          ),
        ],
      ),
    );
  }

  void _showTerms(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.of('drawer.terms')),
        content: const SingleChildScrollView(
          child: Text(
            '1. GoldVault stores digital gold and silver on your behalf '
            'in a secure vault. Each gram you purchase is backed by '
            '24K gold / 999 silver.\n\n'
            '2. Metal prices are pulled live from Yahoo Finance and may '
            'differ from spot rates by a small spread.\n\n'
            '3. Redemption for physical jewellery is subject to making '
            'charges and shipping fees, payable on delivery.\n\n'
            '4. KYC may be required for redemptions above ₹50,000.\n\n'
            '5. By using this app you agree to these terms.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Translations.of('common.close')),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.gold;
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: danger ? AppColors.danger : AppColors.textOnDark,
        ),
      ),
      onTap: onTap,
      dense: true,
    );
  }
}
