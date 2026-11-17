class Profile {
  // Core
  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final bool isAdmin;
  final DateTime createdAt;

  // Verification flags
  final bool emailVerified;
  final bool phoneVerified;

  // Personal
  final String? gender;
  final DateTime? dateOfBirth;
  final String? religion;
  final String? maritalStatus;
  final int? dependants;

  // Family
  final DateTime? weddingDate;
  final String? spouseName;
  final String? spouseGender;
  final DateTime? spouseDob;

  // Address
  final String? addrLabel;
  final String? addrDoorNo;
  final String? addrStreet;
  final String? addrArea;
  final String? addrCity;
  final String? addrState;
  final String? addrPincode;

  // Identity (last-4 masked)
  final String? aadhaarLast4;
  final String? panLast4;

  // Misc
  final String? nearestShowroom;
  final String? avatarUrl;

  Profile({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    this.isAdmin = false,
    required this.createdAt,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.gender,
    this.dateOfBirth,
    this.religion,
    this.maritalStatus,
    this.dependants,
    this.weddingDate,
    this.spouseName,
    this.spouseGender,
    this.spouseDob,
    this.addrLabel,
    this.addrDoorNo,
    this.addrStreet,
    this.addrArea,
    this.addrCity,
    this.addrState,
    this.addrPincode,
    this.aadhaarLast4,
    this.panLast4,
    this.nearestShowroom,
    this.avatarUrl,
  });

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      isAdmin: (map['is_admin'] as bool?) ?? false,
      createdAt: _parseDate(map['created_at']) ?? DateTime.now(),
      emailVerified: (map['email_verified'] as bool?) ?? false,
      phoneVerified: (map['phone_verified'] as bool?) ?? false,
      gender: map['gender'] as String?,
      dateOfBirth: _parseDate(map['date_of_birth']),
      religion: map['religion'] as String?,
      maritalStatus: map['marital_status'] as String?,
      dependants: (map['dependants'] as num?)?.toInt(),
      weddingDate: _parseDate(map['wedding_date']),
      spouseName: map['spouse_name'] as String?,
      spouseGender: map['spouse_gender'] as String?,
      spouseDob: _parseDate(map['spouse_dob']),
      addrLabel: map['addr_label'] as String? ?? 'Home',
      addrDoorNo: map['addr_door_no'] as String?,
      addrStreet: map['addr_street'] as String?,
      addrArea: map['addr_area'] as String?,
      addrCity: map['addr_city'] as String?,
      addrState: map['addr_state'] as String?,
      addrPincode: map['addr_pincode'] as String?,
      aadhaarLast4: map['aadhaar_last4'] as String?,
      panLast4: map['pan_last4'] as String?,
      nearestShowroom: map['nearest_showroom'] as String?,
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}
