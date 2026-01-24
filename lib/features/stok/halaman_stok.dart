import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

import '../../core/ui/app_feedback.dart';
import '../../core/ui/interactive_widgets.dart';
import '../../core/widgets/web_barcode_scanner.dart';
import '../../database/models/produk_model.dart';
import '../../database/services/firestore_service.dart';

class HalamanStok extends StatefulWidget {
  final bool canAdd;
  final bool canEdit;
  final bool canDelete;

  const HalamanStok({
    super.key,
    this.canAdd = true,
    this.canEdit = true,
    this.canDelete = true,
  });

  @override
  State<HalamanStok> createState() => _HalamanStokState();
}

class _HalamanStokState extends State<HalamanStok> {
  final FirestoreService firestore = FirestoreService();
  final TextEditingController _cariC = TextEditingController();
  String _kataKunci = '';
  bool get _showActions => widget.canEdit || widget.canDelete;

  Future<void> _formProduk(Produk? produk) async {
    String formatAngka(int value) {
      final str = value.abs().toString();
      final buffer = StringBuffer();
      for (var i = 0; i < str.length; i++) {
        final pos = str.length - i;
        buffer.write(str[i]);
        if (pos > 1 && pos % 3 == 1) buffer.write('.');
      }
      return buffer.toString();
    }

    int parseAngka(String value) =>
        int.tryParse(value.replaceAll('.', '')) ?? 0;

    final namaC = TextEditingController(text: produk?.nama ?? '');
    final barcodeC = TextEditingController(text: produk?.barcode ?? '');
    final kategoriC = TextEditingController(text: produk?.kategori ?? '');
    final hargaC = TextEditingController(
      text: produk == null ? '' : formatAngka(produk.harga),
    );
    final hargaModalC = TextEditingController(
      text: produk == null ? '' : formatAngka(produk.hargaModal),
    );
    final diskonMinQtyC = TextEditingController(
      text: produk == null || produk.diskonMinQty == 0
          ? ''
          : produk.diskonMinQty.toString(),
    );
    final diskonHargaC = TextEditingController(
      text: produk == null || produk.diskonHarga == 0
          ? ''
          : formatAngka(produk.diskonHarga),
    );
    final diskonPersenC = TextEditingController(
      text: produk == null || produk.diskonPersen == 0
          ? ''
          : produk.diskonPersen.toString(),
    );
    final labaPersenC = TextEditingController();
    final stokAwalC = TextEditingController();
    final stokC = TextEditingController(text: produk?.stok.toString() ?? '');
    String? gambarBase64 = produk?.gambarBase64;
    var _syncing = false;
    var _syncingGrosir = false;
    final maxImageBytes = 700 * 1024;

    final kategoriList = await firestore.ambilSemuaProduk().first;
    if (!mounted) return;
    final kategoriSet = <String>{};
    for (final item in kategoriList) {
      final value = item.kategori.trim();
      if (value.isNotEmpty) {
        kategoriSet.add(value);
      }
    }
    final kategoriOpsi = kategoriSet.toList()..sort();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          int modalValue = parseAngka(hargaModalC.text);
          int jualValue = parseAngka(hargaC.text);
          final percent = modalValue <= 0
              ? null
              : (((jualValue - modalValue) / modalValue) * 100).round();
          if (!_syncing && percent != null) {
            labaPersenC.text = percent.toString();
          }
          final minQtyValue = int.tryParse(diskonMinQtyC.text) ?? 0;
          final diskonHargaValue = parseAngka(diskonHargaC.text);
          final diskonPersenValue = int.tryParse(diskonPersenC.text) ?? 0;
          final safeDiskonPersen = diskonPersenValue.clamp(0, 100);
          int? hargaGrosirPerItem;
          if (diskonHargaValue > 0) {
            hargaGrosirPerItem = diskonHargaValue;
          } else if (safeDiskonPersen > 0 && jualValue > 0) {
            hargaGrosirPerItem =
                (jualValue * (100 - safeDiskonPersen) / 100).round();
          }
          final int? totalGrosir = minQtyValue > 0
              ? (hargaGrosirPerItem ?? jualValue) * minQtyValue
              : null;
          Future<void> pilihGambar(ImageSource source) async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(
              source: source,
              maxWidth: 1024,
              maxHeight: 1024,
              imageQuality: 70,
            );
            if (picked == null) return;
            final bytes = await picked.readAsBytes();
            if (bytes.lengthInBytes > maxImageBytes) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ukuran foto terlalu besar untuk disimpan.'),
                ),
              );
              return;
            }
            setModalState(() {
              gambarBase64 = base64Encode(bytes);
            });
          }

          Future<void> pilihGambarSheet() async {
            await showModalBottomSheet<void>(
              context: context,
              builder: (sheetContext) {
                return SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.photo_camera),
                        title: const Text('Ambil foto'),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await pilihGambar(ImageSource.camera);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library),
                        title: const Text('Pilih dari galeri'),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await pilihGambar(ImageSource.gallery);
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          }

          Future<void> scanBarcode() async {
            bool handled = false;
            final isWindowsDesktop =
                !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
            final canUseCamera = kIsWeb ||
                defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS;
            if (!canUseCamera && !isWindowsDesktop) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Scan kamera hanya tersedia di Android/iOS/Web. Gunakan input manual.',
                  ),
                ),
              );
              return;
            }

            String? result;
            try {
              if (isWindowsDesktop) {
                result = await SimpleBarcodeScanner.scanBarcode(context);
                if (result == null || result.isEmpty || result == '-1') {
                  return;
                }
                if (!context.mounted) return;
                setModalState(() {
                  barcodeC.text = result!;
                });
                return;
              }
              result = await showDialog<String>(
                context: context,
                builder: (dialogContext) {
                  String? webError;
                  bool webStarted = false;
                  int restartToken = 0;
                  return AlertDialog(
                    title: const Text('Scan Barcode'),
                    content: SizedBox(
                      width: 420,
                      height: 320,
                      child: StatefulBuilder(
                        builder: (context, setDialogState) {
                          if (kIsWeb) {
                            if (webError != null) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.videocam_off, size: 40),
                                      const SizedBox(height: 8),
                                      const Text('Kamera tidak bisa diakses'),
                                      const SizedBox(height: 4),
                                      Text(
                                        webError!,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setDialogState(() {
                                            webError = null;
                                            webStarted = false;
                                            restartToken++;
                                          });
                                        },
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Coba lagi'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            if (!webStarted) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.videocam, size: 40),
                                    const SizedBox(height: 8),
                                    const Text('Mulai kamera untuk scan barcode'),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setDialogState(() {
                                          webStarted = true;
                                          restartToken++;
                                        });
                                      },
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Mulai kamera'),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return WebBarcodeScanner(
                              key: ValueKey(restartToken),
                              onDetect: (code) {
                                if (handled) return;
                                handled = true;
                                Navigator.of(dialogContext).pop(code);
                              },
                              onError: (message) {
                                setDialogState(() {
                                  webError = message;
                                  webStarted = false;
                                });
                              },
                            );
                          }

                          return MobileScanner(
                            errorBuilder: (context, error, child) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.videocam_off, size: 40),
                                      const SizedBox(height: 8),
                                      const Text('Kamera tidak bisa diakses'),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Untuk web, gunakan https atau localhost.',
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        icon: const Icon(Icons.close),
                                        label: const Text('Tutup'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            onDetect: (capture) {
                              if (handled) return;
                              final barcodes = capture.barcodes;
                              if (barcodes.isEmpty) return;
                              final code = barcodes.first.rawValue;
                              if (code == null) return;
                              handled = true;
                              Navigator.of(dialogContext).pop(code);
                            },
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            } finally {
            }
            final scanned = result;
            if (scanned == null) return;
            setModalState(() {
              barcodeC.text = scanned;
            });
          }

          final screenWidth = MediaQuery.of(context).size.width;
          final dialogWidth = screenWidth - 48.0;
          final contentWidth = dialogWidth > 760.0 ? 760.0 : dialogWidth;

          final detailSection = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FormSection(
                title: 'Detail Produk',
                icon: Icons.inventory_2_outlined,
                child: Column(
                  children: [
                    FocusTextField(
                      controller: namaC,
                      decoration: const InputDecoration(
                        labelText: "Nama Produk",
                        prefixIcon: Icon(Icons.sell_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FocusTextField(
                      controller: barcodeC,
                      decoration: InputDecoration(
                        labelText: "Barcode",
                        prefixIcon: const Icon(Icons.qr_code_2_outlined),
                        suffixIcon: IconButton(
                          onPressed: scanBarcode,
                          icon: const Icon(Icons.qr_code_scanner),
                          tooltip: 'Scan barcode',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FocusTextField(
                      controller: kategoriC,
                      decoration: InputDecoration(
                        labelText: "Kategori",
                        prefixIcon: const Icon(Icons.category_outlined),
                        suffixIcon: kategoriOpsi.isEmpty
                            ? null
                            : PopupMenuButton<String>(
                                tooltip: 'Pilih kategori',
                                icon: const Icon(Icons.arrow_drop_down),
                                onSelected: (value) {
                                  setModalState(() {
                                    kategoriC.text = value;
                                  });
                                },
                                itemBuilder: (context) {
                                  return kategoriOpsi
                                      .map(
                                        (value) => PopupMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        ),
                                      )
                                      .toList();
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _FormSection(
                title: 'Harga & Laba',
                icon: Icons.price_change_outlined,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FocusTextField(
                            controller: hargaModalC,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              const ThousandsSeparatorInputFormatter(),
                            ],
                            decoration: const InputDecoration(
                              labelText: "Harga Modal",
                              prefixText: 'Rp ',
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FocusTextField(
                            controller: labaPersenC,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Laba (%)",
                              suffixText: '%',
                            ),
                            onChanged: (value) {
                              if (_syncing) return;
                              _syncing = true;
                              final modal =
                                  parseAngka(hargaModalC.text);
                              final persen = double.tryParse(value) ?? 0;
                              if (modal > 0) {
                                final jual =
                                    (modal * (1 + persen / 100)).round();
                                hargaC.text = formatAngka(jual);
                              }
                              _syncing = false;
                              setModalState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FocusTextField(
                      controller: hargaC,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        const ThousandsSeparatorInputFormatter(),
                      ],
                      decoration: const InputDecoration(
                        labelText: "Harga Jual",
                        prefixText: 'Rp ',
                      ),
                      onChanged: (value) {
                        if (_syncing) return;
                        _syncing = true;
                        final modal = parseAngka(hargaModalC.text);
                        final jual = parseAngka(value);
                        if (modal > 0) {
                          final persen =
                              (((jual - modal) / modal) * 100).round();
                          labaPersenC.text = persen.toString();
                        }
                        _syncing = false;
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.trending_up, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          percent == null ? '-' : '$percent%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'estimasi laba',
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
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _FormSection(
                title: 'Harga Grosir',
                icon: Icons.local_offer_outlined,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FocusTextField(
                            controller: diskonMinQtyC,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: "Minimal beli (qty)",
                              prefixIcon: Icon(Icons.confirmation_number_outlined),
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FocusTextField(
                            controller: diskonPersenC,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: "Diskon (%)",
                              suffixText: '%',
                            ),
                            onChanged: (value) {
                              if (_syncingGrosir) return;
                              _syncingGrosir = true;
                              final jual = parseAngka(hargaC.text);
                              final persen =
                                  (int.tryParse(value) ?? 0).clamp(0, 100);
                              if (jual > 0) {
                                final diskonHarga =
                                    (jual * (100 - persen) / 100).round();
                                diskonHargaC.text = formatAngka(diskonHarga);
                              }
                              _syncingGrosir = false;
                              setModalState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FocusTextField(
                      controller: diskonHargaC,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        const ThousandsSeparatorInputFormatter(),
                      ],
                      decoration: const InputDecoration(
                        labelText: "Harga jual diskon",
                        prefixText: 'Rp ',
                      ),
                      onChanged: (value) {
                        if (_syncingGrosir) return;
                        _syncingGrosir = true;
                        final jual = parseAngka(hargaC.text);
                        final hargaDiskon = parseAngka(value);
                        if (jual > 0 && hargaDiskon > 0) {
                          final persen =
                              ((1 - (hargaDiskon / jual)) * 100).round();
                          diskonPersenC.text =
                              persen.clamp(0, 100).toString();
                        }
                        _syncingGrosir = false;
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            minQtyValue <= 0
                                ? 'Isi minimal beli untuk melihat perkiraan.'
                                : (hargaGrosirPerItem == null
                                    ? 'Belum ada harga grosir, estimasi $minQtyValue pcs: Rp ${formatAngka(totalGrosir ?? 0)}'
                                    : 'Perkiraan $minQtyValue pcs: Rp ${formatAngka(totalGrosir ?? 0)}'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _FormSection(
                title: 'Stok',
                icon: Icons.inventory_outlined,
                child: produk == null
                    ? FocusTextField(
                        controller: stokAwalC,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Stok Awal",
                          prefixIcon: Icon(Icons.layers_outlined),
                        ),
                      )
                    : FocusTextField(
                        controller: stokC,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Stok",
                          prefixIcon: Icon(Icons.layers_outlined),
                        ),
                      ),
              ),
            ],
          );

          final imageSection = Column(
            children: [
              InkWell(
                onTap: pilihGambarSheet,
                borderRadius: BorderRadius.circular(16),
                child: HoverCard(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFF1EFEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor),
                    boxShadow: _luxShadow(context),
                  ),
                  child: gambarBase64 == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_a_photo_outlined, size: 48),
                            SizedBox(height: 8),
                            Text(
                              'Upload foto',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            base64Decode(gambarBase64!),
                            fit: BoxFit.cover,
                          ),
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Klik untuk ganti',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ],
          );

          return AlertDialog(
            title: Text(produk == null ? "Produk Baru" : "Edit Produk"),
            content: SizedBox(
              width: contentWidth,
              height: MediaQuery.of(context).size.height * 0.72,
              child: SingleChildScrollView(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 720;
                    if (isNarrow) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          detailSection,
                          const SizedBox(height: 16),
                          Center(child: imageSection),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: detailSection),
                        const SizedBox(width: 20),
                        imageSection,
                      ],
                    );
                  },
                ),
              ),
            ),
            actions: [
              HoverButton(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal"),
                ),
              ),
              HoverButton(
                child: ElevatedButton(
                  onPressed: () async {
                    final missing = <String>[];
                    final namaText = namaC.text.trim();
                    final hargaModalText = hargaModalC.text.trim();
                    final hargaText = hargaC.text.trim();
                    if (namaText.isEmpty) {
                      missing.add('Nama Produk');
                    }
                    if (hargaModalText.isEmpty) {
                      missing.add('Harga Modal');
                    }
                    if (hargaText.isEmpty) {
                      missing.add('Harga Jual');
                    }
                    if (hargaModalText.isNotEmpty &&
                        hargaText.isNotEmpty &&
                        labaPersenC.text.trim().isEmpty) {
                      final modal = parseAngka(hargaModalText);
                      final jual = parseAngka(hargaText);
                      if (modal > 0) {
                        labaPersenC.text =
                            (((jual - modal) / modal) * 100).round().toString();
                      }
                    }
                    if (labaPersenC.text.trim().isEmpty) {
                      missing.add('Laba (%)');
                    }
                    final stokText =
                        produk == null ? stokAwalC.text : stokC.text;
                    if (stokText.trim().isEmpty) {
                      missing.add(produk == null ? 'Stok Awal' : 'Stok');
                    }
                    if (missing.isNotEmpty) {
                      if (!context.mounted) return;
                      AppFeedback.show(
                        context,
                        message: 'Mohon isi: ${missing.join(', ')}',
                        type: AppFeedbackType.info,
                      );
                      return;
                    }
                    final harga = parseAngka(hargaC.text);
                    final hargaModal = parseAngka(hargaModalC.text);
                    try {
                      if (produk == null) {
                        final stokAwal = int.tryParse(stokAwalC.text) ?? 0;
                        final diskonMinQty =
                            int.tryParse(diskonMinQtyC.text) ?? 0;
                        final diskonPersen = (int.tryParse(diskonPersenC.text) ??
                                0)
                            .clamp(0, 100);
                        final diskonHarga = parseAngka(diskonHargaC.text);

                        final p = Produk(
                          nama: namaC.text,
                          barcode: barcodeC.text,
                          kategori: kategoriC.text.trim().isEmpty
                              ? 'Lainnya'
                              : kategoriC.text.trim(),
                          harga: harga,
                          hargaModal: hargaModal,
                          diskonMinQty: diskonMinQty,
                          diskonHarga: diskonHarga,
                          diskonPersen: diskonPersen,
                          gambarBase64: gambarBase64,
                          stok: stokAwal,
                          dibuatPada: Timestamp.now(),
                        );

                        await firestore.tambahProdukDenganLog(p, stokAwal);
                      } else {
                        final diskonMinQty =
                            int.tryParse(diskonMinQtyC.text) ?? 0;
                        final diskonPersen = (int.tryParse(diskonPersenC.text) ??
                                0)
                            .clamp(0, 100);
                        final diskonHarga = parseAngka(diskonHargaC.text);
                        final p = Produk(
                          id: produk.id,
                          nama: namaC.text,
                          barcode: barcodeC.text,
                          kategori: kategoriC.text.trim().isEmpty
                              ? 'Lainnya'
                              : kategoriC.text.trim(),
                          harga: harga,
                          hargaModal: hargaModal,
                          diskonMinQty: diskonMinQty,
                          diskonHarga: diskonHarga,
                          diskonPersen: diskonPersen,
                          gambarBase64: gambarBase64,
                          stok: int.tryParse(stokC.text) ?? 0,
                          dibuatPada: produk.dibuatPada,
                        );

                        await firestore.updateProduk(p);
                      }
                    } on FirebaseException catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Gagal simpan: ${e.code}'),
                        ),
                      );
                      return;
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Gagal simpan data produk.'),
                        ),
                      );
                      return;
                    }

                    if (!mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text("Simpan"),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _hapusProduk(Produk produk) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus produk?'),
          content: Text(
            'Produk "${produk.nama}" akan dihapus beserta stoknya. Lanjutkan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await firestore.hapusProduk(produk.id!);
  }
  @override
  void dispose() {
    _cariC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        return Padding(
          padding: EdgeInsets.all(isNarrow ? 16 : 24),
          child: Column(
            children: [
              HoverCard(
                child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                  boxShadow: _luxShadow(context),
                ),
                child: isNarrow
                    ? Column(
                        children: [
                          FocusTextField(
                            controller: _cariC,
                            onChanged: (value) {
                              setState(() =>
                                  _kataKunci = value.trim().toLowerCase());
                            },
                            decoration: InputDecoration(
                              hintText: 'Cari nama / barcode',
                              prefixIcon: Icon(
                                Icons.search,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              filled: true,
                              fillColor:
                                  Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF1F1F1F)
                                      : const Color(0xFFF1EFEB),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: Theme.of(context).dividerColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              suffixIcon: _kataKunci == ''
                                  ? null
                                  : IconButton(
                                      icon: Icon(
                                        Icons.close,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                      onPressed: () {
                                        _cariC.clear();
                                        setState(() => _kataKunci = '');
                                      },
                                    ),
                            ),
                          ),
                          if (widget.canAdd) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: HoverButton(
                                child: ElevatedButton.icon(
                                  onPressed: () => _formProduk(null),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    foregroundColor:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.black
                                            : Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 16,
                                    ),
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Tambah Produk'),
                                ),
                              ),
                            ),
                          ],
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: FocusTextField(
                              controller: _cariC,
                              onChanged: (value) {
                                setState(() => _kataKunci =
                                    value.trim().toLowerCase());
                              },
                              decoration: InputDecoration(
                                hintText: 'Cari nama / barcode',
                                prefixIcon: Icon(
                                  Icons.search,
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                ),
                                filled: true,
                                fillColor: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF1F1F1F)
                                    : const Color(0xFFF1EFEB),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                      color: Theme.of(context).dividerColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                suffixIcon: _kataKunci == ''
                                    ? null
                                    : IconButton(
                                        icon: Icon(
                                          Icons.close,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                        onPressed: () {
                                          _cariC.clear();
                                          setState(() => _kataKunci = '');
                                        },
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          if (widget.canAdd)
                            HoverButton(
                              child: ElevatedButton.icon(
                                onPressed: () => _formProduk(null),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.black
                                          : Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 16,
                                  ),
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('Tambah Produk'),
                              ),
                            ),
                        ],
                      ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _TabelStok(
                  firestore: firestore,
                  kataKunci: _kataKunci,
                  onEdit: widget.canEdit ? _formProduk : null,
                  onHapus: widget.canDelete ? _hapusProduk : null,
                  showActions: _showActions,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabelStok extends StatelessWidget {
  final FirestoreService firestore;
  final String kataKunci;
  final void Function(Produk)? onEdit;
  final void Function(Produk)? onHapus;
  final bool showActions;

  const _TabelStok({
    required this.firestore,
    required this.kataKunci,
    required this.onEdit,
    required this.onHapus,
    required this.showActions,
  });

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: _luxShadow(context),
        ),
        child: StreamBuilder<List<Produk>>(
          stream: firestore.ambilSemuaProduk(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

          final data = snap.data!;

          final keyword = kataKunci.trim().toLowerCase();
          final filtered = keyword.isEmpty
              ? data
              : data.where((p) {
                  final nama = p.nama.toLowerCase();
                  final barcode = p.barcode.toLowerCase();
                  return nama.contains(keyword) || barcode.contains(keyword);
                }).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('Produk tidak ditemukan'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final divider = Theme.of(context).dividerColor;
              final minTableWidth = showActions ? 1280.0 : 1120.0;
              final tableWidth = math.max(constraints.maxWidth, minTableWidth);
              final dragDevices = {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              };
              return Scrollbar(
                child: SingleChildScrollView(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: dragDevices,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: DataTable(
                          headingTextStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          dataTextStyle: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                          headingRowHeight: 54,
                          dataRowMinHeight: 60,
                          dataRowMaxHeight: 70,
                          columnSpacing: 24,
                          dividerThickness: 0.8,
                          showCheckboxColumn: false,
                          border: TableBorder.all(color: divider, width: 0.6),
                          headingRowColor: WidgetStatePropertyAll(
                            Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF1F1F1F)
                                : const Color(0xFFF1EFEB),
                          ),
                          columns: [
                            const DataColumn(label: Text('Nama Produk')),
                            const DataColumn(label: Text('Kategori')),
                            const DataColumn(label: Text('Barcode')),
                            const DataColumn(label: Text('Harga Modal')),
                            const DataColumn(label: Text('Harga Jual')),
                            const DataColumn(label: Text('Harga Grosir')),
                            const DataColumn(label: Text('Diskon Grosir %')),
                            const DataColumn(label: Text('Laba %')),
                            const DataColumn(label: Text('Stok')),
                            const DataColumn(label: Text('Status')),
                            if (showActions)
                              const DataColumn(label: Text('Aksi')),
                          ],
                          rows: filtered.map((p) {
                            final stok = p.stok;
                            final status = stok < 5
                                ? 'Darurat'
                                : stok < 10
                                    ? 'Menipis'
                                    : 'Normal';
                            final statusColor = stok < 5
                                ? const Color(0xFFEF4444)
                                : stok < 10
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF22C55E);
                            final labaPercent = p.hargaModal <= 0
                                ? '-'
                                : '${(((p.harga - p.hargaModal) / p.hargaModal) * 100).round()}%';
                            final grosirPersen = p.diskonPersen.clamp(0, 100);
                            final grosirHarga = p.diskonHarga > 0
                                ? p.diskonHarga
                                : (grosirPersen > 0
                                    ? (p.harga * (100 - grosirPersen) / 100).round()
                                    : 0);
                            final grosirHargaLabel =
                                grosirHarga > 0 ? 'Rp ${_formatAngka(grosirHarga)}' : '-';
                            final grosirPersenLabel =
                                grosirPersen > 0 ? '$grosirPersen%' : '-';

                          final cells = <DataCell>[
                            DataCell(
                              Text(
                                p.nama,
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                p.kategori.isEmpty ? 'Lainnya' : p.kategori,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                p.barcode,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            DataCell(Text('Rp ${_formatAngka(p.hargaModal)}')),
                            DataCell(Text('Rp ${_formatAngka(p.harga)}')),
                            DataCell(Text(grosirHargaLabel)),
                            DataCell(Text(grosirPersenLabel)),
                              DataCell(Text(labaPercent)),
                              DataCell(Text(stok.toString())),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ];
                            if (showActions) {
                              cells.add(
                                DataCell(
                                  Row(
                                    children: [
                                      if (onEdit != null)
                                        IconButton(
                                          tooltip: 'Edit',
                                          icon: Icon(
                                            Icons.edit_outlined,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                          iconSize: 22,
                                          onPressed: () => onEdit!(p),
                                        ),
                                      if (onHapus != null)
                                        IconButton(
                                          tooltip: 'Hapus',
                                          icon: const Icon(Icons.delete_outline,
                                              color: Color(0xFFB42318)),
                                          iconSize: 22,
                                          onPressed: () => onHapus!(p),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return DataRow(cells: cells);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
          },
        ),
      ),
    );
  }
}

String _formatAngka(int value) {
  final str = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    final pos = str.length - i;
    buffer.write(str[i]);
    if (pos > 1 && pos % 3 == 1) buffer.write('.');
  }
  return buffer.toString();
}

class _FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _FormSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return HoverCard(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E1E)
              : const Color(0xFFF8F6F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
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


