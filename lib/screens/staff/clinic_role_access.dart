String normalizeClinicRole(String? role) => (role ?? '').trim().toLowerCase();

bool canUseClinicalDecisionSupport(String? role) =>
    normalizeClinicRole(role) == 'staff';
