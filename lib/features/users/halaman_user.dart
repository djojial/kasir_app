import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../core/ui/app_feedback.dart';
import '../../core/ui/interactive_widgets.dart';
import '../../core/access/role_access.dart';
import '../../database/services/firestore_service.dart';
import '../../firebase_options.dart';

class HalamanUser extends StatefulWidget {
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final bool canEditRoleDefaults;

  const HalamanUser({
    super.key,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
    required this.canEditRoleDefaults,
  });

  @override
  State<HalamanUser> createState() => _HalamanUserState();
}

class _HalamanUserState extends State<HalamanUser> {
  final _firestore = FirestoreService();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _nicknameC = TextEditingController();
  String _role = 'operator';
  bool _loading = false;
  Future<FirebaseApp>? _secondaryAppFuture;
  Map<String, String>? _actorCache;

  static const _roles = kRoleKeys;
  static const _pageLabels = {
    'dashboard': 'Dashboard',
    'transaksi': 'Transaksi',
    'stok': 'Stok',
    'laporan': 'Laporan',
    'aktivitas': 'Aktivitas Sistem',
    'users': 'Users',
  };
  static const _featureLabels = {
    'stok_tambah': 'Stok: Tambah',
    'stok_edit': 'Stok: Edit',
    'stok_hapus': 'Stok: Hapus',
    'users_create': 'Users: Create',
    'users_edit': 'Users: Edit',
    'users_hapus': 'Users: Hapus',
  };

  Map<String, Map<String, bool>>? _defaultRoleDraft;
  String? _defaultRoleKey;
  String? _defaultRoleFingerprint;

  bool _customAccessEnabled = false;
  Map<String, Map<String, bool>>? _customAccessDraft;
  String? _customAccessRoleKey;
  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    _nicknameC.dispose();
    super.dispose();
  }

  Future<FirebaseApp> _initSecondary() async {
    return Firebase.initializeApp(
      name: 'userCreation',
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  Future<Map<String, String>> _resolveActor() async {
    if (_actorCache != null) return _actorCache!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _actorCache = {'name': 'Unknown'};
      return _actorCache!;
    }
    final email = user.email ?? '';
    var name = user.displayName?.trim() ?? '';
    try {
      final profile =
          await _firestore.streamUserProfile(user.uid, email: user.email).first;
      final nick = (profile?['nama_panggilan'] ?? '').toString().trim();
      if (nick.isNotEmpty) {
        name = nick;
      }
    } catch (_) {}
    if (name.isEmpty && email.isNotEmpty) {
      name = email.split('@').first;
    }
    _actorCache = {
      'uid': user.uid,
      'email': email,
      'name': name,
    };
    return _actorCache!;
  }

  Future<void> _createUser() async {
    if (_loading) return;
    final email = _emailC.text.trim();
    final password = _passC.text;
    final nickname = _nicknameC.text.trim();
    if (nickname.isEmpty) {
      AppFeedback.show(
        context,
        message: 'Nama panggilan wajib diisi',
        type: AppFeedbackType.info,
      );
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      AppFeedback.show(
        context,
        message: 'Email dan password wajib diisi',
        type: AppFeedbackType.info,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      _secondaryAppFuture ??= _initSecondary();
      final app = await _secondaryAppFuture!;
      final auth = FirebaseAuth.instanceFor(app: app);
      final cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _firestore.upsertUserRole(
        uid: cred.user!.uid,
        email: email,
        role: _role,
        namaPanggilan: nickname,
        accessOverride: _customAccessEnabled
            ? _serializeAccess(_customAccessDraft)
            : null,
      );
      final actor = await _resolveActor();
      await _firestore.logActivity(
        action: 'user_create',
        category: 'user',
        targetId: cred.user!.uid,
        targetLabel: email,
        meta: {
          'role': _role,
          'nama_panggilan': nickname,
        },
        actor: actor,
      );
      await auth.signOut();
      if (!mounted) return;
      _emailC.clear();
      _passC.clear();
      _nicknameC.clear();
      setState(() {
        _role = 'operator';
        _customAccessEnabled = false;
        _customAccessDraft = null;
        _customAccessRoleKey = null;
      });
      AppFeedback.show(
        context,
        message: 'User berhasil dibuat',
        type: AppFeedbackType.success,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'email-already-in-use'
          ? 'Email sudah terdaftar'
          : e.code == 'weak-password'
              ? 'Password terlalu lemah'
              : e.message ?? 'Gagal membuat user';
      AppFeedback.show(
        context,
        message: message,
        type: AppFeedbackType.error,
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: 'Gagal membuat user',
        type: AppFeedbackType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resetPassword(String email) async {
    final target = email.trim().toLowerCase();
    if (target.isEmpty) {
      AppFeedback.show(
        context,
        message: 'Email belum terisi',
        type: AppFeedbackType.info,
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: target);
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: 'Link reset password dikirim ke $target',
        type: AppFeedbackType.success,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: e.code == 'user-not-found'
            ? 'Email belum terdaftar di Auth'
            : e.message ?? 'Gagal kirim reset password',
        type: AppFeedbackType.error,
      );
    }
  }

  Future<void> _resetPasswordViaAdmin({
    required String email,
    required String role,
  }) async {
    final target = email.trim().toLowerCase();
    if (target.isEmpty) {
      AppFeedback.show(
        context,
        message: 'Email belum terisi',
        type: AppFeedbackType.info,
      );
      return;
    }

    await _resetPassword(target);
  }

  Future<void> _deleteUserDoc({
    required String uid,
    required String email,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Akun'),
          content: Text(
            'Hapus data user $email dari daftar? Akun Firebase Auth tetap ada.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
    if (result != true) return;
    await _firestore.hapusUser(uid);
    final actor = await _resolveActor();
    await _firestore.logActivity(
      action: 'user_delete',
      category: 'user',
      targetId: uid,
      targetLabel: email,
      meta: {
        'email': email,
      },
      actor: actor,
    );
    if (!mounted) return;
    AppFeedback.show(
      context,
      message: 'Data user dihapus',
      type: AppFeedbackType.success,
    );
  }

  Future<void> _toggleUserDisabled({
    required String uid,
    required String email,
    required bool disabled,
    required String role,
    required bool isVirtual,
  }) async {
    final nextDisabled = !disabled;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(nextDisabled ? 'Nonaktifkan Akun' : 'Aktifkan Akun'),
          content: Text(
            nextDisabled
                ? 'Nonaktifkan akses login untuk $email?'
                : 'Aktifkan kembali akses login untuk $email?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    if (result != true) return;
    if (isVirtual) {
      await _firestore.upsertUserRole(
        uid: uid,
        email: email,
        role: role,
        disabled: nextDisabled,
      );
    } else {
      await _firestore.setUserDisabled(uid, nextDisabled);
    }
    final actor = await _resolveActor();
    await _firestore.logActivity(
      action: nextDisabled ? 'user_disable' : 'user_enable',
      category: 'user',
      targetId: uid,
      targetLabel: email,
      meta: {
        'disabled': nextDisabled,
        'role': role,
      },
      actor: actor,
    );
    if (!mounted) return;
    AppFeedback.show(
      context,
      message: nextDisabled ? 'Akun dinonaktifkan' : 'Akun diaktifkan',
      type: AppFeedbackType.success,
    );
  }

  Future<void> _changeEmail({
    required String uid,
    required String currentEmail,
    required List<Map<String, dynamic>> users,
  }) async {
    final controller = TextEditingController(text: currentEmail);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ubah Username'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gunakan email baru untuk akun ini.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    if (result != true) return;

    final nextEmail = controller.text.trim().toLowerCase();
    if (nextEmail.isEmpty) {
      AppFeedback.show(
        context,
        message: 'Email wajib diisi',
        type: AppFeedbackType.info,
      );
      return;
    }
    final exists = users.any((u) {
      final email = (u['email'] ?? '').toString().toLowerCase();
      return email == nextEmail;
    });
    if (exists && nextEmail != currentEmail.toLowerCase()) {
      AppFeedback.show(
        context,
        message: 'Email sudah terdaftar',
        type: AppFeedbackType.info,
      );
      return;
    }

    await _firestore.updateUserEmail(uid, nextEmail);
    final actor = await _resolveActor();
    await _firestore.logActivity(
      action: 'user_update_email',
      category: 'user',
      targetId: uid,
      targetLabel: nextEmail,
      meta: {
        'email_lama': currentEmail,
        'email_baru': nextEmail,
      },
      actor: actor,
    );
    if (!mounted) return;
    AppFeedback.show(
      context,
      message: 'Username diperbarui',
      type: AppFeedbackType.success,
    );
  }

  Future<void> _changeNickname({
    required String uid,
    required String currentNickname,
  }) async {
    final controller = TextEditingController(text: currentNickname);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ubah Nama Panggilan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Masukkan nama panggilan yang akan ditampilkan.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Nama panggilan',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    final nextNickname = controller.text.trim();
    controller.dispose();
    if (result != true) return;
    if (nextNickname.isEmpty) {
      AppFeedback.show(
        context,
        message: 'Nama panggilan wajib diisi',
        type: AppFeedbackType.info,
      );
      return;
    }

    await _firestore.updateUserNickname(uid, nextNickname);
    final actor = await _resolveActor();
    await _firestore.logActivity(
      action: 'user_update_nickname',
      category: 'user',
      targetId: uid,
      targetLabel: nextNickname,
      meta: {
        'nama_lama': currentNickname,
        'nama_baru': nextNickname,
      },
      actor: actor,
    );
    if (!mounted) return;
    AppFeedback.show(
      context,
      message: 'Nama panggilan diperbarui',
      type: AppFeedbackType.success,
    );
  }

  Future<void> _changeRole({
    required String uid,
    required String email,
    required String currentRole,
  }) async {
    var selectedRole = currentRole;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ubah Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                email,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _roles.map((role) {
                  final selected = selectedRole == role;
                  final color = _roleColor(role);
                  return ChoiceChip(
                    label: Text(_roleLabel(role)),
                    selected: selected,
                    selectedColor: color.withValues(alpha: 0.22),
                    side: BorderSide(
                      color:
                          selected ? color : Theme.of(context).dividerColor,
                    ),
                    labelStyle: TextStyle(
                      color: selected
                          ? color
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) {
                      selectedRole = role;
                      (context as Element).markNeedsBuild();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (result != true) return;
    await _firestore.upsertUserRole(
      uid: uid,
      email: email,
      role: selectedRole,
    );
    final actor = await _resolveActor();
    await _firestore.logActivity(
      action: 'user_update_role',
      category: 'user',
      targetId: uid,
      targetLabel: email,
      meta: {
        'role_lama': currentRole,
        'role_baru': selectedRole,
      },
      actor: actor,
    );
    if (!mounted) return;
    AppFeedback.show(
      context,
      message: 'Role diperbarui menjadi ${_roleLabel(selectedRole)}',
      type: AppFeedbackType.success,
    );
  }

  Map<String, Map<String, bool>> _cloneAccess(
    Map<String, Map<String, bool>> source,
  ) {
    return {
      'pages': Map<String, bool>.from(source['pages'] ?? {}),
      'features': Map<String, bool>.from(source['features'] ?? {}),
    };
  }

  String _fingerprintAccess(Map<String, Map<String, bool>> access) {
    final pages = access['pages'] ?? {};
    final features = access['features'] ?? {};
    final parts = [
      for (final key in kAccessPages) '$key:${pages[key] == true}',
      for (final key in kAccessFeatures) '$key:${features[key] == true}',
    ];
    return parts.join('|');
  }

  Map<String, dynamic> _serializeAccess(
    Map<String, Map<String, bool>>? access,
  ) {
    if (access == null) return {};
    return {
      'pages': Map<String, bool>.from(access['pages'] ?? {}),
      'features': Map<String, bool>.from(access['features'] ?? {}),
    };
  }

  void _ensureDefaultDraft(Map<String, Map<String, bool>> defaultAccess) {
    final fingerprint = _fingerprintAccess(defaultAccess);
    if (_defaultRoleDraft == null ||
        _defaultRoleKey != _role ||
        _defaultRoleFingerprint != fingerprint) {
      _defaultRoleDraft = _cloneAccess(defaultAccess);
      _defaultRoleKey = _role;
      _defaultRoleFingerprint = fingerprint;
    }
  }

  void _ensureCustomDraft(Map<String, Map<String, bool>> defaultAccess) {
    if (_customAccessDraft == null || _customAccessRoleKey != _role) {
      _customAccessDraft = _cloneAccess(defaultAccess);
      _customAccessRoleKey = _role;
    }
  }

  Future<void> _saveDefaultRoleAccess() async {
    if (_defaultRoleDraft == null) return;
    await _firestore.setRoleAccessConfig({
      _role: _serializeAccess(_defaultRoleDraft),
    });
    final actor = await _resolveActor();
    await _firestore.logActivity(
      action: 'role_default_update',
      category: 'user',
      targetLabel: _role,
      meta: {
        'role': _role,
      },
      actor: actor,
    );
    if (!mounted) return;
    AppFeedback.show(
      context,
      message: 'Default akses ${_roleLabel(_role)} diperbarui',
      type: AppFeedbackType.success,
    );
  }

  Future<void> _openDefaultRoleModal(
    Map<String, Map<String, Map<String, bool>>> roleConfig,
  ) async {
    if (!widget.canEditRoleDefaults) return;
    final base = roleConfig[_role] ?? kDefaultRoleAccess[_role]!;
    _ensureDefaultDraft(base);
    var draft = _cloneAccess(_defaultRoleDraft ?? base);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Default Role: ${_roleLabel(_role)}'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) {
                          final isWide =
                              MediaQuery.of(context).size.width >= 900;
                          final roleColor = _roleColor(_role);
                          final panelDecoration = BoxDecoration(
                            color: roleColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _luxShadow(context),
                            border: Border.all(
                              color:
                                  Theme.of(context).dividerColor.withValues(
                                        alpha: 0.6,
                                      ),
                            ),
                          );
                          Widget panel(Widget child) => Container(
                                padding: const EdgeInsets.all(12),
                                decoration: panelDecoration,
                                child: child,
                              );

                          final pageSection = _buildAccessSection(
                            title: 'Halaman',
                            labels: _pageLabels,
                            values: draft['pages'] ?? {},
                            editable: true,
                            accentColor: roleColor,
                            useGrid: false,
                            badgeColor: roleColor,
                            onToggle: (key, value) {
                              setDialogState(() {
                                draft['pages']![key] = value;
                              });
                            },
                          );
                          final featureSection = _buildAccessSection(
                            title: 'Fitur',
                            labels: _featureLabels,
                            values: draft['features'] ?? {},
                            editable: true,
                            accentColor: roleColor,
                            useGrid: false,
                            badgeColor: roleColor,
                            onToggle: (key, value) {
                              setDialogState(() {
                                draft['features']![key] = value;
                              });
                            },
                          );

                          if (!isWide) {
                            return Column(
                              children: [
                                panel(pageSection),
                                const SizedBox(height: 12),
                                panel(featureSection),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: panel(pageSection)),
                              const SizedBox(width: 12),
                              Expanded(child: panel(featureSection)),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Simpan Default'),
            ),
          ],
        );
      },
    );

    if (result != true) return;
    setState(() {
      _defaultRoleDraft = draft;
      _defaultRoleKey = _role;
      _defaultRoleFingerprint = _fingerprintAccess(draft);
    });
    await _saveDefaultRoleAccess();
  }

  Future<void> _editUserAccess({
    required String uid,
    required String role,
    required Map<String, dynamic>? overrideRaw,
    required Map<String, Map<String, Map<String, bool>>> roleConfig,
  }) async {
    final base = roleConfig[role] ?? kDefaultRoleAccess[role]!;
    var customEnabled = overrideRaw != null;
    var draft = customEnabled
        ? applyAccessOverride(base, overrideRaw)
        : _cloneAccess(base);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Akses Khusus'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SingleChildScrollView(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Switch.adaptive(
                          value: customEnabled,
                          onChanged: (value) {
                            setDialogState(() => customEnabled = value);
                            if (!value) {
                              draft = _cloneAccess(base);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text('Gunakan akses khusus'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.maxFinite,
                      child: _buildAccessSection(
                        title: 'Halaman',
                        labels: _pageLabels,
                        values: draft['pages'] ?? {},
                        editable: customEnabled,
                        accentColor: _roleColor(role),
                        useGrid: false,
                        onToggle: (key, value) {
                          setDialogState(() {
                            draft['pages']![key] = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.maxFinite,
                      child: _buildAccessSection(
                        title: 'Fitur',
                        labels: _featureLabels,
                        values: draft['features'] ?? {},
                        editable: customEnabled,
                        accentColor: _roleColor(role),
                        useGrid: false,
                        onToggle: (key, value) {
                          setDialogState(() {
                            draft['features']![key] = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (result != true) return;
    await _firestore.updateUserAccessOverride(
      uid,
      customEnabled ? _serializeAccess(draft) : null,
    );
    final actor = await _resolveActor();
    await _firestore.logActivity(
      action: 'user_access_override',
      category: 'user',
      targetId: uid,
      meta: {
        'enabled': customEnabled,
      },
      actor: actor,
    );
    if (!mounted) return;
    AppFeedback.show(
      context,
      message: 'Akses khusus diperbarui',
      type: AppFeedbackType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 720;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestore.streamUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snapshot.data!;
        final total = users.length;
        final ownerCount =
            users.where((u) => (u['role'] ?? '') == 'owner').length;
        final adminCount =
            users.where((u) => (u['role'] ?? '') == 'admin').length;
        final operatorCount =
            users.where((u) => (u['role'] ?? '') == 'operator').length;
        return StreamBuilder<Map<String, dynamic>?>(
          stream: _firestore.streamRoleAccessConfig(),
          builder: (context, accessSnap) {
            final roleAccessConfig =
                mergeRoleAccessConfig(accessSnap.data);
            final defaultAccess =
                roleAccessConfig[_role] ?? kDefaultRoleAccess[_role]!;
            _ensureDefaultDraft(defaultAccess);
            if (_customAccessEnabled) {
              _ensureCustomDraft(defaultAccess);
            } else {
              _customAccessDraft = null;
              _customAccessRoleKey = null;
            }

            return Padding(
              padding: EdgeInsets.all(isNarrow ? 16 : 24),
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.14),
                          Theme.of(context).colorScheme.surface,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child:
                                  const Icon(Icons.manage_accounts_outlined),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kelola Pengguna',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Buat akun baru, tetapkan role, dan pantau akses.',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _statPill(context, 'Total', total.toString()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _statCard(
                              context,
                              'Admin',
                              adminCount,
                              _roleColor('admin'),
                            ),
                            _statCard(
                              context,
                              'Owner',
                              ownerCount,
                              _roleColor('owner'),
                            ),
                            _statCard(
                              context,
                              'Operator',
                              operatorCount,
                              _roleColor('operator'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isNarrow)
                    Column(
                      children: [
                        _buildFormCard(context, roleAccessConfig),
                        const SizedBox(height: 12),
                        _buildRoleGuide(context),
                        const SizedBox(height: 12),
                        _buildUserListCard(
                          context,
                          users,
                          total,
                          roleAccessConfig,
                          height: 320,
                        ),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              _buildFormCard(context, roleAccessConfig),
                              const SizedBox(height: 12),
                              _buildRoleGuide(context),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: _buildUserListCard(
                            context,
                            users,
                            total,
                            roleAccessConfig,
                            height: 380,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
      },
    );
      },
    );
  }

  Widget _buildFormCard(
    BuildContext context,
    Map<String, Map<String, Map<String, bool>>> roleAccessConfig,
  ) {
    final isWide = MediaQuery.of(context).size.width >= 920;
    return HoverCard(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: _luxShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.person_add_alt_1_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buat Akun Baru',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Akun langsung terintegrasi ke Firebase Auth.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!widget.canCreate)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Akses membuat akun dibatasi.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
            if (isWide)
              Column(
                children: [
                  FocusTextField(
                    controller: _nicknameC,
                    enabled: widget.canCreate,
                    decoration: const InputDecoration(
                      labelText: 'Nama panggilan',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FocusTextField(
                          controller: _emailC,
                          keyboardType: TextInputType.emailAddress,
                          enabled: widget.canCreate,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FocusTextField(
                          controller: _passC,
                          obscureText: true,
                          enabled: widget.canCreate,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else ...[
              FocusTextField(
                controller: _nicknameC,
                enabled: widget.canCreate,
                decoration: const InputDecoration(
                  labelText: 'Nama panggilan',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              FocusTextField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                enabled: widget.canCreate,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              FocusTextField(
                controller: _passC,
                obscureText: true,
                enabled: widget.canCreate,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Role akses',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Role menentukan akses bawaan. Ubah "Default Akses" untuk mengubah aturan semua akun dengan role ini.',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _roles.map((role) {
                      final selected = _role == role;
                      final color = _roleColor(role);
                      return ChoiceChip(
                        label: Text(_roleLabel(role)),
                        selected: selected,
                        selectedColor: color.withValues(alpha: 0.22),
                        side: BorderSide(
                          color:
                              selected ? color : Theme.of(context).dividerColor,
                        ),
                        labelStyle: TextStyle(
                          color: selected
                              ? color
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: _loading
                            ? null
                            : (_) => setState(() {
                                _role = role;
                                _defaultRoleDraft = null;
                                _defaultRoleKey = null;
                                _defaultRoleFingerprint = null;
                                if (_customAccessEnabled) {
                                  _customAccessDraft = null;
                                  _customAccessRoleKey = null;
                                }
                              }),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: widget.canEditRoleDefaults
                      ? () => _openDefaultRoleModal(roleAccessConfig)
                      : null,
                  icon: const Icon(Icons.tune),
                  label: const Text('Default Akses'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Switch.adaptive(
                  value: _customAccessEnabled,
                  onChanged: widget.canCreate
                      ? (value) {
                          setState(() {
                            _customAccessEnabled = value;
                            if (!value) {
                              _customAccessDraft = null;
                              _customAccessRoleKey = null;
                            }
                          });
                        }
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  'Akses Khusus',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
                Text(
                  _customAccessEnabled
                      ? 'Hanya berlaku untuk akun yang dibuat ini.'
                      : 'Jika OFF, akun mengikuti Default Role.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
                ),
            if (_customAccessEnabled) ...[
              const SizedBox(height: 8),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 560;
                  final roleColor = _roleColor(_role);
                  final panelDecoration = BoxDecoration(
                    color: roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                    boxShadow: _luxShadow(context),
                  );
                  Widget panel(Widget child) => Container(
                        padding: const EdgeInsets.all(12),
                        decoration: panelDecoration,
                        child: child,
                      );
                  final pageSection = _buildAccessSection(
                    title: 'Akses Halaman',
                    labels: _pageLabels,
                    values: _customAccessDraft?['pages'] ?? const {},
                    editable: true,
                    accentColor: _roleColor(_role),
                    icon: Icons.view_module_outlined,
                    onToggle: (key, value) {
                      setState(() {
                        _customAccessDraft ??=
                            _cloneAccess(kDefaultRoleAccess[_role]!);
                        _customAccessDraft?['pages']?[key] = value;
                      });
                    },
                  );
                  final featureSection = _buildAccessSection(
                    title: 'Akses Fitur',
                    labels: _featureLabels,
                    values: _customAccessDraft?['features'] ?? const {},
                    editable: true,
                    accentColor: _roleColor(_role),
                    icon: Icons.extension_outlined,
                    onToggle: (key, value) {
                      setState(() {
                        _customAccessDraft ??=
                            _cloneAccess(kDefaultRoleAccess[_role]!);
                        _customAccessDraft?['features']?[key] = value;
                      });
                    },
                  );

                  if (!isWide) {
                    return Column(
                      children: [
                        panel(pageSection),
                        const SizedBox(height: 10),
                        panel(featureSection),
                      ],
                    );
                  }

                  return Table(
                    columnWidths: const {
                      0: FlexColumnWidth(),
                      1: FlexColumnWidth(),
                    },
                    defaultVerticalAlignment:
                        TableCellVerticalAlignment.top,
                    children: [
                      TableRow(
                        children: [
                          panel(pageSection),
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: panel(featureSection),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: HoverButton(
                enabled: !_loading && widget.canCreate,
                child: ElevatedButton.icon(
                  onPressed:
                      _loading || !widget.canCreate ? null : _createUser,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(_loading
                      ? 'Menyimpan...'
                      : widget.canCreate
                          ? 'Buat Akun'
                          : 'Akses dibatasi'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessSection({
    required String title,
    required Map<String, String> labels,
    required Map<String, bool> values,
    required bool editable,
    required void Function(String key, bool value) onToggle,
    Color? accentColor,
    IconData? icon,
    bool useGrid = true,
    Color? badgeColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onSurface;
    final chipColor = accentColor ?? colorScheme.primary;
    final chipBorder = colorScheme.outline.withValues(alpha: 0.85);
    final badgeAccent = badgeColor ?? chipColor;
    final selectedCount =
        values.values.where((value) => value == true).length;
    final totalCount = labels.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 28,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Row(
                children: [
                  if (icon != null)
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: chipColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 16,
                        color: chipColor,
                      ),
                    ),
                  if (icon != null) const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: badgeAccent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '$selectedCount/$totalCount aktif',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (useGrid)
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              final hasBoundedWidth =
                  constraints.hasBoundedWidth && constraints.maxWidth.isFinite;
              final availableWidth =
                  hasBoundedWidth ? constraints.maxWidth : 0.0;
              final twoColumns = hasBoundedWidth && availableWidth >= 360;
              final chipWidth =
                  twoColumns ? (availableWidth - spacing) / 2 : null;
              return Wrap(
                spacing: spacing,
                runSpacing: 8,
                children: labels.entries.map((entry) {
                  final key = entry.key;
                  final selected = values[key] == true;
                  return SizedBox(
                    width: chipWidth,
                    child: FilterChip(
                      label: Text(entry.value),
                      selected: selected,
                      onSelected: editable
                          ? (value) => onToggle(key, value)
                          : null,
                      showCheckmark: true,
                      backgroundColor: Colors.white,
                      selectedColor: chipColor.withValues(alpha: 0.95),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : textColor,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: selected
                            ? chipColor.withValues(alpha: 0.95)
                            : chipBorder,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      shape: const StadiumBorder(),
                    ),
                  );
                }).toList(),
              );
            },
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: labels.entries.map((entry) {
              final key = entry.key;
              final selected = values[key] == true;
              return FilterChip(
                label: Text(entry.value),
                selected: selected,
                onSelected:
                    editable ? (value) => onToggle(key, value) : null,
                showCheckmark: true,
                backgroundColor: Colors.white,
                selectedColor: chipColor.withValues(alpha: 0.95),
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : textColor,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: selected
                      ? chipColor.withValues(alpha: 0.95)
                      : chipBorder,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                shape: const StadiumBorder(),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildRoleGuide(BuildContext context) {
    return HoverCard(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ringkasan Role',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _roleHint(
              context,
              role: 'admin',
              desc: 'Akses penuh semua menu dan kelola pengguna.',
            ),
            const SizedBox(height: 10),
            _roleHint(
              context,
              role: 'owner',
              desc: 'Dashboard, laporan, dan stok (lihat saja).',
            ),
            const SizedBox(height: 10),
            _roleHint(
              context,
              role: 'operator',
              desc: 'Transaksi dan stok (tambah & hapus).',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserListCard(
    BuildContext context,
    List<Map<String, dynamic>> users,
    int total,
    Map<String, Map<String, Map<String, bool>>> roleConfig, {
    double height = 320,
  }) {
    return HoverCard(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Akun Terdaftar',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$total akun',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: height,
              child: users.isEmpty
                  ? const Center(child: Text('Belum ada user'))
                  : ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final email = (user['email'] ?? '-').toString();
                        final emailKey = email.toLowerCase();
                        final nickname =
                            (user['nama_panggilan'] ?? '').toString();
                        final role =
                            (user['role'] ?? 'operator').toString();
                        final isVirtual = user['virtual'] == true;
                        final isDisabled = user['disabled'] == true;
                        final rawOverride = user['access_override'];
                        final accessOverride = rawOverride is Map
                            ? Map<String, dynamic>.from(rawOverride)
                            : null;
                        final uid = (user['id'] ?? '').toString();
                        final effectiveId = uid.isNotEmpty ? uid : emailKey;
                        return Row(
                          children: [
                            _avatar(email, _roleColor(role)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    email,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Role akses: ${_roleLabel(role)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  if (isDisabled)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Akun nonaktif',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ),
                                  if (isVirtual)
                                    const SizedBox.shrink(),
                                ],
                              ),
                            ),
                            _roleBadge(context, role),
                            if (isDisabled) ...[
                              const SizedBox(width: 6),
                              _statusBadge(context, 'Nonaktif'),
                            ],
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                                tooltip: 'Aksi',
                                onSelected: (value) {
                                  if (value == 'role') {
                                    if (effectiveId.isEmpty) return;
                                    if (!widget.canEdit) return;
                                    _changeRole(
                                      uid: effectiveId,
                                      email: emailKey,
                                      currentRole: role,
                                    );
                                  } else if (value == 'email') {
                                    if (effectiveId.isEmpty) return;
                                    if (!widget.canEdit) return;
                                    _changeEmail(
                                      uid: effectiveId,
                                      currentEmail: email,
                                      users: users,
                                    );
                                  } else if (value == 'nickname') {
                                    if (effectiveId.isEmpty) return;
                                    if (!widget.canEdit) return;
                                    _changeNickname(
                                      uid: effectiveId,
                                      currentNickname: nickname,
                                    );
                                  } else if (value == 'toggle') {
                                    if (effectiveId.isEmpty) return;
                                    if (!widget.canEdit) return;
                                    _toggleUserDisabled(
                                      uid: effectiveId,
                                      email: emailKey,
                                      disabled: isDisabled,
                                      role: role,
                                      isVirtual: isVirtual,
                                    );
                                  } else if (value == 'access') {
                                    if (effectiveId.isEmpty) return;
                                    if (!widget.canEdit) return;
                                    _editUserAccess(
                                      uid: effectiveId,
                                      role: role.toLowerCase(),
                                      overrideRaw: accessOverride,
                                      roleConfig: roleConfig,
                                    );
                                  } else if (value == 'delete') {
                                    if (effectiveId.isEmpty) return;
                                    if (!widget.canDelete) return;
                                    _deleteUserDoc(
                                      uid: effectiveId,
                                      email: email,
                                    );
                                  } else if (value == 'reset') {
                                    if (!widget.canEdit) return;
                                    _resetPasswordViaAdmin(
                                      email: email,
                                      role: role.toLowerCase(),
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (widget.canEdit)
                                    const PopupMenuItem(
                                      value: 'role',
                                      child: Text('Ubah Role'),
                                    ),
                                  if (widget.canEdit)
                                    const PopupMenuItem(
                                      value: 'email',
                                      child: Text('Ubah Email'),
                                    ),
                                  if (widget.canEdit)
                                    const PopupMenuItem(
                                      value: 'nickname',
                                      child: Text('Ubah Nama Panggilan'),
                                    ),
                                  if (widget.canEdit)
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(
                                        isDisabled
                                            ? 'Aktifkan Akun'
                                            : 'Nonaktifkan Akun',
                                      ),
                                    ),
                                  if (widget.canEdit)
                                    const PopupMenuItem(
                                      value: 'access',
                                      child: Text('Akses Khusus'),
                                    ),
                                  if (widget.canDelete)
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Hapus Akun'),
                                    ),
                                  if (widget.canEdit)
                                    const PopupMenuItem(
                                      value: 'reset',
                                      child: Text('Reset Password'),
                                    ),
                                ],
                                child: const Icon(
                                  Icons.more_vert,
                                  size: 20,
                                ),
                              ),
                            ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleHint(
    BuildContext context, {
    required String role,
    required String desc,
  }) {
    final color = _roleColor(role);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.shield_outlined, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _roleLabel(role),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard(BuildContext context, String label, int value, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _avatar(String email, Color color) {
    final letter =
        email.isNotEmpty ? email.trim().toUpperCase().characters.first : '?';
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _roleBadge(BuildContext context, String role) {
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        _roleLabel(role),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context, String label) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'owner':
        return const Color(0xFFEF4444);
      case 'admin':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF22C55E);
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Admin';
      default:
        return 'Operator';
    }
  }
}

List<BoxShadow> _luxShadow(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return [
    BoxShadow(
      color: isDark ? const Color(0x44000000) : const Color(0x1A000000),
      blurRadius: 18,
      offset: const Offset(0, 10),
    ),
  ];
}
