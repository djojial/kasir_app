import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

import '../../core/widgets/web_barcode_scanner.dart';
import '../../database/models/produk_model.dart';
import '../../database/services/firestore_service.dart';
class HalamanScanBarcode extends StatefulWidget {
  final VoidCallback? onBackToDashboard;

  const HalamanScanBarcode({super.key, this.onBackToDashboard});

  @override
  State<HalamanScanBarcode> createState() => _HalamanScanBarcodeState();
}

class _HalamanScanBarcodeState extends State<HalamanScanBarcode> {
  final FirestoreService firestore = FirestoreService();
  bool _isProcessing = false;
  String? _webError;
  bool _webStarted = false;
  int _restartToken = 0;

  String? hasilScan;
  Produk? produk;

  bool get canUseCamera {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get isWindowsDesktop =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _prosesBarcode(String kode) async {
    final hasil = await firestore.getProdukByBarcode(kode);

    if (!mounted) return;
    setState(() {
      hasilScan = kode;
      produk = hasil;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasil != null
              ? "Produk ditemukan: ${hasil.nama}"
              : "Produk belum terdaftar",
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: hasil != null ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 860;
          final scanPanel = Container(
            padding: const EdgeInsets.all(20),
            decoration: _panelDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Scan Produk',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    TextButton.icon(
                      onPressed: widget.onBackToDashboard ??
                          () {
                            Navigator.of(context).maybePop();
                          },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Kembali'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: isWindowsDesktop
                      ? _WebStartPrompt(
                          onStart: () async {
                            final result =
                                await SimpleBarcodeScanner.scanBarcode(context);
                            if (result == null ||
                                result.isEmpty ||
                                result == '-1') {
                              return;
                            }
                            if (_isProcessing) return;
                            _isProcessing = true;
                            _prosesBarcode(result);
                          },
                        )
                      : canUseCamera
                      ? Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF1F1F1F)
                                : const Color(0xFFF1EFEB),
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: kIsWeb
                                ? (_webError != null
                                    ? _CameraErrorPanel(
                                        error: _webError!,
                                        onRetry: () {
                                          setState(() {
                                            _webError = null;
                                            _webStarted = false;
                                            _restartToken++;
                                          });
                                        },
                                      )
                                    : (!_webStarted
                                        ? _WebStartPrompt(
                                            onStart: () {
                                              setState(() {
                                                _webStarted = true;
                                                _restartToken++;
                                              });
                                            },
                                          )
                                        : WebBarcodeScanner(
                                            key: ValueKey(_restartToken),
                                            onDetect: (value) {
                                              if (_isProcessing) return;
                                              _isProcessing = true;
                                              _prosesBarcode(value);
                                            },
                                            onError: (message) {
                                              if (!mounted) return;
                                              setState(() {
                                                _webError = message;
                                                _webStarted = false;
                                              });
                                            },
                                          )))
                                : MobileScanner(
                                    errorBuilder: (context, error, child) {
                                      return _CameraErrorPanel(
                                        error: error,
                                        onRetry: () {
                                          setState(() {});
                                        },
                                      );
                                    },
                                    onDetect: (capture) {
                                      if (_isProcessing) return;
                                      final barcode = capture.barcodes.first;
                                      final value = barcode.rawValue;

                                      if (value != null) {
                                        _isProcessing = true;
                                        _prosesBarcode(value);
                                      }
                                    },
                                  ),
                          ),
                        )
                      : _CameraErrorPanel(
                          error: 'Kamera tidak didukung di platform ini.',
                          onRetry: () {
                            setState(() {});
                          },
                        ),
                ),
              ],
            ),
          );
          final hasilCard =
              _HasilScanCard(produk: produk, hasilScan: hasilScan);

          return Padding(
            padding: const EdgeInsets.all(24),
            child: isNarrow
                ? Column(
                    children: [
                      Flexible(flex: 3, child: scanPanel),
                      const SizedBox(height: 20),
                      Flexible(flex: 2, child: hasilCard),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(flex: 3, child: scanPanel),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: hasilCard),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _HasilScanCard extends StatelessWidget {
  final Produk? produk;
  final String? hasilScan;

  const _HasilScanCard({required this.produk, required this.hasilScan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(context),
      child: produk == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_2_outlined, size: 48),
                const SizedBox(height: 12),
                const Text('Belum ada hasil scan'),
                if (hasilScan != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Barcode: $hasilScan',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hasil Scan', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text(
                  produk!.nama,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Harga: Rp ${produk!.harga}',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stok: ${produk!.stok}',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: const [
                    Chip(label: Text('Offline')),
                    Chip(label: Text('Tokopedia')),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Tambah ke keranjang (POS)'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _WebStartPrompt extends StatelessWidget {
  final VoidCallback onStart;

  const _WebStartPrompt({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam, size: 48),
          const SizedBox(height: 12),
          const Text('Mulai kamera untuk scan barcode'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Mulai kamera'),
          ),
        ],
      ),
    );
  }
}

class _CameraErrorPanel extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final VoidCallback? onManual;

  const _CameraErrorPanel({
    required this.error,
    required this.onRetry,
    this.onManual,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1F1F1F)
            : const Color(0xFFF1EFEB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, size: 48),
          const SizedBox(height: 12),
          Text(
            'Kamera tidak bisa diakses',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Izinkan akses kamera. Untuk web, gunakan https atau localhost.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (error is String) ...[
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
              if (onManual != null)
                ElevatedButton.icon(
                  onPressed: onManual,
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Input manual'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

BoxDecoration _panelDecoration(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final divider = Theme.of(context).dividerColor;
  return BoxDecoration(
    color: scheme.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: divider),
    boxShadow: _luxShadow(context),
  );
}

List<BoxShadow> _luxShadow(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return [
    BoxShadow(
      color: isDark ? const Color(0x66000000) : const Color(0x22000000),
      blurRadius: 18,
      offset: const Offset(0, 10),
    ),
  ];
}
