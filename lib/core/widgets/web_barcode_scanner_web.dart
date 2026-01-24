import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui;

import 'package:flutter/widgets.dart';

class WebBarcodeScanner extends StatefulWidget {
  final ValueChanged<String> onDetect;
  final ValueChanged<String>? onError;

  const WebBarcodeScanner({
    super.key,
    required this.onDetect,
    this.onError,
  });

  @override
  State<WebBarcodeScanner> createState() => _WebBarcodeScannerState();
}

class _WebBarcodeScannerState extends State<WebBarcodeScanner> {
  late final String _viewType;
  late final String _containerId;
  int? _handleId;

  @override
  void initState() {
    super.initState();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    _viewType = 'web-barcode-scanner-$stamp';
    _containerId = 'web-barcode-scanner-container-$stamp';
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final container = html.DivElement()
        ..id = _containerId
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#000'
        ..style.borderRadius = '16px'
        ..style.overflow = 'hidden';
      return container;
    });
    _startWhenReady();
  }

  Future<void> _startWhenReady() async {
    for (var i = 0; i < 30; i++) {
      if (js_util.hasProperty(html.window, 'startWebScanner')) {
        _startScanner();
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    widget.onError?.call('Scanner web belum siap.');
  }

  void _startScanner() {
    if (!js_util.hasProperty(html.window, 'startWebScanner')) {
      widget.onError?.call('Scanner web tidak tersedia.');
      return;
    }
    final onScan = js.allowInterop((String code) {
      widget.onDetect(code);
    });
    final onError = js.allowInterop((String message) {
      widget.onError?.call(message);
    });
    final handle = js_util.callMethod(
      html.window,
      'startWebScanner',
      [_containerId, onScan, onError],
    );
    if (handle is int) {
      _handleId = handle;
    }
  }

  @override
  void dispose() {
    if (_handleId != null &&
        js_util.hasProperty(html.window, 'stopWebScanner')) {
      js_util.callMethod(html.window, 'stopWebScanner', [_handleId]);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
