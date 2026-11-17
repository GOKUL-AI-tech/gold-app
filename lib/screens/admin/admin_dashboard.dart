import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../main.dart';
import '../../services/live_price_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import 'admin_price_screen.dart';
import 'admin_users_screen.dart';
import 'admin_redemptions_screen.dart';
import 'admin_reports_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _totalUsers    = 0;
  int _pendingOrders = 0;
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
    LivePriceService.instance.addListener(_onPrice);
  }

  @override
  void dispose() {
    LivePriceService.instance.removeListener(_onPrice);
    super.dispose();
  }

  void _onPrice() { if (mounted) setState(() {}); }

  Future<void> _loadStats() async {
    // Fetch each stat independently so one failure doesn't zero out the others.
    int users = 0, orders = 0;

    try {
      // Use ProfileService.listAllUsers() — confirmed working through RLS.
      final all = await ProfileService().listAllUsers();
      users = all.length;
    } catch (_) {}

    try {
      final rows = await supabase
          .from('redemption_requests')
          .select('id')
          .inFilter('status', ['requested', 'pending', 'approved']);
      orders = (rows as List).length;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _totalUsers    = users;
      _pendingOrders = orders;
      _statsLoading  = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gold   = LivePriceService.instance.goldInrPerGram;
    final silver = LivePriceService.instance.silverInrPerGram;

    final tiles = <_Tile>[
      _Tile(Icons.price_change_outlined, 'Update Prices',
          'Set live gold & silver rates', AppColors.darkGold,
          const AdminPriceScreen()),
      _Tile(Icons.people_outline, 'Manage Users',
          'View & inspect all accounts', AppColors.success,
          const AdminUsersScreen()),
      _Tile(Icons.local_shipping_outlined, 'Redemption Orders',
          'Approve, ship or reject orders', const Color(0xFF1E88E5),
          const AdminRedemptionsScreen()),
      _Tile(Icons.analytics_outlined, 'Reports',
          'Holdings, volumes & revenue', const Color(0xFF9C27B0),
          const AdminReportsScreen()),
    ];

    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: AppColors.gold,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // ── Stats row 1 ──
            Row(children: [
              _stat('Users',   _statsLoading ? '…' : '$_totalUsers',
                  Icons.people,              AppColors.gold),
              const SizedBox(width: 8),
              _stat('Pending', _statsLoading ? '…' : '$_pendingOrders',
                  Icons.hourglass_top_outlined, AppColors.danger),
              const SizedBox(width: 8),
              _stat('Gold/g',  gold   == 0 ? '…' : '₹${gold.toStringAsFixed(0)}',
                  Icons.diamond_outlined,    AppColors.darkGold),
            ]),
            const SizedBox(height: 8),
            // ── Stats row 2 ──
            Row(children: [
              _stat('Silver/g', silver == 0 ? '…' : '₹${silver.toStringAsFixed(0)}',
                  Icons.workspace_premium_outlined, const Color(0xFFB0BEC5)),
              const SizedBox(width: 8),
              _stat('Updated', LivePriceService.instance.lastUpdatedLabel,
                  Icons.access_time_outlined, AppColors.muted),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
            ]),
            const SizedBox(height: 20),

            // ── Quick-action tiles ──
            Text('Quick Actions',
                style: GoogleFonts.inter(color: AppColors.muted,
                    fontSize: 12, fontWeight: FontWeight.w600,
                    letterSpacing: 0.6)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: tiles.map((t) => _TileCard(t)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: GoogleFonts.inter(color: AppColors.textOnDark,
                      fontSize: 13, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 10)),
            ],
          )),
        ]),
      ),
    );
  }
}

class _Tile {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final Widget screen;
  const _Tile(this.icon, this.title, this.subtitle, this.color, this.screen);
}

class _TileCard extends StatelessWidget {
  final _Tile t;
  const _TileCard(this.t, {super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => t.screen)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.color.withOpacity(0.25), width: 1)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: t.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(t.icon, color: t.color, size: 22),
            ),
            const Spacer(),
            Text(t.title,
                style: GoogleFonts.inter(color: AppColors.textOnDark,
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(t.subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
