import 'package:flutter/material.dart';

import '../../models/profile.dart';
import '../../services/live_price_service.dart';
import '../../services/locale_controller.dart';
import '../../services/profile_service.dart';
import '../../services/translations.dart';
import '../../services/locale_aware_mixin.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_home_screen.dart';
import 'dashboard_tab.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'redemption_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with LocaleAwareMixin {
  int _index = 0;
  Profile? _profile;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Loads saved locale first, then profile data.
  /// The loading spinner stays visible during both, so by the time
  /// the UI appears it is already in the correct language.
  Future<void> _init() async {
    await localeController.load();
    // Start the global live-price loop here, once, for the whole session.
    LivePriceService.instance.startAutoRefresh();
    _loadProfile();
  }

  @override
  void dispose() {
    LivePriceService.instance.stopAutoRefresh();
    super.dispose(); // calls LocaleAwareMixin.dispose
  }

  Future<void> _loadProfile() async {
    try {
      final p = await ProfileService().getCurrentProfile();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _loadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Admin accounts get their own dedicated shell — they never see the user app.
    if (_profile?.isAdmin == true) {
      return const AdminHomeScreen();
    }

    final tabs = <Widget>[
      const DashboardTab(),
      const HistoryScreen(),
      const RedemptionScreen(),
      const ProfileScreen(),
    ];

    final navItems = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
          icon: const Icon(Icons.dashboard_outlined),
          label: context.t('tab.home')),
      BottomNavigationBarItem(
          icon: const Icon(Icons.receipt_long_outlined),
          label: context.t('tab.history')),
      BottomNavigationBarItem(
          icon: const Icon(Icons.diamond_outlined),
          label: context.t('tab.jewellery')),
      BottomNavigationBarItem(
          icon: const Icon(Icons.person_outline),
          label: context.t('tab.profile')),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index.clamp(0, tabs.length - 1),
        items: navItems,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: AppColors.darkGold,
      ),
    );
  }
}
