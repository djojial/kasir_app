import 'package:flutter/widgets.dart';

class WebBarcodeScanner extends StatelessWidget {
  final ValueChanged<String> onDetect;
  final ValueChanged<String>? onError;

  const WebBarcodeScanner({
    super.key,
    required this.onDetect,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
