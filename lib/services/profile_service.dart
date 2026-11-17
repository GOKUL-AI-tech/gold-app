import '../main.dart';
import '../models/profile.dart';

class ProfileService {
  Future<Profile?> getCurrentProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromMap(data);
  }

  Future<void> upsertProfile({
    required String fullName,
    String? phone,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    await supabase.from('profiles').upsert({
      'id': user.id,
      'full_name': fullName,
      'email': user.email,
      'phone': phone,
    });
  }

  /// Generic patch — pass any subset of profile columns to update.
  Future<void> patchProfile(Map<String, dynamic> updates) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    if (updates.isEmpty) return;
    await supabase.from('profiles').update(updates).eq('id', user.id);
  }

  Future<List<Profile>> listAllUsers() async {
    final rows = await supabase
        .from('profiles')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((m) => Profile.fromMap(m as Map<String, dynamic>))
        .toList();
  }
}
