enum UserRole { admin, agent }

class UserAccount {
  final String uid;
  final String username;
  final String displayName;
  final UserRole role;
  final String? agencyId;
  final String? boundDeviceFingerprint;
  final int maxOfflineDays;
  final DateTime? loginExpiryAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  UserAccount({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.role,
    this.agencyId,
    this.boundDeviceFingerprint,
    this.maxOfflineDays = 7,
    this.loginExpiryAt,
    this.isActive = true,
    required this.createdAt,
    this.lastLoginAt,
  });

  bool get isExpired => loginExpiryAt != null && DateTime.now().isAfter(loginExpiryAt!);
  int get daysUntilExpiry => loginExpiryAt != null ? loginExpiryAt!.difference(DateTime.now()).inDays : -1;

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'username': username,
    'displayName': displayName,
    'role': role.name,
    'agencyId': agencyId,
    'boundDeviceFingerprint': boundDeviceFingerprint,
    'maxOfflineDays': maxOfflineDays,
    'loginExpiryAt': loginExpiryAt?.toIso8601String(),
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'lastLoginAt': lastLoginAt?.toIso8601String(),
  };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
    uid: json['uid'] as String,
    username: json['username'] as String,
    displayName: json['displayName'] as String,
    role: json['role'] == 'admin' ? UserRole.admin : UserRole.agent,
    agencyId: json['agencyId'] as String?,
    boundDeviceFingerprint: json['boundDeviceFingerprint'] as String?,
    maxOfflineDays: json['maxOfflineDays'] as int? ?? 7,
    loginExpiryAt: json['loginExpiryAt'] != null ? DateTime.parse(json['loginExpiryAt'] as String) : null,
    isActive: json['isActive'] as bool? ?? true,
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastLoginAt: json['lastLoginAt'] != null ? DateTime.parse(json['lastLoginAt'] as String) : null,
  );

  factory UserAccount.fromFirestore(String uid, Map<String, dynamic> data) => UserAccount(
    uid: uid,
    username: data['username'] as String? ?? '',
    displayName: data['displayName'] as String? ?? '',
    role: data['role'] == 'admin' ? UserRole.admin : UserRole.agent,
    agencyId: data['agencyId'] as String?,
    boundDeviceFingerprint: data['boundDeviceFingerprint'] as String?,
    maxOfflineDays: data['maxOfflineDays'] as int? ?? 7,
    loginExpiryAt: data['loginExpiryAt'] != null ? (data['loginExpiryAt'] as dynamic).toDate() as DateTime : null,
    isActive: data['isActive'] as bool? ?? true,
    createdAt: (data['createdAt'] as dynamic).toDate() as DateTime,
    lastLoginAt: data['lastLoginAt'] != null ? (data['lastLoginAt'] as dynamic).toDate() as DateTime : null,
  );
}
