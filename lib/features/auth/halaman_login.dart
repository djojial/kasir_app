import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ui/app_feedback.dart';
import '../../core/ui/interactive_widgets.dart';
import '../../core/theme_controller.dart';
class HalamanLogin extends StatefulWidget {
  const HalamanLogin({super.key});

  static String? pendingMessage;
  static bool pendingSuccess = false;

  static void showMessageOnNextLogin(
    String message, {
    bool success = false,
  }) {
    if (pendingMessage == message && pendingSuccess == success) {
      return;
    }
    pendingMessage = message;
    pendingSuccess = success;
  }

  @override
  State<HalamanLogin> createState() => _HalamanLoginState();
}

class _HalamanLoginState extends State<HalamanLogin> {
  static const _prefRemember = 'login_remember';
  static const _prefEmail = 'login_email';
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _loading = false;
  bool _rememberMe = false;
  String? _error;
  String? _statusMessage;
  bool _statusSuccess = false;
  bool _obscurePassword = true;
  bool _showPendingToast = false;
  bool _pendingToastSuccess = false;
  bool _pendingToastScheduled = false;
  String? _pendingToastMessage;
  bool _successToastScheduled = false;

  @override
  void initState() {
    super.initState();
    _consumePendingMessage();
    _loadRememberedUser();
  }

  Future<void> _loadRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_prefRemember) ?? false;
    final email = prefs.getString(_prefEmail) ?? '';
    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
      if (remember && email.isNotEmpty) {
        _emailC.text = email;
      }
    });
  }

  Future<void> _setRememberMe(bool value) async {
    setState(() => _rememberMe = value);
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      await prefs.setBool(_prefRemember, true);
      await prefs.setString(_prefEmail, _emailC.text.trim());
    } else {
      await prefs.remove(_prefRemember);
      await prefs.remove(_prefEmail);
    }
  }

  Future<void> _forgotPassword() async {
    final rootContext = context;
    if (!mounted) return;
    final safeEmail = _emailC.text.trim().toLowerCase();
    if (safeEmail.isEmpty) {
      AppFeedback.show(
        rootContext,
        message: 'Email belum diisi.',
        type: AppFeedbackType.error,
      );
      return;
    }
    try {
      AppFeedback.showLoading(rootContext, message: 'Memeriksa akun...');
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: safeEmail)
          .limit(1)
          .get();
      final data = snap.docs.isEmpty ? null : snap.docs.first.data();
      final role =
          (data?['role'] ?? '').toString().trim().toLowerCase();
      AppFeedback.hideLoading();

      if (role != 'admin') {
        if (role.isEmpty) {
          AppFeedback.show(
            rootContext,
            message: 'Email belum terdaftar.',
            type: AppFeedbackType.error,
          );
        } else {
          AppFeedback.show(
            rootContext,
            message: 'Hubungi Admin.',
            type: AppFeedbackType.info,
          );
        }
        return;
      }

      AppFeedback.showLoading(rootContext, message: 'Mengirim reset password...');
      await FirebaseAuth.instance.sendPasswordResetEmail(email: safeEmail);
      if (!mounted) return;
      AppFeedback.show(
        rootContext,
        message: 'Link reset password sudah dikirim.',
        type: AppFeedbackType.success,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      AppFeedback.show(
        rootContext,
        message: e.message ?? 'Gagal mengirim reset password.',
        type: AppFeedbackType.error,
      );
    } on FirebaseException catch (_) {
      if (!mounted) return;
      AppFeedback.show(
        rootContext,
        message: 'Gagal memeriksa akun.',
        type: AppFeedbackType.error,
      );
    } finally {
      AppFeedback.hideLoading();
    }
  }

  void _consumePendingMessage() {
    final pending = HalamanLogin.pendingMessage;
    if (pending == null) return;
    _statusMessage = pending;
    _statusSuccess = HalamanLogin.pendingSuccess;
    _error = _statusSuccess ? null : pending;
    HalamanLogin.pendingMessage = null;
    HalamanLogin.pendingSuccess = false;
    _pendingToastMessage = pending;
    _pendingToastSuccess = _statusSuccess;
    _showPendingToast = true;
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailC.text.trim();
    final password = _passC.text;
    if (email.isEmpty) {
      AppFeedback.show(
        context,
        message: 'Mohon isi Email Anda.',
        type: AppFeedbackType.error,
      );
      return;
    }
    if (password.isEmpty) {
      AppFeedback.show(
        context,
        message: 'Mohon isi Password Anda.',
        type: AppFeedbackType.error,
      );
      return;
    }

    final safeEmail = email.toLowerCase();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: safeEmail)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        AppFeedback.show(
          context,
          message: 'Akun Tidak Terdaftar.',
          type: AppFeedbackType.error,
        );
        return;
      }
    } on FirebaseException catch (_) {
      // If lookup fails, fall back to auth to avoid blocking login.
    }

    setState(() {
      _loading = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (mounted) {
        setState(() {
          _statusSuccess = true;
          _statusMessage = 'Login berhasil';
        });
        if (_rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_prefRemember, true);
          await prefs.setString(_prefEmail, _emailC.text.trim());
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_prefRemember);
          await prefs.remove(_prefEmail);
        }
        if (!_successToastScheduled) {
          _successToastScheduled = true;
          AppFeedback.queue(
            message: 'Login berhasil',
            type: AppFeedbackType.success,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _error = 'Akun Tidak Terdaftar.';
            break;
          case 'wrong-password':
            _error = 'Password salah.';
            break;
          case 'invalid-credential':
          case 'invalid-login-credentials':
            _error = 'Password salah.';
            break;
          case 'invalid-email':
            _error = 'Format email tidak valid.';
            break;
          case 'too-many-requests':
            _error = 'Permintaan dari perangkat ini diblokir sementara. Coba lagi nanti.';
            break;
          case 'user-disabled':
            _error = 'Akun dinonaktifkan.';
            break;
          default:
            _error = e.message ?? 'Login gagal.';
        }
        _statusSuccess = false;
        _statusMessage = _error;
      });
      if (mounted && _statusMessage != null) {
        AppFeedback.show(
          context,
          message: _statusMessage!,
          type: AppFeedbackType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showPendingToast && !_pendingToastScheduled) {
      _pendingToastScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_showPendingToast) return;
        AppFeedback.show(
          context,
          message: _pendingToastMessage ?? '',
          type: _pendingToastSuccess
              ? AppFeedbackType.success
              : AppFeedbackType.error,
          duration: const Duration(seconds: 2),
        );
        if (!mounted) return;
        setState(() {
          _showPendingToast = false;
          _pendingToastScheduled = false;
          _pendingToastMessage = null;
        });
      });
    }
    if (HalamanLogin.pendingMessage != null &&
        HalamanLogin.pendingMessage != _statusMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(_consumePendingMessage);
      });
    }
    final scheme = Theme.of(context).colorScheme;
    final divider = Theme.of(context).dividerColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0xFF0E0E0E),
                        Color(0xFF151515),
                        Color(0xFF0B0B0B),
                      ]
                    : const [
                        Color(0xFFF7F6F3),
                        Color(0xFFF0EEE9),
                        Color(0xFFFFFFFF),
                      ],
              ),
            ),
          ),
          Positioned(
            top: -80,
            left: -60,
            child: _GlowBlob(
              size: 220,
              color: const Color(0xFFF28C28),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -40,
            child: _GlowBlob(
              size: 260,
              color: const Color(0xFFF7C27A),
            ),
          ),
          Positioned(
            top: 18,
            right: 18,
            child: IconButton(
              onPressed: () => ThemeController.toggle(context),
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              color: scheme.primary,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: HoverCard(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(
                        alpha: isDark ? 0.92 : 0.98,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: divider),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 24,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'image/nira_posbaru.png',
                            width: 180,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: _loading ? 6 : 0,
                          curve: Curves.easeOut,
                          decoration: BoxDecoration(
                            color: _loading
                                ? scheme.primary.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: _loading
                              ? LinearProgressIndicator(
                                  backgroundColor: Colors.transparent,
                                  color: scheme.primary,
                                )
                              : null,
                        ),
                        if (_loading) const SizedBox(height: 10),
                        Text(
                          'Selamat Datang',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Masuk untuk mulai transaksi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 20),
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
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: _loading
                                  ? null
                                  : (value) => _setRememberMe(value ?? false),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: _loading
                                    ? null
                                    : () => _setRememberMe(!_rememberMe),
                                child: const Text(
                                  'Ingat saya',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _loading ? null : _forgotPassword,
                              child: const Text('Lupa password?'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const SizedBox(height: 18),
                        HoverButton(
                          enabled: !_loading,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Masuk'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Gunakan akun yang terverifikasi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF7C776D),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.25),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 80,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}
