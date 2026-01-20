import 'dart:async';

import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

bool _feedbackShowing = false;

Future<void> showCenteredFeedback({
  required String message,
  required bool success,
  Duration duration = const Duration(milliseconds: 1200),
}) async {
  final context = rootScaffoldMessengerKey.currentContext;
  if (context == null) return;

  if (_feedbackShowing) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  _feedbackShowing = true;

  final bgColor = success ? const Color(0xFF1F6A3C) : const Color(0xFFB42318);

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              constraints: const BoxConstraints(minWidth: 160),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Timer(duration, () {
    if (!context.mounted) return;
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    _feedbackShowing = false;
  });
}
