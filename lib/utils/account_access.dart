String accountRole(Map<String, dynamic> data) =>
    (data['role'] as String? ?? 'customer').trim().toLowerCase();

bool hasAdminAccess(Map<String, dynamic> data) {
  final role = accountRole(data);
  if (role == 'admin' || role == 'superadmin') return true;
  final flag = data['adminusertype'];
  if (flag is bool) return flag;
  if (flag is String) return flag.trim().toLowerCase() == 'true';
  if (flag is num) return flag != 0;
  return false;
}

bool hasStaffAccess(Map<String, dynamic> data) =>
    hasAdminAccess(data) || ['staff', 'vet'].contains(accountRole(data));

String adminAccessDetails({
  required String projectId,
  required String uid,
  required String? email,
  required Map<String, dynamic>? profile,
}) =>
    'Administrator access could not be verified.\n\n'
    'Account: ${email ?? "unknown"}\n'
    'Firebase project: $projectId\n'
    'Profile: users/$uid\n'
    'Role: ${profile?["role"] ?? "missing"}\n'
    'adminusertype: ${profile?["adminusertype"] ?? "missing"}\n\n'
    'Check this exact profile in Firebase Console. Set role to admin or '
    'superadmin, or adminusertype to Boolean true.';
