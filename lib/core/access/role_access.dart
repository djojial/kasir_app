const List<String> kRoleKeys = ['admin', 'owner', 'operator'];

const List<String> kAccessPages = [
  'dashboard',
  'transaksi',
  'stok',
  'laporan',
  'users',
];

const List<String> kAccessFeatures = [
  'stok_tambah',
  'stok_edit',
  'stok_hapus',
  'users_create',
  'users_edit',
  'users_hapus',
];

const Map<String, Map<String, Map<String, bool>>> kDefaultRoleAccess = {
  'admin': {
    'pages': {
      'dashboard': true,
      'transaksi': true,
      'stok': true,
      'laporan': true,
      'users': true,
    },
    'features': {
      'stok_tambah': true,
      'stok_edit': true,
      'stok_hapus': true,
      'users_create': true,
      'users_edit': true,
      'users_hapus': true,
    },
  },
  'owner': {
    'pages': {
      'dashboard': true,
      'transaksi': false,
      'stok': true,
      'laporan': true,
      'users': false,
    },
    'features': {
      'stok_tambah': false,
      'stok_edit': false,
      'stok_hapus': false,
      'users_create': false,
      'users_edit': false,
      'users_hapus': false,
    },
  },
  'operator': {
    'pages': {
      'dashboard': false,
      'transaksi': true,
      'stok': true,
      'laporan': false,
      'users': false,
    },
    'features': {
      'stok_tambah': true,
      'stok_edit': false,
      'stok_hapus': true,
      'users_create': false,
      'users_edit': false,
      'users_hapus': false,
    },
  },
};

Map<String, Map<String, Map<String, bool>>> mergeRoleAccessConfig(
  Map<String, dynamic>? raw,
) {
  final result = <String, Map<String, Map<String, bool>>>{};
  for (final role in kRoleKeys) {
    final base = kDefaultRoleAccess[role]!;
    result[role] = {
      'pages': Map<String, bool>.from(base['pages']!),
      'features': Map<String, bool>.from(base['features']!),
    };
  }

  if (raw == null) return result;
  for (final role in kRoleKeys) {
    final roleRaw = raw[role];
    if (roleRaw is! Map) continue;
    final pagesRaw = roleRaw['pages'];
    if (pagesRaw is Map) {
      for (final key in result[role]!['pages']!.keys) {
        final val = pagesRaw[key];
        if (val is bool) {
          result[role]!['pages']![key] = val;
        }
      }
    }
    final featuresRaw = roleRaw['features'];
    if (featuresRaw is Map) {
      for (final key in result[role]!['features']!.keys) {
        final val = featuresRaw[key];
        if (val is bool) {
          result[role]!['features']![key] = val;
        }
      }
    }
  }

  return result;
}

Map<String, Map<String, bool>> applyAccessOverride(
  Map<String, Map<String, bool>> base,
  Map<String, dynamic>? override,
) {
  final result = {
    'pages': Map<String, bool>.from(base['pages'] ?? {}),
    'features': Map<String, bool>.from(base['features'] ?? {}),
  };
  if (override == null) return result;

  final pagesRaw = override['pages'];
  if (pagesRaw is Map) {
    for (final key in result['pages']!.keys) {
      final val = pagesRaw[key];
      if (val is bool) {
        result['pages']![key] = val;
      }
    }
  }
  final featuresRaw = override['features'];
  if (featuresRaw is Map) {
    for (final key in result['features']!.keys) {
      final val = featuresRaw[key];
      if (val is bool) {
        result['features']![key] = val;
      }
    }
  }

  return result;
}
