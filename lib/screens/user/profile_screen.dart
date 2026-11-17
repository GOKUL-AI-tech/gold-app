import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../main.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/translations.dart';
import '../../services/locale_aware_mixin.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../auth/login_screen.dart';

/// Rich profile screen — dark "Gold Century" theme.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with LocaleAwareMixin {
  final _service = ProfileService();
  Profile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _service.getCurrentProfile();
    if (!mounted) return;
    setState(() {
      _profile = p;
      _loading = false;
    });
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    try {
      await _service.patchProfile(patch);
      await _load();
    } catch (e) {
      _toast('Save failed: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String _v(String? s) =>
      (s == null || s.trim().isEmpty) ? '-' : s.trim();

  String _vDate(DateTime? d) =>
      d == null ? '-' : DateFormat('dd MMM yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final p = _profile;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.gold),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(Translations.of('profile.title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppColors.gold),
            tooltip: Translations.of('drawer.support'),
            onPressed: () => _toast(Translations.of('profile.helpTip')),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _avatarHeader(p),
              const SizedBox(height: 20),
              _basicDetailsCard(p),
              const SizedBox(height: 12),
              _addressCard(p),
              const SizedBox(height: 12),
              _personalCard(p),
              const SizedBox(height: 12),
              _familyCard(p),
              const SizedBox(height: 12),
              _identityCard(p),
              const SizedBox(height: 12),
              _showroomCard(p),
              const SizedBox(height: 24),
              _actionButton(
                icon: Icons.lock_reset_outlined,
                label: Translations.of('auth.setPassword'),
                onTap: _showSetPasswordDialog,
              ),
              const SizedBox(height: 10),
              _actionButton(
                icon: Icons.logout,
                label: Translations.of('profile.signOut'),
                onTap: _signOut,
                danger: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Header ----------
  Widget _avatarHeader(Profile? p) {
    final initial = ((p?.fullName?.isNotEmpty == true
            ? p!.fullName![0]
            : (p?.email?.isNotEmpty == true ? p!.email![0] : '?'))
        .toUpperCase());

    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF1D689), Color(0xFFD9B556)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withOpacity(0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: GoogleFonts.inter(
                    color: AppColors.textOnGold,
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardElevated,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 1.5),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.edit,
                      size: 14, color: AppColors.gold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            p?.fullName ?? Translations.of('profile.yourProfile'),
            style: GoogleFonts.inter(
              color: AppColors.textOnDark,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (p?.email != null) ...[
            const SizedBox(height: 4),
            Text(
              p!.email!,
              style: const TextStyle(
                  color: AppColors.muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  // ---------- Card scaffold ----------
  Widget _sectionCard({
    required IconData icon,
    required String title,
    required VoidCallback onEdit,
    required Widget body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.gold.withOpacity(0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.gold, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.edit,
                      size: 16, color: AppColors.gold.withOpacity(0.8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
              height: 1,
              color: AppColors.gold.withOpacity(0.15)),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.muted)),
                const SizedBox(height: 3),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textOnDark)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _verifiedChip(bool verified, {VoidCallback? onVerify}) {
    if (verified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(Translations.of('common.verified'),
            style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      );
    }
    return GestureDetector(
      onTap: onVerify,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(Translations.of('common.verifyNow'),
            style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      ),
    );
  }

  // ---------- Basic Details ----------
  Widget _basicDetailsCard(Profile? p) {
    return _sectionCard(
      icon: Icons.person_outline,
      title: Translations.of('profile.basicDetails'),
      onEdit: () => _editBasicDetails(p),
      body: Column(
        children: [
          _kv(Translations.of('profile.name'), _v(p?.fullName)),
          _kv(
            Translations.of('profile.mobile'),
            _v(p?.phone),
            trailing: _verifiedChip(
              p?.phoneVerified ?? false,
              onVerify: () => _toast(Translations.of('profile.phoneOtpSoon')),
            ),
          ),
          _kv(
            Translations.of('profile.email'),
            _v(p?.email),
            trailing: _verifiedChip(
              p?.emailVerified ?? false,
              onVerify: () =>
                  _toast(Translations.of('profile.emailVerifyStub')),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Address ----------
  Widget _addressCard(Profile? p) {
    return _sectionCard(
      icon: Icons.location_on_outlined,
      title: Translations.of('profile.address'),
      onEdit: () => _editAddress(p),
      body: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8C36A), Color(0xFFB88A2A)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.home_outlined,
                      color: AppColors.textOnGold, size: 14),
                  const SizedBox(width: 6),
                  Text(p?.addrLabel ?? Translations.of('profile.home'),
                      style: GoogleFonts.inter(
                          color: AppColors.textOnGold,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _kv(Translations.of('profile.doorNo'), _v(p?.addrDoorNo)),
          _kv(Translations.of('profile.street'), _v(p?.addrStreet)),
          _kv(Translations.of('profile.area'), _v(p?.addrArea)),
          _kv(Translations.of('profile.city'), _v(p?.addrCity)),
          _kv(Translations.of('profile.state'), _v(p?.addrState)),
          _kv(Translations.of('profile.pinCode'), _v(p?.addrPincode)),
        ],
      ),
    );
  }

  // ---------- Personal Details ----------
  Widget _personalCard(Profile? p) {
    return _sectionCard(
      icon: Icons.account_circle_outlined,
      title: Translations.of('profile.personal'),
      onEdit: () => _editPersonal(p),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(child: _kv(Translations.of('profile.gender'), _v(p?.gender))),
              const SizedBox(width: 10),
              Expanded(child: _kv(Translations.of('profile.religion'), _v(p?.religion))),
            ],
          ),
          Row(
            children: [
              Expanded(
                  child: _kv(Translations.of('profile.dob'), _vDate(p?.dateOfBirth))),
              const SizedBox(width: 10),
              Expanded(
                  child: _kv(Translations.of('profile.marital'), _v(p?.maritalStatus))),
            ],
          ),
          _kv(Translations.of('profile.dependants'),
              p?.dependants == null ? '-' : '${p!.dependants}'),
        ],
      ),
    );
  }

  // ---------- Family ----------
  Widget _familyCard(Profile? p) {
    return _sectionCard(
      icon: Icons.family_restroom_outlined,
      title: Translations.of('profile.family'),
      onEdit: () => _editFamily(p),
      body: Column(
        children: [
          _kv(Translations.of('profile.wedding'), _vDate(p?.weddingDate)),
          Row(
            children: [
              Expanded(child: _kv(Translations.of('profile.spouseName'), _v(p?.spouseName))),
              const SizedBox(width: 10),
              Expanded(
                  child: _kv(Translations.of('profile.spouseGender'), _v(p?.spouseGender))),
              const SizedBox(width: 10),
              Expanded(
                  child: _kv(Translations.of('profile.spouseDob'), _vDate(p?.spouseDob))),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Identity Proof ----------
  Widget _identityCard(Profile? p) {
    return _sectionCard(
      icon: Icons.fingerprint,
      title: Translations.of('profile.identity'),
      onEdit: () => _toast(Translations.of('profile.tapLinkNow')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Linking your Aadhaar and PAN will help us digitally '
              'secure and recover your account.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 14),
          _idRow(
            label: Translations.of('profile.aadhaar'),
            value: p?.aadhaarLast4 == null
                ? Translations.of('profile.notLinked')
                : 'XXXX-XXXX-${p!.aadhaarLast4}',
            linked: p?.aadhaarLast4 != null,
            onLink: () => _editIdentity(p, isAadhaar: true),
          ),
          Divider(height: 24, color: AppColors.gold.withOpacity(0.15)),
          _idRow(
            label: Translations.of('profile.pan'),
            value: p?.panLast4 == null
                ? Translations.of('profile.notLinked')
                : 'XXXXXX${p!.panLast4}X',
            linked: p?.panLast4 != null,
            onLink: () => _editIdentity(p, isAadhaar: false),
          ),
          const SizedBox(height: 10),
          Text(
            Translations.of('profile.identityDisclaimer'),
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _idRow({
    required String label,
    required String value,
    required bool linked,
    required VoidCallback onLink,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.muted)),
              const SizedBox(height: 3),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textOnDark)),
            ],
          ),
        ),
        GestureDetector(
          onTap: onLink,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: linked
                  ? AppColors.cardElevated
                  : AppColors.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: linked ? AppColors.muted : AppColors.gold,
                width: 1,
              ),
            ),
            child: Text(
              linked ? 'Update' : 'Link Now',
              style: TextStyle(
                color: linked ? AppColors.muted : AppColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Showroom ----------
  Widget _showroomCard(Profile? p) {
    return _sectionCard(
      icon: Icons.storefront_outlined,
      title: Translations.of('profile.nearestShowroom'),
      onEdit: () => _editShowroom(p),
      body: Text(
        _v(p?.nearestShowroom),
        style: GoogleFonts.inter(
            fontSize: 14, color: AppColors.textOnDark),
      ),
    );
  }

  // ---------- Action Buttons ----------
  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? AppColors.danger : AppColors.gold;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios,
                color: color.withOpacity(0.5), size: 14),
          ],
        ),
      ),
    );
  }

  // ============================================================
  //  EDIT DIALOGS
  // ============================================================

  Future<void> _editBasicDetails(Profile? p) async {
    final name = TextEditingController(text: p?.fullName ?? '');
    final phone = TextEditingController(text: p?.phone ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.of('profile.editBasic')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration:
                    InputDecoration(labelText: Translations.of('profile.fullName'))),
            const SizedBox(height: 8),
            TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration:
                    InputDecoration(labelText: Translations.of('profile.mobile'))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(Translations.of('common.cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(Translations.of('common.save'))),
        ],
      ),
    );
    if (ok == true) {
      await _patch({
        'full_name': name.text.trim(),
        'phone': phone.text.trim(),
      });
    }
  }

  Future<void> _editAddress(Profile? p) async {
    final door = TextEditingController(text: p?.addrDoorNo ?? '');
    final street = TextEditingController(text: p?.addrStreet ?? '');
    final area = TextEditingController(text: p?.addrArea ?? '');
    final city = TextEditingController(text: p?.addrCity ?? '');
    final state = TextEditingController(text: p?.addrState ?? '');
    final pin = TextEditingController(text: p?.addrPincode ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.of('profile.editAddress')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: door,
                  decoration:
                      InputDecoration(labelText: Translations.of('profile.doorNo'))),
              TextField(
                  controller: street,
                  decoration:
                      InputDecoration(labelText: Translations.of('profile.street'))),
              TextField(
                  controller: area,
                  decoration: InputDecoration(
                      labelText: Translations.of('profile.area'))),
              TextField(
                  controller: city,
                  decoration: InputDecoration(labelText: Translations.of('profile.city'))),
              TextField(
                  controller: state,
                  decoration:
                      InputDecoration(labelText: Translations.of('profile.state'))),
              TextField(
                  controller: pin,
                  keyboardType: TextInputType.number,
                  decoration:
                      InputDecoration(labelText: Translations.of('profile.pinCode'))),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(Translations.of('common.cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(Translations.of('common.save'))),
        ],
      ),
    );
    if (ok == true) {
      await _patch({
        'addr_door_no': door.text.trim(),
        'addr_street': street.text.trim(),
        'addr_area': area.text.trim(),
        'addr_city': city.text.trim(),
        'addr_state': state.text.trim(),
        'addr_pincode': pin.text.trim(),
      });
    }
  }

  Future<void> _editPersonal(Profile? p) async {
    String? gender = p?.gender;
    String? religion = p?.religion;
    String? marital = p?.maritalStatus;
    DateTime? dob = p?.dateOfBirth;
    final dependants =
        TextEditingController(text: p?.dependants?.toString() ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(Translations.of('profile.editPersonal')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dropdown(
                    'Gender',
                    gender,
                    ['Male', 'Female', 'Other', 'Prefer not to say'],
                    (v) => setLocal(() => gender = v)),
                _dropdown(
                    'Religion',
                    religion,
                    [
                      'Hindu',
                      'Muslim',
                      'Christian',
                      'Sikh',
                      'Jain',
                      'Buddhist',
                      'Other'
                    ],
                    (v) => setLocal(() => religion = v)),
                _dropdown(
                    Translations.of('profile.marital'),
                    marital,
                    ['Single', 'Married', 'Divorced', 'Widowed'],
                    (v) => setLocal(() => marital = v)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(Translations.of('profile.dob')),
                  subtitle: Text(_vDate(dob)),
                  trailing:
                      const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: dob ?? DateTime(2000, 1, 1),
                      firstDate: DateTime(1925),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setLocal(() => dob = picked);
                  },
                ),
                TextField(
                    controller: dependants,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: Translations.of('profile.dependantsCount'))),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(Translations.of('common.cancel'))),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(Translations.of('common.save'))),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _patch({
        'gender': gender,
        'religion': religion,
        'marital_status': marital,
        'date_of_birth': dob?.toIso8601String().substring(0, 10),
        'dependants': int.tryParse(dependants.text.trim()),
      });
    }
  }

  Future<void> _editFamily(Profile? p) async {
    DateTime? wedding = p?.weddingDate;
    final spouse = TextEditingController(text: p?.spouseName ?? '');
    String? spouseGender = p?.spouseGender;
    DateTime? spouseDob = p?.spouseDob;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(Translations.of('profile.editFamily')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(Translations.of('profile.wedding')),
                  subtitle: Text(_vDate(wedding)),
                  trailing:
                      const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: wedding ?? DateTime(2010, 1, 1),
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null)
                      setLocal(() => wedding = picked);
                  },
                ),
                TextField(
                    controller: spouse,
                    decoration: InputDecoration(
                        labelText: Translations.of('profile.spouseName'))),
                _dropdown(Translations.of('profile.spouseGender'), spouseGender,
                    ['Male', 'Female', 'Other'],
                    (v) => setLocal(() => spouseGender = v)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(Translations.of('profile.spouseDob')),
                  subtitle: Text(_vDate(spouseDob)),
                  trailing:
                      const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: spouseDob ?? DateTime(2000, 1, 1),
                      firstDate: DateTime(1925),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null)
                      setLocal(() => spouseDob = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(Translations.of('common.cancel'))),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(Translations.of('common.save'))),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _patch({
        'wedding_date': wedding?.toIso8601String().substring(0, 10),
        'spouse_name': spouse.text.trim(),
        'spouse_gender': spouseGender,
        'spouse_dob': spouseDob?.toIso8601String().substring(0, 10),
      });
    }
  }

  Future<void> _editIdentity(Profile? p,
      {required bool isAadhaar}) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAadhaar ? Translations.of('profile.linkAadhaar') : Translations.of('profile.linkPan')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Translations.of('profile.last4Only'),
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: isAadhaar
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: InputDecoration(
                labelText: isAadhaar
                    ? Translations.of('profile.aadhaar12')
                    : Translations.of('profile.pan10'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(Translations.of('common.cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(Translations.of('common.save'))),
        ],
      ),
    );
    if (ok != true) return;
    final raw = ctrl.text.trim();
    if (isAadhaar && raw.length != 12) {
      _toast(Translations.of('profile.aadhaar12err'));
      return;
    }
    if (!isAadhaar && raw.length != 10) {
      _toast(Translations.of('profile.pan10err'));
      return;
    }
    final last4 = raw.substring(raw.length - 4);
    await _patch(
        {isAadhaar ? 'aadhaar_last4' : 'pan_last4': last4});
  }

  Future<void> _editShowroom(Profile? p) async {
    final ctrl =
        TextEditingController(text: p?.nearestShowroom ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.of('profile.nearestShowroom')),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
              labelText: Translations.of('profile.showroomHint')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(Translations.of('common.cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(Translations.of('common.save'))),
        ],
      ),
    );
    if (ok == true) {
      await _patch({'nearest_showroom': ctrl.text.trim()});
    }
  }

  Widget _dropdown(String label, String? value, List<String> items,
      ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DropdownButtonFormField<String>(
        value: value != null && items.contains(value) ? value : null,
        decoration: InputDecoration(labelText: label),
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _showSetPasswordDialog() async {
    final pwdCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(Translations.of('auth.setPassword')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'After saving, you can sign in with your email and '
                'this password — no OTP needed.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pwdCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: Translations.of('auth.newPassword'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setLocal(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: Translations.of('auth.confirmPassword'),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(Translations.of('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(Translations.of('common.save')),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final pwd = pwdCtrl.text;
    final confirm = confirmCtrl.text;

    if (pwd.length < 6) {
      _toast(Translations.of('auth.passwordMin6'));
      return;
    }
    if (pwd != confirm) {
      _toast(Translations.of('auth.passwordMismatch'));
      return;
    }
    try {
      await AuthService().updatePassword(pwd);
      _toast(
          Translations.of('auth.passwordUpdated'));
    } catch (e) {
      _toast('Could not update password: $e');
    }
  }
}
