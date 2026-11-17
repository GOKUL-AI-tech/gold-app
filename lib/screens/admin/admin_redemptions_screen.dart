import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../main.dart';
import '../../theme/app_theme.dart';
import '../../widgets/money.dart';

class AdminRedemptionsScreen extends StatefulWidget {
  const AdminRedemptionsScreen({super.key});

  @override
  State<AdminRedemptionsScreen> createState() =>
      _AdminRedemptionsScreenState();
}

class _AdminRedemptionsScreenState extends State<AdminRedemptionsScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Embed jewellery_catalog via item_id FK. We fetch user emails
      // in a second pass below since redemption_requests.user_id points
      // to auth.users (not profiles), so PostgREST can't auto-embed it.
      final data = await supabase
          .from('redemption_requests')
          .select('*, jewellery_catalog(name, weight_grams)')
          .order('created_at', ascending: false);
      final rows = List<Map<String, dynamic>>.from(data as List);

      // Resolve user emails for the admin display
      final userIds = rows
          .map((r) => r['user_id'] as String)
          .toSet()
          .toList();
      Map<String, Map<String, dynamic>> userMap = {};
      if (userIds.isNotEmpty) {
        final users = await supabase
            .from('profiles')
            .select('id, email, full_name')
            .inFilter('id', userIds);
        for (final u in users as List) {
          final m = u as Map<String, dynamic>;
          userMap[m['id'] as String] = m;
        }
      }
      for (final r in rows) {
        r['profiles'] = userMap[r['user_id']];
      }
      _rows = rows;
    } catch (_) {
      _rows = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _setStatus(String id, String status) async {
    try {
      await supabase
          .from('redemption_requests')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM, h:mm a');
    return Scaffold(
      appBar: AppBar(title: const Text('Redemption Requests')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _rows.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 100),
                      Center(child: Text('No requests yet')),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final r = _rows[i];
                        final item = r['jewellery_catalog'] as Map?;
                        final user = r['profiles'] as Map?;
                        final status = r['status'] as String? ?? 'requested';
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item?['name'] ?? 'Item',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  _StatusChip(status: status),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${user?['email'] ?? '—'}  •  ${formatGrams((r['grams_redeemed'] as num).toDouble())}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted),
                              ),
                              const SizedBox(height: 4),
                              Text('Address: ${r['shipping_address']}',
                                  style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                'Requested ${fmt.format(DateTime.parse(r['created_at']).toLocal())}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.muted),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (status == 'requested')
                                    OutlinedButton(
                                      onPressed: () =>
                                          _setStatus(r['id'], 'approved'),
                                      child: const Text('Approve'),
                                    ),
                                  if (status == 'approved')
                                    OutlinedButton(
                                      onPressed: () =>
                                          _setStatus(r['id'], 'shipped'),
                                      child: const Text('Mark Shipped'),
                                    ),
                                  if (status == 'shipped')
                                    OutlinedButton(
                                      onPressed: () =>
                                          _setStatus(r['id'], 'delivered'),
                                      child: const Text('Mark Delivered'),
                                    ),
                                  if (status == 'requested' ||
                                      status == 'approved')
                                    TextButton(
                                      onPressed: () =>
                                          _setStatus(r['id'], 'rejected'),
                                      child: const Text('Reject',
                                          style: TextStyle(
                                              color: AppColors.danger)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'approved':
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        break;
      case 'shipped':
        bg = const Color(0xFFFFF8E1);
        fg = AppColors.darkGold;
        break;
      case 'delivered':
        bg = const Color(0xFFE8F5E9);
        fg = AppColors.success;
        break;
      case 'rejected':
      case 'cancelled':
        bg = const Color(0xFFFFEBEE);
        fg = AppColors.danger;
        break;
      default:
        bg = const Color(0xFFF5F5F5);
        fg = Colors.black87;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            color: fg, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
