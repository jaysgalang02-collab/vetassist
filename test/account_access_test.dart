import 'package:flutter_test/flutter_test.dart';
import 'package:vetassist/utils/account_access.dart';

void main() {
  test('rejection identifies the exact Firebase profile being checked', () {
    final details = adminAccessDetails(
      projectId: 'test-project',
      uid: 'signed-in-uid',
      email: 'staff@example.com',
      profile: {'role': 'staff', 'adminusertype': false},
    );
    expect(details, contains('test-project'));
    expect(details, contains('users/signed-in-uid'));
    expect(details, contains('staff@example.com'));
    expect(details, contains('Role: staff'));
    expect(details, contains('adminusertype: false'));
  });

  test('admin and superadmin can enter both privileged portals', () {
    for (final role in ['admin', 'superadmin', ' ADMIN ', 'SuperAdmin']) {
      expect(hasAdminAccess({'role': role}), isTrue);
      expect(hasStaffAccess({'role': role}), isTrue);
    }
  });

  test('legacy admin flags grant access', () {
    for (final flag in [true, 'true', ' TRUE ', 1]) {
      expect(hasAdminAccess({'role': 'staff', 'adminusertype': flag}), isTrue);
    }
  });

  test('ordinary accounts cannot enter the admin portal', () {
    for (final data in <Map<String, dynamic>>[
      {},
      {'role': 'customer'},
      {'role': 'staff', 'adminusertype': false},
      {'role': 'vet', 'adminusertype': 'false'},
      {'role': 'user', 'adminusertype': 0},
    ]) {
      expect(hasAdminAccess(data), isFalse);
    }
  });
}
