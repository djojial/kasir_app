import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool _hoverEnabled() {
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

class HoverCard extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double hoverScale;
  final double pressedScale;
  final Duration duration;
  final Curve curve;
  final Color shadowColor;
  final double shadowBlur;
  final double shadowBlurHover;
  final Offset shadowOffset;
  final VoidCallback? onTap;

  const HoverCard({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.hoverScale = 1.06,
    this.pressedScale = 0.97,
    this.duration = const Duration(milliseconds: 280),
    this.curve = Curves.easeOutExpo,
    this.shadowColor = const Color(0x22000000),
    this.shadowBlur = 16,
    this.shadowBlurHover = 32,
    this.shadowOffset = const Offset(0, 10),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return child;
    }
    return GestureDetector(
      onTap: onTap,
      child: child,
    );
  }
}

class HoverButton extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double hoverScale;
  final double pressedScale;
  final Duration duration;
  final Curve curve;
  final Color shadowColor;
  final double shadowBlur;
  final double shadowBlurHover;
  final Offset shadowOffset;

  const HoverButton({
    super.key,
    required this.child,
    this.enabled = true,
    this.hoverScale = 1.06,
    this.pressedScale = 0.97,
    this.duration = const Duration(milliseconds: 280),
    this.curve = Curves.easeOutExpo,
    this.shadowColor = const Color(0x22000000),
    this.shadowBlur = 10,
    this.shadowBlurHover = 26,
    this.shadowOffset = const Offset(0, 8),
  });

  @override
  State<HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<HoverButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enableHover = _hoverEnabled() && widget.enabled;
    final scale = _pressed
        ? widget.pressedScale
        : (_hovered && enableHover ? widget.hoverScale : 1.0);
    final blur = _hovered && enableHover ? widget.shadowBlurHover : widget.shadowBlur;
    final child = AnimatedScale(
      duration: widget.duration,
      curve: widget.curve,
      scale: scale,
      child: AnimatedContainer(
        duration: widget.duration,
        curve: widget.curve,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: widget.enabled
              ? [
                  BoxShadow(
                    color: widget.shadowColor,
                    blurRadius: blur,
                    offset: widget.shadowOffset,
                  ),
                ]
              : const [],
        ),
        child: widget.child,
      ),
    );

    return MouseRegion(
      onEnter: (_) {
        if (!enableHover) return;
        setState(() => _hovered = true);
      },
      onExit: (_) {
        if (!enableHover) return;
        setState(() => _hovered = false);
      },
      child: Listener(
        onPointerDown: (_) {
          if (!widget.enabled) return;
          setState(() => _pressed = true);
        },
        onPointerUp: (_) {
          if (!widget.enabled) return;
          setState(() => _pressed = false);
        },
        onPointerCancel: (_) {
          if (!widget.enabled) return;
          setState(() => _pressed = false);
        },
        child: child,
      ),
    );
  }
}

class FocusTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool readOnly;
  final bool? enabled;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final TextStyle? style;
  final Color? cursorColor;
  final TextAlign textAlign;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final VoidCallback? onTap;

  const FocusTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.style,
    this.cursorColor,
    this.textAlign = TextAlign.start,
    this.inputFormatters,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTap,
  });

  @override
  State<FocusTextField> createState() => _FocusTextFieldState();
}

class _FocusTextFieldState extends State<FocusTextField> {
  late final FocusNode _focusNode;
  bool _ownsFocus = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _focusNode = FocusNode();
      _ownsFocus = true;
    } else {
      _focusNode = widget.focusNode!;
    }
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocus) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.decoration?.errorText != null &&
        widget.decoration!.errorText!.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    final shadowColor = hasError
        ? const Color(0xFFEF4444)
        : scheme.primary;
    final showGlow = _focusNode.hasFocus || hasError;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutExpo,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: shadowColor.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        obscureText: widget.obscureText,
        readOnly: widget.readOnly,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        style: widget.style,
        cursorColor: widget.cursorColor,
        textAlign: widget.textAlign,
        inputFormatters: widget.inputFormatters,
        maxLength: widget.maxLength,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        onEditingComplete: widget.onEditingComplete,
        onTap: widget.onTap,
        decoration: widget.decoration,
      ),
    );
  }
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const ThousandsSeparatorInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = _formatThousands(digitsOnly);
    final selection = _mapCursorPosition(
      rawText: newValue.text,
      formattedText: formatted,
      cursorIndex: newValue.selection.baseOffset,
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selection),
    );
  }

  String _formatThousands(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final indexFromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }

  int _mapCursorPosition({
    required String rawText,
    required String formattedText,
    required int cursorIndex,
  }) {
    var digitsBeforeCursor = 0;
    final safeCursor = cursorIndex.clamp(0, rawText.length);
    for (var i = 0; i < safeCursor; i++) {
      if (_isDigit(rawText.codeUnitAt(i))) {
        digitsBeforeCursor++;
      }
    }

    if (digitsBeforeCursor == 0) {
      return 0;
    }

    var digitsSeen = 0;
    for (var i = 0; i < formattedText.length; i++) {
      if (_isDigit(formattedText.codeUnitAt(i))) {
        digitsSeen++;
      }
      if (digitsSeen == digitsBeforeCursor) {
        return i + 1;
      }
    }
    return formattedText.length;
  }

  bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;
}
