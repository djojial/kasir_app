import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../database/models/produk_model.dart';
import '../../database/services/firestore_service.dart';
class HalamanScanBarcode extends StatefulWidget {
  final VoidCallback? onBackToDashboard;

  const HalamanScanBarcode({super.key, this.onBackToDashboard});

  @override
  State<HalamanScanBarcode> createState() => _HalamanScanBarcodeState();
}

class _HalamanScanBarcodeState extends State<HalamanScanBarcode> {
  final MobileScannerController controller = MobileScannerController();
  final TextEditingController inputManual = TextEditingController();
  final FirestoreService firestore = FirestoreService();

  String? hasilScan;
  Produk? produk;
  bool modeKamera = true;

  bool get canUseCamera {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    if (modeKamera && canUseCamera) {
      controller.start();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    inputManual.dispose();
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Container(
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
                          label: const Text('Dashboard'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ModeButton(
                            active: modeKamera,
                            icon: Icons.camera_alt_outlined,
                            label: 'Scan kamera',
                            onTap: () {
                              setState(() => modeKamera = true);
                              if (canUseCamera) {
                                controller.start();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ModeButton(
                            active: !modeKamera,
                            icon: Icons.keyboard_outlined,
                            label: 'Input manual',
                            onTap: () {
                              setState(() => modeKamera = false);
                              if (canUseCamera) {
                                controller.stop();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: modeKamera && canUseCamera
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
                                child: MobileScanner(
                                  controller: controller,
                                  errorBuilder: (context, error, child) {
                                    return _CameraErrorPanel(
                                      error: error,
                                      onRetry: () {
                                        controller.start();
                                        setState(() {});
                                      },
                                      onManual: () {
                                        setState(() => modeKamera = false);
                                        controller.stop();
                                      },
                                    );
                                  },
                                  onDetect: (capture) {
                                    final barcode = capture.barcodes.first;
                                    final value = barcode.rawValue;

                                    if (value != null) {
                                      controller.stop();
                                      _prosesBarcode(value);
                                    }
                                  },
                                ),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF1F1F1F)
                                    : const Color(0xFFF1EFEB),
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: Theme.of(context).dividerColor),
                              ),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: inputManual,
                                    decoration: InputDecoration(
                                      labelText: 'Kode barcode',
                                      suffixIcon: Icon(
                                        Icons.qr_code_scanner,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      filled: true,
                                      fillColor:
                                          Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFF1C1C1C)
                                              : const Color(0xFFF1EFEB),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: Theme.of(context).dividerColor),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    onSubmitted: (v) {
                                      if (v.isNotEmpty) {
                                        _prosesBarcode(v);
                                        inputManual.clear();
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        if (inputManual.text.isNotEmpty) {
                                          _prosesBarcode(inputManual.text);
                                          inputManual.clear();
                                        }
                                      },
                                      child: const Text('Scan'),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Gunakan input manual untuk desktop/web.',
                                    style: TextStyle(color: Color(0xFF7C776D)),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: _HasilScanCard(produk: produk, hasilScan: hasilScan),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ModeButton({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.12)
                : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1F1F1F)
                    : const Color(0xFFF1EFEB)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: active
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
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

class _CameraErrorPanel extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onManual;

  const _CameraErrorPanel({
    required this.error,
    required this.onRetry,
    required this.onManual,
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
