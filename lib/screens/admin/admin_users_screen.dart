import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../main.dart';
import '../../models/profile.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _service = ProfileService();
  List<Profile> _users    = [];
  List<Profile> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(_filter);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _users = await _service.listAllUsers();
      _filter();
    } catch (_) { _users = []; }
    if (mounted) setState(() => _loading = false);
  }

  void _filter() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_users)
          : _users.where((u) =>
              (u.fullName ?? '').toLowerCase().contains(q) ||
              (u.email    ?? '').toLowerCase().contains(q) ||
              (u.phone    ?? '').toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _toggleAdmin(Profile p) async {
    try {
      await supabase.from('profiles')
          .update({'is_admin': !p.isAdmin}).eq('id', p.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  String _initial(Profile u) {
    final name = u.fullName ?? u.email ?? '?';
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  void _showDetail(Profile u) {
    final fmt = DateFormat('dd MMM yyyy');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.charcoal,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.muted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2)),
            )),
            Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.gold.withOpacity(0.15),
                child: Text(_initial(u),
                    style: GoogleFonts.inter(color: AppColors.gold,
                        fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.fullName ?? '(no name)',
                      style: GoogleFonts.inter(color: AppColors.textOnDark,
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  Text(u.email ?? '—',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  if (u.isAdmin)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('ADMIN', style: TextStyle(
                          color: AppColors.gold, fontSize: 10,
                          fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ),
                ],
              )),
            ]),
            const SizedBox(height: 20),
            _sectionTitle('Account Info'),
            _row('Email',   u.email ?? '—'),
            _row('Phone',   u.phone ?? '—'),
            _row('Joined',  fmt.format(u.createdAt)),
            _row('Email Verified', u.emailVerified ? 'Yes' : 'No'),
            _row('Phone Verified', u.phoneVerified ? 'Yes' : 'No'),
            _sectionTitle('Personal Details'),
            _row('Gender',         u.gender ?? '—'),
            _row('Date of Birth',  u.dateOfBirth != null ? fmt.format(u.dateOfBirth!) : '—'),
            _row('Religion',       u.religion ?? '—'),
            _row('Marital Status', u.maritalStatus ?? '—'),
            _row('Dependants',     u.dependants?.toString() ?? '—'),
            _sectionTitle('Address (${u.addrLabel ?? "Home"})'),
            _row('Door No',  u.addrDoorNo ?? '—'),
            _row('Street',   u.addrStreet ?? '—'),
            _row('Area',     u.addrArea   ?? '—'),
            _row('City',     u.addrCity   ?? '—'),
            _row('State',    u.addrState  ?? '—'),
            _row('Pincode',  u.addrPincode ?? '—'),
            _sectionTitle('Identity'),
            _row('Aadhaar', u.aadhaarLast4 != null ? 'XXXX-XXXX-${u.aadhaarLast4}' : '—'),
            _row('PAN',     u.panLast4     != null ? 'XXXXXX${u.panLast4}' : '—'),
            _row('Showroom', u.nearestShowroom ?? '—'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.admin_panel_settings_outlined,
                    color: AppColors.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Admin Access',
                    style: GoogleFonts.inter(color: AppColors.textOnDark,
                        fontWeight: FontWeight.w600))),
                Switch(
                  value: u.isAdmin,
                  activeColor: AppColors.gold,
                  onChanged: (_) {
                    Navigator.pop(context);
                    _toggleAdmin(u);
                  },
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(t,
        style: GoogleFonts.inter(color: AppColors.gold,
            fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 130,
          child: Text(label,
              style: const TextStyle(color: AppColors.muted, fontSize: 13))),
      Expanded(child: Text(value,
          style: const TextStyle(color: AppColors.textOnDark,
              fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _search,
                style: const TextStyle(color: AppColors.textOnDark),
                decoration: InputDecoration(
                  hintText: 'Search name, email, phone…',
                  hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: AppColors.muted, size: 20),
                  filled: true,
                  fillColor: AppColors.cardBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.gold),
              onPressed: _load,
              tooltip: 'Refresh',
            ),
          ]),
        ),
        if (!_loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filtered.length} user${_filtered.length == 1 ? "" : "s"}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : _filtered.isEmpty
                  ? Center(child: Text('No users found',
                        style: GoogleFonts.inter(color: AppColors.muted)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _UserCard(
                        user: _filtered[i],
                        onTap: () => _showDetail(_filtered[i]),
                      ),
                    ),
        ),
      ]),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Profile user;
  final VoidCallback onTap;
  const _UserCard({required this.user, required this.onTap});

  String _initial() {
    final n = user.fullName ?? user.email ?? '?';
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.gold.withOpacity(0.15),
            child: Text(_initial(),
                style: GoogleFonts.inter(color: AppColors.gold,
                    fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(user.fullName ?? '(no name)',
                      style: GoogleFonts.inter(color: AppColors.textOnDark,
                          fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (user.isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('ADMIN', style: TextStyle(
                        color: AppColors.gold, fontSize: 9,
                        fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  ),
              ]),
              const SizedBox(height: 2),
              Text(user.email ?? '—',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (user.phone != null) ...[
                const SizedBox(height: 1),
                Text(user.phone!,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ],
          )),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmt.format(user.createdAt),
                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 18),
          ]),
        ]),
      ),
    );
  }
}
