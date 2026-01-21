import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/ui/app_feedback.dart';
import '../../core/ui/interactive_widgets.dart';
import '../../database/services/firestore_service.dart';
import '../../firebase_options.dart';

class HalamanUser extends StatefulWidget {
  const HalamanUser({super.key});

  @override
  State<HalamanUser> createState() => _HalamanUserState();
}

class _HalamanUserState extends State<HalamanUser> {
  final _firestore = FirestoreService();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  String _role = 'operator';
  bool _loading = false;
  Future<FirebaseApp>? _secondaryAppFuture;

  static const _roles = ['admin', 'owner', 'operator'];
  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  Future<FirebaseApp> _initSecondary() async {
    return Firebase.initializeApp(
      name: 'userCreation',
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  Future<void> _createUser() async {
    if (_loading) return;
    final email = _emailC.text.trim();
    final password = _passC.text;
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
      );
      await auth.signOut();
      if (!mounted) return;
      _emailC.clear();
      _passC.clear();
      setState(() {
        _role = 'operator';
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

  String _functionsBaseUrl() {
    final projectId = Firebase.app().options.projectId;
    return 'https://us-central1-$projectId.cloudfunctions.net';
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

    if (role == 'admin') {
      await _resetPassword(target);
      return;
    }

    final controller = TextEditingController();
    final confirmController = TextEditingController();
    final newPassword = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Buat password baru untuk $target',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(dialogContext)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password baru',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Konfirmasi password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              controller.text.trim(),
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    final confirmText = confirmController.text.trim();
    controller.dispose();
    confirmController.dispose();
    if (newPassword == null) return;

    if (newPassword.length < 6) {
      AppFeedback.show(
        context,
        message: 'Password minimal 6 karakter',
        type: AppFeedbackType.error,
      );
      return;
    }
    if (newPassword != confirmText) {
      AppFeedback.show(
        context,
        message: 'Konfirmasi password tidak sama',
        type: AppFeedbackType.error,
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppFeedback.show(
        context,
        message: 'Sesi login tidak ditemukan',
        type: AppFeedbackType.error,
      );
      return;
    }

    AppFeedback.showLoading(context, message: 'Menyimpan password...');
    try {
      final token = await user.getIdToken();
      final url = Uri.parse('${_functionsBaseUrl()}/setUserPassword');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': target,
          'password': newPassword,
        }),
      );
      if (response.statusCode != 200) {
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;
        final message = body is Map && body['error'] is String
            ? body['error'] as String
            : 'Gagal reset password';
        AppFeedback.show(
          context,
          message: message,
          type: AppFeedbackType.error,
        );
        return;
      }
      AppFeedback.show(
        context,
        message: 'Password berhasil direset',
        type: AppFeedbackType.success,
      );
    } catch (e) {
      AppFeedback.show(
        context,
        message: 'Gagal reset password',
        type: AppFeedbackType.error,
      );
    } finally {
      AppFeedback.hideLoading();
    }
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
    if (!mounted) return;
    AppFeedback.show(
      context,
      message: 'Username diperbarui',
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
    if (!mounted) return;
    AppFeedback.show(
      context,
      message: 'Role diperbarui menjadi ${_roleLabel(selectedRole)}',
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
                          child: const Icon(Icons.manage_accounts_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kelola Pengguna',
                                style: Theme.of(context).textTheme.titleMedium,
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
                        _statCard(context, 'Admin', adminCount,
                            _roleColor('admin')),
                        _statCard(context, 'Owner', ownerCount,
                            _roleColor('owner')),
                        _statCard(context, 'Operator', operatorCount,
                            _roleColor('operator')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (isNarrow)
                Column(
                  children: [
                    _buildFormCard(context),
                    const SizedBox(height: 12),
                    _buildRoleGuide(context),
                    const SizedBox(height: 12),
                    _buildUserListCard(context, users, total, height: 320),
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
                          _buildFormCard(context),
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
  }

  Widget _buildFormCard(BuildContext context) {
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
            if (isWide)
              Row(
                children: [
                  Expanded(
                    child: FocusTextField(
                      controller: _emailC,
                      keyboardType: TextInputType.emailAddress,
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
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              FocusTextField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              FocusTextField(
                controller: _passC,
                obscureText: true,
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
            const SizedBox(height: 8),
            Wrap(
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
                    color: selected ? color : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: _loading
                      ? null
                      : (_) => setState(() => _role = role),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: HoverButton(
                enabled: !_loading,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _createUser,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(_loading ? 'Menyimpan...' : 'Buat Akun'),
                ),
              ),
            ),
          ],
        ),
      ),
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
    int total, {
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
                        final role =
                            (user['role'] ?? 'operator').toString();
                        final isVirtual = user['virtual'] == true;
                        final isDisabled = user['disabled'] == true;
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
                                    _changeRole(
                                      uid: effectiveId,
                                      email: emailKey,
                                      currentRole: role,
                                    );
                                  } else if (value == 'email') {
                                    if (effectiveId.isEmpty) return;
                                    _changeEmail(
                                      uid: effectiveId,
                                      currentEmail: email,
                                      users: users,
                                    );
                                  } else if (value == 'toggle') {
                                    if (effectiveId.isEmpty) return;
                                    _toggleUserDisabled(
                                      uid: effectiveId,
                                      email: emailKey,
                                      disabled: isDisabled,
                                      role: role,
                                      isVirtual: isVirtual,
                                    );
                                  } else if (value == 'delete') {
                                    if (effectiveId.isEmpty) return;
                                    _deleteUserDoc(
                                      uid: effectiveId,
                                      email: email,
                                    );
                                  } else if (value == 'reset') {
                                    _resetPasswordViaAdmin(
                                      email: email,
                                      role: role.toLowerCase(),
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'role',
                                    child: Text('Ubah Role'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'email',
                                    child: Text('Ubah Username'),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Text(
                                      isDisabled
                                          ? 'Aktifkan Akun'
                                          : 'Nonaktifkan Akun',
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Hapus Akun'),
                                  ),
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
