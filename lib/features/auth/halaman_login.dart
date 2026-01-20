import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
  final _emailC = TextEditingController(text: 'muhammaddjojial@gmail.com');
  final _passC = TextEditingController(text: 'hebatkali'); //wahyujaya ac
  bool _loading = false;
  String? _error;
  String? _statusMessage;
  bool _statusSuccess = false;
  bool _showPendingToast = false;
  bool _pendingToastSuccess = false;
  bool _pendingToastScheduled = false;
  String? _pendingToastMessage;
  bool _successToastScheduled = false;

  @override
  void initState() {
    super.initState();
    _consumePendingMessage();
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
    setState(() {
      _loading = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailC.text.trim(),
        password: _passC.text,
      );
      if (mounted) {
        setState(() {
          _statusSuccess = true;
          _statusMessage = 'Login berhasil';
        });
        if (!_successToastScheduled) {
          _successToastScheduled = true;
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            _successToastScheduled = false;
            if (HalamanLogin.pendingMessage != null) return;
            if (_showPendingToast) return;
            if (FirebaseAuth.instance.currentUser == null) return;
            AppFeedback.show(
              context,
              message: 'Login berhasil',
              type: AppFeedbackType.success,
            );
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _error = 'Akun belum terdaftar.';
            break;
          case 'wrong-password':
            _error = 'Password salah.';
            break;
          case 'invalid-email':
            _error = 'Format email tidak valid.';
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
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _statusMessage == null
                              ? const SizedBox.shrink()
                              : Container(
                                  key: ValueKey(_statusMessage),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _statusSuccess
                                        ? const Color(0xFF16A34A)
                                            .withValues(alpha: 0.12)
                                        : const Color(0xFFEF4444)
                                            .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _statusSuccess
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFEF4444),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _statusSuccess
                                            ? Icons.check_circle_rounded
                                            : Icons.error_rounded,
                                        color: _statusSuccess
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFFEF4444),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _statusMessage!,
                                          style: TextStyle(
                                            color: _statusSuccess
                                                ? const Color(0xFF16A34A)
                                                : const Color(0xFFEF4444),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
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
