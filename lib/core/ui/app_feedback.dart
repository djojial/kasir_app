import 'dart:async';

import 'package:flutter/material.dart';

enum AppFeedbackType {
  success,
  error,
  info,
}

class AppFeedback {
  static OverlayEntry? _toastEntry;
  static OverlayEntry? _loadingEntry;
  static String? _pendingMessage;
  static AppFeedbackType _pendingType = AppFeedbackType.info;
  static Duration _pendingDuration = const Duration(seconds: 3);

  static void queue({
    required String message,
    AppFeedbackType type = AppFeedbackType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _pendingMessage = message;
    _pendingType = type;
    _pendingDuration = duration;
  }

  static void flushQueued(BuildContext context) {
    final message = _pendingMessage;
    if (message == null) return;
    final type = _pendingType;
    final duration = _pendingDuration;
    _pendingMessage = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      show(
        context,
        message: message,
        type: type,
        duration: duration,
      );
    });
  }

  static void show(
    BuildContext context, {
    required String message,
    AppFeedbackType type = AppFeedbackType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (_toastEntry?.mounted ?? false) {
      _toastEntry?.remove();
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    final colors = _colorsFor(type);
    final entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(colors.icon, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
    _toastEntry = entry;
    Timer(duration, () {
      if (entry.mounted) {
        entry.remove();
      }
      if (_toastEntry == entry) {
        _toastEntry = null;
      }
    });
  }

  static void showLoading(
    BuildContext context, {
    String message = 'Memproses...',
  }) {
    hideLoading();
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: Material(
            color: Colors.black.withValues(alpha: 0.35),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
    _loadingEntry = entry;
  }

  static void hideLoading() {
    if (_loadingEntry?.mounted ?? false) {
      _loadingEntry?.remove();
    }
    _loadingEntry = null;
  }

  static _FeedbackColors _colorsFor(AppFeedbackType type) {
    switch (type) {
      case AppFeedbackType.success:
        return _FeedbackColors(
          background: const Color(0xFF16A34A).withValues(alpha: 0.92),
          icon: Icons.check_circle_rounded,
        );
      case AppFeedbackType.error:
        return _FeedbackColors(
          background: const Color(0xFFEF4444).withValues(alpha: 0.92),
          icon: Icons.error_rounded,
        );
      case AppFeedbackType.info:
        return _FeedbackColors(
          background: const Color(0xFF2563EB).withValues(alpha: 0.92),
          icon: Icons.info_rounded,
        );
    }
  }
}

class _FeedbackColors {
  final Color background;
  final IconData icon;

  const _FeedbackColors({
    required this.background,
    required this.icon,
  });
}
