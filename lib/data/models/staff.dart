/// The signed-in staff member, as `/api/staff/login`, `/token/refresh` and
/// `/me` return them. Roles can change at any time on the web, so this is
/// refreshed with every token refresh and when the app resumes.
class StaffProfile {
  const StaffProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    required this.roleLabel,
    required this.gymName,
    required this.hasPin,
    required this.sharedDevice,
    required this.permissions,
    required this.browseAllMembers,
  });

  factory StaffProfile.fromJson(Map<String, dynamic> json) => StaffProfile(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String? ?? '',
        roles: [for (final r in json['roles'] as List) r as String],
        roleLabel: json['role_label'] as String? ?? '',
        gymName: (json['gym'] as Map?)?['name'] as String? ?? '',
        hasPin: json['has_pin'] as bool? ?? false,
        sharedDevice: json['shared_device'] as bool? ?? false,
        permissions: {for (final p in json['permissions'] as List) p as String},
        browseAllMembers: json['browse_all_members'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'roles': roles,
        'role_label': roleLabel,
        'gym': {'name': gymName},
        'has_pin': hasPin,
        'shared_device': sharedDevice,
        'permissions': permissions.toList(),
        'browse_all_members': browseAllMembers,
      };

  final int id;
  final String name;
  final String email;
  final List<String> roles;
  final String roleLabel;
  final String gymName;
  final bool hasPin;

  /// Signed in with a PIN on the gym's front-desk device: front-desk work only.
  final bool sharedDevice;
  final Set<String> permissions;

  /// False for trainers (unless also a manager): they see only their clients.
  final bool browseAllMembers;

  /// Whether any of [names] is allowed in this session. The server checks
  /// every request anyway; this only decides what to show.
  bool can(String name, [String? or1, String? or2]) =>
      permissions.contains(name) ||
      (or1 != null && permissions.contains(or1)) ||
      (or2 != null && permissions.contains(or2));
}

/// The front-desk device this phone or tablet is enrolled as.
class FrontDeskDevice {
  const FrontDeskDevice({required this.id, required this.name, required this.gymName});

  factory FrontDeskDevice.fromJson(Map<String, dynamic> json) => FrontDeskDevice(
        id: json['id'] as int,
        name: json['name'] as String,
        gymName: (json['gym'] as Map?)?['name'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'gym': {'name': gymName}};

  final int id;
  final String name;
  final String gymName;
}

/// Someone who can sign in on the front-desk device (lock screen).
class LockScreenStaff {
  const LockScreenStaff({required this.id, required this.name, required this.initials, required this.roleLabel});

  factory LockScreenStaff.fromJson(Map<String, dynamic> json) => LockScreenStaff(
        id: json['id'] as int,
        name: json['name'] as String,
        initials: json['initials'] as String? ?? '',
        roleLabel: json['role_label'] as String? ?? '',
      );

  final int id;
  final String name;
  final String initials;
  final String roleLabel;
}

/// Tokens plus the profile, from any sign-in or refresh.
class SignInResult {
  const SignInResult({required this.token, required this.refreshToken, required this.staff});

  factory SignInResult.fromJson(Map<String, dynamic> json) => SignInResult(
        token: json['token'] as String,
        refreshToken: json['refresh_token'] as String,
        staff: StaffProfile.fromJson(json['staff'] as Map<String, dynamic>),
      );

  final String token;
  final String refreshToken;
  final StaffProfile staff;
}
