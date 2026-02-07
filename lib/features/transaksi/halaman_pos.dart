import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:file_selector/file_selector.dart' as fs;

import '../../core/ui/app_feedback.dart';
import '../../core/ui/interactive_widgets.dart';
import '../../database/models/produk_model.dart';
import '../../database/models/transaksi_model.dart';
import '../../database/services/firestore_service.dart';
import '../../utils/pdf_download.dart';
import '../../utils/pdf_save.dart';
import 'halaman_scan.dart';

class HalamanPOS extends StatefulWidget {
  const HalamanPOS({super.key});

  @override
  State<HalamanPOS> createState() => _HalamanPOSState();
}

class _HalamanPOSState extends State<HalamanPOS> {
  final FirestoreService firestore = FirestoreService();
  final TextEditingController _cariProdukC = TextEditingController();
  final List<TransaksiItem> keranjang = [];
  String _kataKunciProduk = '';
  String _kategoriAktif = 'Semua';
  bool _cartSheetOpen = false;
  Timer? _emptyReloadTimer;
  bool _showEmptyReload = false;
  Map<String, String>? _actorCache;
  Future<void> _openScanDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        final maxWidth =
            media.size.width < 900 ? media.size.width - 32 : 960.0;
        final maxHeight = media.size.height - 32;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: HalamanScanBarcode(
              onBackToDashboard: () => Navigator.of(context).maybePop(),
              onAddToCart: (produk) =>
                  tambahKeKeranjang(produk, openCartSheet: false),
            ),
          ),
        );
      },
    );
  }

  // =========================
  // TAMBAH KE KERANJANG
  // =========================
  void tambahKeKeranjang(Produk produk, {bool openCartSheet = true}) {
    if (produk.stok <= 0) {
      _snack("Barang tidak tersedia", Colors.red);
      return;
    }

    final index = keranjang.indexWhere((e) => e.produk.id == produk.id);

    setState(() {
      if (index == -1) {
        final item = Transaksi.buatItem(
          produk: produk,
          qty: 1,
        );
        keranjang.add(item);
      } else {
        if (keranjang[index].qty < produk.stok) {
          keranjang[index].qty++;
        } else {
          _snack("Stok tidak mencukupi", Colors.orange);
        }
      }
    });

    if (openCartSheet && MediaQuery.of(context).size.width < 720) {
      _openCartSheet();
    }
  }

  void tambahQty(TransaksiItem item) {
    if (item.qty < item.produk.stok) {
      setState(() {
        item.qty++;
      });
    } else {
      _snack("Stok tidak mencukupi", Colors.orange);
    }
  }

  void kurangiQty(TransaksiItem item) {
    setState(() {
      if (item.qty > 1) {
        item.qty--;
      } else {
        keranjang.remove(item);
      }
    });
  }

  // =========================
  // HITUNG TOTAL
  // =========================
  int _itemHarga(TransaksiItem item) {
    final override = item['hargaOverride'];
    if (override is int && override > 0) {
      return override;
    }
    final produk = item.produk;
    final minQty = produk.diskonMinQty;
    final diskonHarga = produk.diskonHarga;
    if (minQty > 0 && item.qty >= minQty) {
      if (diskonHarga > 0) return diskonHarga;
      final diskonPersen = produk.diskonPersen.clamp(0, 100);
      if (diskonPersen > 0) {
        return (produk.harga * (100 - diskonPersen) / 100).round();
      }
    }
    return produk.harga;
  }

  int _itemDiskon(TransaksiItem item) {
    final diskon = item['diskonPersen'];
    return diskon is int ? diskon : 0;
  }

  int _itemSubtotal(TransaksiItem item) => _itemHarga(item) * item.qty;

  int _itemModal(TransaksiItem item) {
    final modal = item.produk.hargaModal;
    if (modal <= 0) return 0;
    return modal * item.qty;
  }

  int _itemTotal(TransaksiItem item) {
    final subtotal = _itemSubtotal(item);
    final diskon = _itemDiskon(item);
    if (diskon <= 0) return subtotal;
    return (subtotal * (100 - diskon) / 100).round();
  }

  int get subtotalBayar =>
      keranjang.fold(0, (s, e) => s + _itemSubtotal(e));

  int get diskonBayar => keranjang.fold(
        0,
        (s, e) => s + (_itemSubtotal(e) - _itemTotal(e)),
      );

  int get totalBayar => subtotalBayar - diskonBayar;
  int get totalQtyBayar => keranjang.fold(0, (sum, item) => sum + item.qty);

  int get totalModalBayar =>
      keranjang.fold(0, (sum, item) => sum + _itemModal(item));

  int get batasDiskonTambahan {
    final batas = totalBayar - totalModalBayar;
    return batas > 0 ? batas : 0;
  }

  int _subtotalItems(List<TransaksiItem> items) =>
      items.fold(0, (sum, item) => sum + _itemSubtotal(item));

  int _diskonItems(List<TransaksiItem> items) =>
      items.fold(
        0,
        (sum, item) => sum + (_itemSubtotal(item) - _itemTotal(item)),
      );

  // =========================
  // PROSES BAYAR
  // =========================
  Future<String> _resolveNamaKasir() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Kasir';
    try {
      final profile = await firestore
          .streamUserProfile(user.uid, email: user.email)
          .first;
      final nickname = (profile?['nama_panggilan'] ?? '').toString().trim();
      if (nickname.isNotEmpty) return nickname;
    } catch (_) {}
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user.email ?? '';
    if (email.isNotEmpty) return email.split('@').first;
    return 'Kasir';
  }

  Future<Map<String, String>> _resolveActor() async {
    if (_actorCache != null) return _actorCache!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _actorCache = {'name': 'Unknown'};
      return _actorCache!;
    }
    final email = user.email ?? '';
    final name = await _resolveNamaKasir();
    _actorCache = {
      'uid': user.uid,
      'email': email,
      'name': name,
    };
    return _actorCache!;
  }

  Future<void> _commitPembayaran(_PaymentResult payment) async {
    if (keranjang.isEmpty) return;

    try {
      for (final item in keranjang) {
        final produkId = item.produk.id;
        if (produkId == null || produkId.isEmpty) {
          _snack('Produk tidak memiliki ID.', Colors.red);
          return;
        }
        final aman = await firestore.cekStokAman(
          produkId: produkId,
          qty: item.qty,
        );

        if (!aman) {
          _snack(
            "Stok ${item.produk.nama} tidak mencukupi",
            Colors.red,
          );
          return;
        }
      }

      for (final item in keranjang) {
        item['paymentMethod'] = payment.method;
        item['paidAmount'] = payment.paidAmount;
        item['change'] = payment.change;
      }

      final transaksi = Transaksi(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        tanggal: DateTime.now(),
        total: payment.total,
        items: List.from(keranjang),
      );
      final invoiceId = _formatInvoice(transaksi.id);

      await firestore.simpanTransaksi(transaksi);
      final actor = await _resolveActor();
      await firestore.logActivity(
        action: 'transaksi',
        category: 'transaksi',
        targetId: transaksi.id,
        targetLabel: invoiceId,
        meta: {
          'total': payment.total,
          'items': totalQtyBayar,
          'transaksi_id': transaksi.id,
          'invoice': invoiceId,
        },
        actor: actor,
      );

      final baseTotal = totalBayar;
      final ratio = baseTotal > 0 ? payment.total / baseTotal : 1.0;
      for (final item in keranjang) {
        final itemTotal = _itemTotal(item);
        final effectiveTotal = (itemTotal * ratio).round();
        final unitPrice =
            item.qty > 0 ? (effectiveTotal / item.qty).round() : 0;
        await firestore.kurangiStokDanCatatLog(
          produk: item.produk,
          qty: item.qty,
          sumber: "POS",
          refId: transaksi.id,
          hargaJualOverride: unitPrice,
          actor: actor,
        );
      }

      if (!mounted) return;
      setState(() {
        keranjang.clear();
      });

      _showReceipt(transaksi, payment);
      _snack("Transaksi berhasil", Colors.green);
    } catch (e, _) {
      debugPrint('Gagal proses pembayaran: $e');
      if (!mounted) return;
      _snack('Gagal memproses pembayaran.', Colors.red);
    }
  }

  Future<void> _openPaymentSheet() async {
    if (keranjang.isEmpty) {
      _snack('Keranjang masih kosong', Colors.orange);
      return;
    }

    final paidController = TextEditingController(text: '');
    final discountController = TextEditingController(text: '');
    final maxDiskonTambahan = batasDiskonTambahan;
    try {
      final result = await showModalBottomSheet<_PaymentResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          String method = 'Cash';
          int paidAmount = 0;
          int discountAmount = 0;
          int totalAfterDiscount = totalBayar;
          int change = paidAmount - totalAfterDiscount;
          bool editingDiscount = false;

          return StatefulBuilder(
            builder: (context, setModalState) {
              void recalcTotals() {
                final parsedPaid = _parseAngkaText(paidController.text);
                var parsedDiskon = _parseAngkaText(discountController.text);
                if (parsedDiskon > maxDiskonTambahan) {
                  parsedDiskon = maxDiskonTambahan;
                  discountController.text =
                      _formatAngkaText(parsedDiskon.toString());
                }
                final updatedTotal = totalBayar - parsedDiskon;
                setModalState(() {
                  paidAmount = parsedPaid;
                  discountAmount = parsedDiskon;
                  totalAfterDiscount = updatedTotal;
                  change = paidAmount - totalAfterDiscount;
                });
              }

              void applyDigit(String value) {
                final activeController =
                    editingDiscount ? discountController : paidController;
                var text = activeController.text.replaceAll('.', '');
                if (value == 'C') {
                  text = '';
                } else if (value == '<') {
                  if (text.isNotEmpty) {
                    text = text.substring(0, text.length - 1);
                  }
                } else {
                  text = '$text$value';
                }
                activeController.text = _formatAngkaText(text);
                recalcTotals();
              }

              return Padding(
                padding: MediaQuery.of(context).viewInsets,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      margin:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.82,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pembayaran',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            const SizedBox(height: 4),
                            FocusTextField(
                              controller: paidController,
                              readOnly: true,
                              onTap: () => setModalState(() {
                                editingDiscount = false;
                              }),
                              decoration: const InputDecoration(
                                labelText: 'Nominal dibayar',
                                prefixIcon: Icon(Icons.payments_outlined),
                              ),
                            ),
                            const SizedBox(height: 10),
                            FocusTextField(
                              controller: discountController,
                              readOnly: true,
                              onTap: () => setModalState(() {
                                editingDiscount = true;
                              }),
                              decoration: const InputDecoration(
                                labelText: 'Diskon',
                                prefixIcon: Icon(Icons.discount_outlined),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Maks diskon tambahan: ${_formatRupiah(maxDiskonTambahan)}',
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (method == 'Cash') ...[
                              const SizedBox(height: 12),
                              Expanded(
                                child: GridView.count(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 2.4,
                                  children: [
                                    _KeypadButton(
                                      label: '7',
                                      onTap: () => applyDigit('7'),
                                    ),
                                    _KeypadButton(
                                      label: '8',
                                      onTap: () => applyDigit('8'),
                                    ),
                                    _KeypadButton(
                                      label: '9',
                                      onTap: () => applyDigit('9'),
                                    ),
                                    _KeypadButton(
                                      label: '4',
                                      onTap: () => applyDigit('4'),
                                    ),
                                    _KeypadButton(
                                      label: '5',
                                      onTap: () => applyDigit('5'),
                                    ),
                                    _KeypadButton(
                                      label: '6',
                                      onTap: () => applyDigit('6'),
                                    ),
                                    _KeypadButton(
                                      label: '1',
                                      onTap: () => applyDigit('1'),
                                    ),
                                    _KeypadButton(
                                      label: '2',
                                      onTap: () => applyDigit('2'),
                                    ),
                                    _KeypadButton(
                                      label: '3',
                                      onTap: () => applyDigit('3'),
                                    ),
                                    _KeypadButton(
                                      label: 'C',
                                      onTap: () => applyDigit('C'),
                                      filled: true,
                                      fillColor: const Color(0xFFEF4444),
                                    ),
                                    _KeypadButton(
                                      label: '0',
                                      onTap: () => applyDigit('0'),
                                    ),
                                    _KeypadButton(
                                      label: '<',
                                      onTap: () => applyDigit('<'),
                                      filled: true,
                                      fillColor: const Color(0xFFC76A1F),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            _SummaryRow(
                              label: 'Total',
                              value: _formatRupiah(totalAfterDiscount),
                              emphasize: true,
                            ),
                            const SizedBox(height: 6),
                            _SummaryRow(
                              label: 'Diskon',
                              value: _formatRupiah(discountAmount),
                            ),
                            const SizedBox(height: 6),
                            _SummaryRow(
                              label: 'Kembalian',
                              value: _formatRupiah(change < 0 ? 0 : change),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: HoverButton(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Batal'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: HoverButton(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        if (method == 'Cash' &&
                                            paidAmount < totalAfterDiscount) {
                                          _snack('Uang belum cukup', Colors.orange);
                                          return;
                                        }
                                        final finalPaid = method == 'Cash'
                                            ? paidAmount
                                            : (paidAmount == 0
                                                ? totalAfterDiscount
                                                : paidAmount);
                                        Navigator.pop(
                                          context,
                                          _PaymentResult(
                                            method: method,
                                            paidAmount: finalPaid,
                                            change: method == 'Cash'
                                                ? (change < 0 ? 0 : change)
                                                : 0,
                                            discount: discountAmount,
                                            total: totalAfterDiscount,
                                          ),
                                        );
                                      },
                                      child: const Text('Konfirmasi'),
                                    ),
                                  ),
                                ),
                              ],
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
        },
      );

      if (result != null) {
        await _commitPembayaran(result);
      }
    } finally {
      paidController.dispose();
      discountController.dispose();
    }
  }

  Future<void> _showReceipt(Transaksi transaksi, _PaymentResult payment) async {
    final invoiceId = _formatInvoice(transaksi.id);
    final subtotal = _subtotalItems(transaksi.items);
    final diskonItems = _diskonItems(transaksi.items);
    final maxDialogHeight = MediaQuery.of(context).size.height * 0.9;
    final namaKasir = await _resolveNamaKasir();
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) {
        const namaToko = 'ATk Wahyu Jaya';
        final tanggal = DateTime.now();
        final tanggalStr =
            '${tanggal.day.toString().padLeft(2, '0')}/${tanggal.month.toString().padLeft(2, '0')}/${tanggal.year}';
        final jamStr =
            '${tanggal.hour.toString().padLeft(2, '0')}:${tanggal.minute.toString().padLeft(2, '0')}';
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxDialogHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 320,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE3E3E3)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          'image/nira_posbaru.png',
                          width: 140,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          namaToko,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text('Tiket $invoiceId'),
                        Text('$tanggalStr, $jamStr'),
                        Text('Dilayani oleh: $namaKasir'),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...transaksi.items.map((item) {
                                final produk = item.produk;
                                final totalItem = _itemTotal(item);
                                final harga = _itemHarga(item);
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            child: Text(
                                              item.qty.toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              produk.nama,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Text(_formatRupiah(totalItem)),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 20),
                                        child: Text(
                                          '${_formatRupiah(harga)} / Unit',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                              _SummaryRow(
                                label: 'Subtotal',
                                value: _formatRupiah(subtotal),
                              ),
                              const SizedBox(height: 4),
                              if (diskonItems > 0) ...[
                                _SummaryRow(
                                  label: 'Diskon Barang',
                                  value: _formatRupiah(diskonItems),
                                ),
                                const SizedBox(height: 4),
                              ],
                              if (payment.discount > 0) ...[
                                _SummaryRow(
                                  label: 'Diskon Tambahan',
                                  value: _formatRupiah(payment.discount),
                                ),
                                const SizedBox(height: 4),
                              ],
                              _SummaryRow(
                                label: 'Total',
                                value: _formatRupiah(payment.total),
                                emphasize: true,
                              ),
                              const SizedBox(height: 4),
                              _SummaryRow(
                                label: 'Kembalian',
                                value: _formatRupiah(payment.change),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HoverButton(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Tutup'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      HoverButton(
                        child: ElevatedButton.icon(
                          onPressed: () => _showPrintOptions(transaksi, payment),
                          icon: const Icon(Icons.print),
                          label: const Text('Cetak Resi'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPrintOptions(
    Transaksi transaksi,
    _PaymentResult payment,
  ) async {
    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cetak Resi', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('PDF (Email/WhatsApp)'),
                subtitle: const Text('Bagikan file PDF struk'),
                onTap: isWindows
                    ? null
                    : () async {
                  Navigator.pop(context);
                  await _shareReceiptPdf(transaksi, payment);
                },
              ),
              ListTile(
                leading: const Icon(Icons.save_alt_outlined),
                title: const Text('Simpan PDF'),
                subtitle: const Text('Simpan file PDF struk'),
                onTap: () async {
                  if (kIsWeb) {
                    await _saveReceiptPdf(transaksi, payment);
                    if (context.mounted) Navigator.pop(context);
                    return;
                  }
                  Navigator.pop(context);
                  await _saveReceiptPdf(transaksi, payment);
                },
              ),
              ListTile(
                leading: const Icon(Icons.print_disabled_outlined),
                title: const Text('Bluetooth Printer'),
                subtitle: const Text('Cetak ke printer thermal'),
                onTap: isWindows
                    ? null
                    : () async {
                  Navigator.pop(context);
                  await _printBluetooth(transaksi, payment);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<pw.Document> _buildReceiptPdf({
    required Transaksi transaksi,
    required _PaymentResult payment,
    PdfPageFormat? pageFormat,
    bool cardStyle = false,
  }) async {
    const namaToko = 'ATk Wahyu Jaya';
    final namaKasir = await _resolveNamaKasir();
    final subtotal = _subtotalItems(transaksi.items);
    final diskonItems = _diskonItems(transaksi.items);
    final invoiceId = _formatInvoice(transaksi.id);
    final tanggal = transaksi.tanggal;
    final tanggalStr =
        '${tanggal.day.toString().padLeft(2, '0')}/${tanggal.month.toString().padLeft(2, '0')}/${tanggal.year}';
    final jamStr =
        '${tanggal.hour.toString().padLeft(2, '0')}:${tanggal.minute.toString().padLeft(2, '0')}';
    final doc = pw.Document();
    final accent = PdfColor.fromInt(0xFFF28C28);
    pw.MemoryImage? logoImage;
    try {
      final bytes = await rootBundle.load('image/nira_posbaru.png');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}
    List<pw.Widget> buildContent(pw.Context context) {
      final muted = pw.TextStyle(fontSize: 9, color: PdfColors.grey600);
      final titleStyle = pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 15,
        color: accent,
      );
      final storeStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12);
      final totalStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12);
      final logoWidget = logoImage == null
          ? pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Container(
                  width: 18,
                  height: 18,
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(width: 1, color: accent),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'C',
                      style: pw.TextStyle(fontSize: 10, color: accent),
                    ),
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Text('NIRA POS', style: titleStyle),
              ],
            )
          : pw.Center(
              child: pw.Image(logoImage, width: 140),
            );
      final body = <pw.Widget>[
        pw.Center(child: logoWidget),
        pw.SizedBox(height: 8),
        pw.Center(child: pw.Text(namaToko, style: storeStyle)),
        pw.SizedBox(height: 8),
        pw.Center(child: pw.Text('Tiket $invoiceId', style: muted)),
        pw.Center(child: pw.Text('$tanggalStr, $jamStr', style: muted)),
        pw.Center(child: pw.Text('Dilayani oleh: $namaKasir', style: muted)),
        pw.SizedBox(height: 14),
        ...transaksi.items.map((item) {
          final produk = item.produk;
          final totalItem = _itemTotal(item);
          final harga = _itemHarga(item);
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 20,
                      child: pw.Text(
                        item.qty.toString(),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        produk.nama,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Text(_formatRupiah(totalItem)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 20),
                  child: pw.Text(
                    '${_formatRupiah(harga)} / Unit',
                    style: muted,
                  ),
                ),
              ],
            ),
          );
        }),
        pw.SizedBox(height: 8),
        _pdfRow('Subtotal', subtotal),
        if (diskonItems > 0) ...[
          pw.SizedBox(height: 4),
          _pdfRow('Diskon Barang', diskonItems),
        ],
        if (payment.discount > 0) ...[
          pw.SizedBox(height: 4),
          _pdfRow('Diskon Tambahan', payment.discount),
        ],
        pw.SizedBox(height: 4),
        _pdfRow('Total', payment.total, bold: true, style: totalStyle),
        pw.SizedBox(height: 4),
        _pdfRow('Kembalian', payment.change),
      ];
      if (!cardStyle) {
        return body;
      }
      return [
        pw.Center(
          child: pw.Container(
            width: 320,
            padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: body,
            ),
          ),
        ),
      ];
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat ?? PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        build: buildContent,
      ),
    );
    return doc;
  }

  pw.Widget _pdfRow(String label, int value,
      {bool bold = false, pw.TextStyle? style}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: bold
              ? (style ?? pw.TextStyle(fontWeight: pw.FontWeight.bold))
              : (style ?? const pw.TextStyle()),
        ),
        pw.Text(
          _formatRupiah(value),
          style: bold
              ? (style ?? pw.TextStyle(fontWeight: pw.FontWeight.bold))
              : (style ?? const pw.TextStyle()),
        ),
      ],
    );
  }

  Future<void> _saveReceiptPdf(
    Transaksi transaksi,
    _PaymentResult payment,
  ) async {
    if (kIsWeb) {
      try {
        final doc = await _buildReceiptPdf(
          transaksi: transaksi,
          payment: payment,
          pageFormat: PdfPageFormat.a4,
          cardStyle: true,
        );
        final bytes = await doc.save();
        final filename = '${_formatInvoice(transaksi.id)}.pdf';
        await savePdfBytesWeb(bytes, filename);
        if (!mounted) return;
        _snack('PDF berhasil diunduh', Colors.green);
      } catch (e) {
        if (!mounted) return;
        _snack('Gagal simpan PDF: $e', Colors.red);
      }
      return;
    }

    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final isMobile = isAndroid || defaultTargetPlatform == TargetPlatform.iOS;
    try {
      final doc = await _buildReceiptPdf(
        transaksi: transaksi,
        payment: payment,
        pageFormat: PdfPageFormat.a4,
        cardStyle: true,
      );
      final bytes = await doc.save();
      final filename = '${_formatInvoice(transaksi.id)}.pdf';
      if (isMobile) {
        final savedPath = await savePdfToDownloads(bytes, filename);
        if (savedPath != null) {
          if (!mounted) return;
          _snack(
            isAndroid
                ? 'PDF tersimpan di Downloads'
                : 'PDF tersimpan di penyimpanan aplikasi',
            Colors.green,
          );
          return;
        }
        final xfile = XFile.fromData(
          bytes,
          name: filename,
          mimeType: 'application/pdf',
        );
        await Share.shareXFiles([xfile], text: 'Simpan PDF struk');
        if (!mounted) return;
        _snack('Pilih Bagikan > Simpan ke File', Colors.orange);
        return;
      }

      final savedPath = await savePdfToDownloads(bytes, filename);
      if (savedPath == null) {
        final location = await fs.getSaveLocation(
          suggestedName: filename,
          acceptedTypeGroups: [
            const fs.XTypeGroup(
              label: 'PDF',
              extensions: ['pdf'],
              mimeTypes: ['application/pdf'],
            ),
          ],
        );
        if (location == null) {
          if (!mounted) return;
          _snack('Penyimpanan dibatalkan', Colors.orange);
          return;
        }
        final path = location.path;
        final xfile = XFile.fromData(
          bytes,
          name: filename,
          mimeType: 'application/pdf',
        );
        await xfile.saveTo(path);
        if (!mounted) return;
        _snack('PDF tersimpan', Colors.green);
        return;
      }
      if (!mounted) return;
      _snack('PDF tersimpan di Downloads', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _snack('Gagal simpan PDF', Colors.red);
    }
  }

  Future<void> _shareReceiptPdf(
    Transaksi transaksi,
    _PaymentResult payment,
  ) async {
    if (kIsWeb) {
      try {
        final doc = await _buildReceiptPdf(
          transaksi: transaksi,
          payment: payment,
          pageFormat: PdfPageFormat.a4,
          cardStyle: true,
        );
        final bytes = await doc.save();
        final filename = '${_formatInvoice(transaksi.id)}.pdf';
        await savePdfBytesWeb(bytes, filename);
        if (!mounted) return;
        _snack('PDF diunduh, silakan kirim', Colors.green);
      } catch (e) {
        if (!mounted) return;
        _snack('Gagal menyiapkan PDF', Colors.red);
      }
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _snack('Bagikan PDF belum tersedia di Windows', Colors.orange);
      return;
    }
    try {
      final doc = await _buildReceiptPdf(
        transaksi: transaksi,
        payment: payment,
        // Gunakan ukuran standar agar preview WhatsApp tidak blank.
        pageFormat: PdfPageFormat.a4,
        cardStyle: true,
      );
      final bytes = await doc.save();
      final filename = '${_formatInvoice(transaksi.id)}.pdf';
      final xfile = XFile.fromData(
        bytes,
        name: filename,
        mimeType: 'application/pdf',
      );
      await Share.shareXFiles([xfile], text: 'Struk pembelian');
    } catch (e) {
      if (!mounted) return;
      _snack('Gagal membagikan PDF', Colors.red);
    }
  }

  Future<void> _printBluetooth(
    Transaksi transaksi,
    _PaymentResult payment,
  ) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      _snack('Bluetooth printer hanya di Android/iOS', Colors.orange);
      return;
    }
    final printerManager = PrinterBluetoothManager();
    printerManager.startScan(const Duration(seconds: 4));

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pilih Printer',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: StreamBuilder<List<PrinterBluetooth>>(
                  stream: printerManager.scanResults,
                  builder: (context, snapshot) {
                    final printers = snapshot.data ?? [];
                    if (printers.isEmpty) {
                      return const Center(child: Text('Tidak ada printer'));
                    }
                    return ListView.builder(
                      itemCount: printers.length,
                      itemBuilder: (context, index) {
                        final printer = printers[index];
                        return ListTile(
                          title: Text(printer.name ?? 'Printer'),
                          subtitle: Text(printer.address ?? ''),
                          onTap: () async {
                            printerManager.selectPrinter(printer);
                            final profile = await CapabilityProfile.load();
                            final generator = Generator(PaperSize.mm58, profile);
                            final bytes = <int>[];
                            bytes.addAll(
                              generator.text(
                                'ATk Wahyu Jaya',
                                styles: const PosStyles(
                                  align: PosAlign.center,
                                  bold: true,
                                ),
                              ),
                            );
                            bytes.addAll(generator.text(
                              'INV: ${_formatInvoice(transaksi.id)}',
                              styles: const PosStyles(align: PosAlign.center),
                            ));
                            bytes.addAll(generator.hr());
                            for (final item in transaksi.items) {
                              final produk = item.produk;
                              final totalItem = _itemTotal(item);
                              bytes.addAll(generator.row([
                                PosColumn(
                                  text: '${produk.nama} x${item.qty}',
                                  width: 8,
                                ),
                                PosColumn(
                                  text: _formatRupiah(totalItem),
                                  width: 4,
                                  styles: const PosStyles(align: PosAlign.right),
                                ),
                              ]));
                            }
                            bytes.addAll(generator.hr());
                            final diskonItems = _diskonItems(transaksi.items);
                            if (diskonItems > 0) {
                              bytes.addAll(generator.row([
                                PosColumn(text: 'Diskon Barang', width: 8),
                                PosColumn(
                                  text: _formatRupiah(diskonItems),
                                  width: 4,
                                  styles:
                                      const PosStyles(align: PosAlign.right),
                                ),
                              ]));
                            }
                            if (payment.discount > 0) {
                              bytes.addAll(generator.row([
                                PosColumn(text: 'Diskon Tambahan', width: 8),
                                PosColumn(
                                  text: _formatRupiah(payment.discount),
                                  width: 4,
                                  styles:
                                      const PosStyles(align: PosAlign.right),
                                ),
                              ]));
                            }
                            bytes.addAll(generator.row([
                              PosColumn(text: 'Total', width: 8),
                              PosColumn(
                                text: _formatRupiah(payment.total),
                                width: 4,
                                styles: const PosStyles(align: PosAlign.right),
                              ),
                            ]));
                            bytes.addAll(generator.row([
                              PosColumn(text: 'Kembalian', width: 8),
                              PosColumn(
                                text: _formatRupiah(payment.change),
                                width: 4,
                                styles: const PosStyles(align: PosAlign.right),
                              ),
                            ]));
                            bytes.addAll(generator.feed(2));
                            bytes.addAll(generator.cut());
                            await printerManager.printTicket(bytes);
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _snack(String msg, Color c) {
    final type = c == Colors.green
        ? AppFeedbackType.success
        : (c == Colors.red ? AppFeedbackType.error : AppFeedbackType.info);
    AppFeedback.show(
      context,
      message: msg,
      type: type,
    );
  }

  List<Produk> _filterProduk(List<Produk> data) {
    final keyword = _kataKunciProduk.trim().toLowerCase();

    var hasil = data.where((p) {
      if (_kategoriAktif != 'Semua' && p.kategori != _kategoriAktif) return false;
      if (keyword.isEmpty) return true;
      return p.nama.toLowerCase().contains(keyword) ||
          p.barcode.toLowerCase().contains(keyword);
    }).toList();

    hasil.sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));

    return hasil;
  }


  void _onSearchSubmit(String value, List<Produk> produk) {
    final keyword = value.trim().toLowerCase();
    if (keyword.isEmpty) return;
    for (final p in produk) {
      if (p.barcode.toLowerCase() == keyword) {
        tambahKeKeranjang(p);
        return;
      }
    }
  }

  void _scheduleEmptyReload() {
    if (_showEmptyReload || _emptyReloadTimer != null) return;
    _emptyReloadTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      _emptyReloadTimer = null;
      setState(() => _showEmptyReload = true);
    });
  }

  @override
  void dispose() {
    _emptyReloadTimer?.cancel();
    _cariProdukC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = _posBackground(context);
    final bgDeep = _posBackgroundDeep(context);
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bg, bgDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: StreamBuilder<List<Produk>>(
          stream: firestore.ambilSemuaProduk(),
          initialData: const <Produk>[],
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              final errorText = snapshot.error?.toString() ?? 'Gagal memuat.';
              debugPrint('Gagal memuat produk: $errorText');
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Gagal memuat produk.'),
                    const SizedBox(height: 6),
                    Text(
                      errorText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    HoverButton(
                      child: OutlinedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Muat ulang'),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final produk = snapshot.data!;
            if (produk.isEmpty) {
              _scheduleEmptyReload();
              return Center(
                child: _showEmptyReload
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Produk belum tersedia.'),
                          const SizedBox(height: 8),
                          HoverButton(
                            child: OutlinedButton(
                              onPressed: () => setState(() {}),
                              child: const Text('Muat ulang'),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
              );
            }
            _emptyReloadTimer?.cancel();
            _emptyReloadTimer = null;
            _showEmptyReload = false;
            final kategoriSet = <String>{
              'Semua',
              ...produk
                  .map((p) => p.kategori.trim().isEmpty ? 'Lainnya' : p.kategori)
                  .toSet(),
            };
            final kategoriList = kategoriSet.toList()..sort();
            if (kategoriList.remove('Semua')) {
              kategoriList.insert(0, 'Semua');
            }

            final produkFiltered = _filterProduk(produk);
            final qtyById = <String, int>{};
            for (final item in keranjang) {
              final id = item.produk.id;
              if (id == null) continue;
              qtyById[id] = (qtyById[id] ?? 0) + item.qty;
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1150;
                final isMobile = constraints.maxWidth < 720;

                if (isMobile) {
                  return Stack(
                    children: [
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            _CatalogToolbar(
                              kataKunci: _kataKunciProduk,
                              cariController: _cariProdukC,
                              kategori: kategoriList,
                              kategoriAktif: _kategoriAktif,
                              onCari: (value) =>
                                  setState(() => _kataKunciProduk = value),
                              onKategori: (value) =>
                                  setState(() => _kategoriAktif = value),
                                onScan: _openScanDialog,
                              onSubmit: (value) => _onSearchSubmit(value, produk),
                            ),
                            const SizedBox(height: 16),
                            _ProdukGrid(
                              produk: produkFiltered,
                              qtyById: qtyById,
                              onTambah: tambahKeKeranjang,
                              shrinkWrap: true,
                              scrollable: false,
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                      if (keranjang.isNotEmpty)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: FloatingActionButton.extended(
                            onPressed: _openCartSheet,
                            backgroundColor: _posAccent,
                            foregroundColor: Colors.black,
                            icon: const Icon(Icons.shopping_bag_outlined),
                            label: Text('$totalQtyBayar item'),
                          ),
                        ),
                    ],
                  );
                }

                return Column(
                  children: [
                    _CatalogToolbar(
                      kataKunci: _kataKunciProduk,
                      cariController: _cariProdukC,
                      kategori: kategoriList,
                      kategoriAktif: _kategoriAktif,
                      onCari: (value) =>
                          setState(() => _kataKunciProduk = value),
                      onKategori: (value) =>
                          setState(() => _kategoriAktif = value),
                        onScan: _openScanDialog,
                      onSubmit: (value) => _onSearchSubmit(value, produk),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: isWide
                          ? Row(
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: _ProdukGrid(
                                    produk: produkFiltered,
                                    qtyById: qtyById,
                                    onTambah: tambahKeKeranjang,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: _TransaksiTable(
                                    items: keranjang,
                                    subtotal: subtotalBayar,
                                    diskon: diskonBayar,
                                    totalBayar: totalBayar,
                                    onBayar: _openPaymentSheet,
                                    getHargaItem: _itemHarga,
                                    getDiskonItem: _itemDiskon,
                                    getTotalItem: _itemTotal,
                                    onTambah: tambahQty,
                                    onKurang: kurangiQty,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _ProdukGrid(
                                    produk: produkFiltered,
                                    qtyById: qtyById,
                                    onTambah: tambahKeKeranjang,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  flex: 4,
                                  child: _TransaksiTable(
                                    items: keranjang,
                                    subtotal: subtotalBayar,
                                    diskon: diskonBayar,
                                    totalBayar: totalBayar,
                                    onBayar: _openPaymentSheet,
                                    getHargaItem: _itemHarga,
                                    getDiskonItem: _itemDiskon,
                                    getTotalItem: _itemTotal,
                                    onTambah: tambahQty,
                                    onKurang: kurangiQty,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openCartSheet() async {
    if (_cartSheetOpen) return;
    _cartSheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final radius = BorderRadius.circular(24);
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.35,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, controller) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.vertical(top: radius.topLeft),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: _TransaksiTable(
                  items: keranjang,
                  subtotal: subtotalBayar,
                  diskon: diskonBayar,
                  totalBayar: totalBayar,
                  onBayar: _openPaymentSheet,
                  getHargaItem: _itemHarga,
                  getDiskonItem: _itemDiskon,
                  getTotalItem: _itemTotal,
                  onTambah: tambahQty,
                  onKurang: kurangiQty,
                  compact: true,
                ),
              ),
            );
          },
        );
      },
    );
    _cartSheetOpen = false;
  }
}

class _CatalogToolbar extends StatelessWidget {
  final String kataKunci;
  final TextEditingController cariController;
  final List<String> kategori;
  final String kategoriAktif;
  final ValueChanged<String> onCari;
  final ValueChanged<String> onKategori;
  final VoidCallback onScan;
  final ValueChanged<String> onSubmit;

  const _CatalogToolbar({
    required this.kataKunci,
    required this.cariController,
    required this.kategori,
    required this.kategoriAktif,
    required this.onCari,
    required this.onKategori,
    required this.onScan,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final text = _posTextPrimary(context);
    final surfaceAlt = _posSurfaceAlt(context);
    final border = _posBorder(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;
        final searchField = FocusTextField(
          controller: cariController,
          onChanged: onCari,
          onSubmitted: onSubmit,
          style: TextStyle(color: text),
          cursorColor: _posAccent,
          decoration: InputDecoration(
            hintText: 'Cari produk atau scan barcode',
            hintStyle: TextStyle(
              color: text.withValues(alpha: 0.5),
            ),
            prefixIcon: const Icon(Icons.search, color: _posAccent),
            filled: true,
            fillColor: surfaceAlt,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _posAccent),
            ),
            suffixIcon: kataKunci.isEmpty
                ? null
                : IconButton(
                    icon: Icon(
                      Icons.close,
                      color: text.withValues(alpha: 0.6),
                    ),
                    onPressed: () {
                      cariController.clear();
                      onCari('');
                    },
                  ),
          ),
        );
        final scanButton = SizedBox(
          width: isNarrow ? double.infinity : null,
          child: HoverButton(
            child: ElevatedButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _posAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),
          ),
        );
        return HoverCard(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: _panelDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Produk ATK',
                      style: TextStyle(
                        color: text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Kategori',
                      style: TextStyle(
                        color: text.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isNarrow)
                  Column(
                    children: [
                      searchField,
                      const SizedBox(height: 10),
                      scanButton,
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 12),
                      scanButton,
                    ],
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kategori.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final k = kategori[index];
                    return ChoiceChip(
                      label: Text(k),
                      selected: k == kategoriAktif,
                      onSelected: (_) => onKategori(k),
                      labelStyle: TextStyle(
                        color: k == kategoriAktif
                            ? Colors.black
                            : text.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                      selectedColor: _posAccent,
                      backgroundColor: surfaceAlt,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: border),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }
}

class _ProdukGrid extends StatelessWidget {
  final List<Produk> produk;
  final Map<String, int> qtyById;
  final ValueChanged<Produk> onTambah;
  final bool shrinkWrap;
  final bool scrollable;

  const _ProdukGrid({
    required this.produk,
    required this.qtyById,
    required this.onTambah,
    this.shrinkWrap = false,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _panelDecoration(context),
        child: produk.isEmpty
            ? Center(
                child: Text(
                  'Belum ada produk',
                  style: TextStyle(color: _posTextPrimary(context)),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width >= 1300
                    ? 6
                    : width >= 1100
                        ? 5
                        : width >= 820
                            ? 4
                            : width >= 600
                                ? 3
                                : 2;
                final isPhone = width < 420;
                final childAspectRatio = isPhone
                    ? 0.62
                    : width < 600
                        ? 0.66
                        : 0.72;

                return GridView.builder(
                  shrinkWrap: shrinkWrap,
                  physics: scrollable
                      ? const AlwaysScrollableScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  primary: scrollable && !shrinkWrap,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: produk.length,
                  itemBuilder: (context, i) {
                    final p = produk[i];
                    final habis = p.stok <= 0;
                    final qty = qtyById[p.id ?? ''] ?? 0;

                    return _ProdukCard(
                      produk: p,
                      habis: habis,
                      qtyInCart: qty,
                      onTap: habis ? null : () => onTambah(p),
                    );
                  },
                );
                },
              ),
      ),
    );
  }
}

class _ProdukCard extends StatelessWidget {
  final Produk produk;
  final bool habis;
  final int qtyInCart;
  final VoidCallback? onTap;

  const _ProdukCard({
    required this.produk,
    required this.habis,
    required this.qtyInCart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = habis ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    final image = _decodeBase64Image(produk.gambarBase64);
    final surfaceAlt = _posSurfaceAlt(context);
    final border = _posBorder(context);
    final text = _posTextPrimary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNarrow = MediaQuery.of(context).size.width < 480;
    final cardPadding = isNarrow ? 8.0 : 12.0;
    final imageHeight = isNarrow ? 100.0 : 140.0;
    final nameLength = produk.nama.trim().length;
    final fontScale = nameLength > 26
        ? 0.82
        : nameLength > 20
            ? 0.88
            : nameLength > 16
                ? 0.94
                : 1.0;
    final titleSize = (isNarrow ? 12.0 : 14.0) * fontScale;
    final priceSize = (isNarrow ? 14.0 : 16.0) * fontScale;
    final placeholderGradient = LinearGradient(
      colors: isDark
          ? const [Color(0xFF3A3A3A), Color(0xFF2A2A2A)]
          : const [Color(0xFFF2EEE7), Color(0xFFE5DED3)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final placeholderIconColor = isDark ? _posAccent : const Color(0xFFF2B05A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: habis ? border : _posAccent,
          ),
          boxShadow: const [],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: imageHeight,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F1F1F) : surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        image == null
                            ? Container(
                                decoration: BoxDecoration(
                                  gradient: placeholderGradient,
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.inventory_2_outlined,
                                    color: placeholderIconColor,
                                    size: 38,
                                  ),
                                ),
                              )
                            : Image(
                                image: image,
                                fit: BoxFit.cover,
                              ),
                        if (image != null)
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0x00000000), Color(0xCC000000)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: image == null
                                  ? (isDark
                                      ? const Color(0xFF1E1E1E)
                                      : Colors.white)
                                  : const Color(0xCC000000),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: border),
                            ),
                            child: Text(
                              produk.kategori.isEmpty ? 'Lainnya' : produk.kategori,
                              style: TextStyle(
                                color: image == null ? text : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  produk.nama,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: text,
                    fontSize: titleSize,
                  ),
                ),
                const SizedBox(height: 2),
                Builder(
                  builder: (context) {
                    final priceWidget = Text(
                      _formatRupiah(produk.harga),
                      style: TextStyle(
                        fontSize: priceSize,
                        fontWeight: FontWeight.w700,
                        color: text,
                      ),
                    );
                    final badgeWidget = Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        habis ? 'Habis' : 'Stok ${produk.stok}',
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: (isNarrow ? 11 : 12) * fontScale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                    if (isNarrow) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [priceWidget, badgeWidget],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [priceWidget, badgeWidget],
                    );
                  },
                ),
              ],
            ),
            if (qtyInCart > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _posAccent,
                    shape: BoxShape.circle,
                    boxShadow: _luxShadow(context),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    qtyInCart.toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


class _TransaksiTable extends StatelessWidget {
  final List<TransaksiItem> items;
  final int subtotal;
  final int diskon;
  final int totalBayar;
  final VoidCallback onBayar;
  final int Function(TransaksiItem) getHargaItem;
  final int Function(TransaksiItem) getDiskonItem;
  final int Function(TransaksiItem) getTotalItem;
  final ValueChanged<TransaksiItem> onTambah;
  final ValueChanged<TransaksiItem> onKurang;
  final bool compact;

  const _TransaksiTable({
    required this.items,
    required this.subtotal,
    required this.diskon,
    required this.totalBayar,
    required this.onBayar,
    required this.getHargaItem,
    required this.getDiskonItem,
    required this.getTotalItem,
    required this.onTambah,
    required this.onKurang,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = _posTextPrimary(context);
    final surfaceAlt = _posSurfaceAlt(context);
    final border = _posBorder(context);
    final isNarrow = MediaQuery.of(context).size.width < 480;
    return HoverCard(
      child: Container(
        padding: EdgeInsets.all(isNarrow ? 12 : 16),
        decoration: _panelDecoration(context),
        child: LayoutBuilder(
          builder: (context, constraints) {
          final isTableNarrow = constraints.maxWidth < 760;
          final listView = items.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada transaksi',
                    style: TextStyle(color: text),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: compact,
                  physics: compact
                      ? const NeverScrollableScrollPhysics()
                      : const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    final harga = getHargaItem(item);
                    final diskon = getDiskonItem(item);
                    final total = getTotalItem(item);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _posAccent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              size: 18,
                              color: _posAccent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.produk.nama,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item.qty} item',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: text.withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _formatRupiah(harga),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: TextStyle(
                                color: text,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatRupiah(total),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: TextStyle(
                                    color: text,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                if (diskon > 0)
                                  Text(
                                    '-$diskon%',
                                    style: const TextStyle(
                                      color: Color(0xFFF59E0B),
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 96,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _QtyPillButton(
                                  icon: Icons.remove,
                                  onTap: () => onKurang(item),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    item.qty.toString(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: text,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _QtyPillButton(
                                  icon: Icons.add,
                                  onTap: () => onTambah(item),
                                  filled: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );

          final totalQty = items.fold(0, (sum, item) => sum + item.qty);
          final listSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transaksi',
                    style: TextStyle(
                      color: text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _posAccent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$totalQty item',
                      style: TextStyle(
                        color: text,
                        fontSize: isNarrow ? 11 : 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              compact ? listView : Expanded(child: listView),
            ],
          );

          final hasFiniteHeight = constraints.maxHeight.isFinite;
          final isShort = hasFiniteHeight && constraints.maxHeight < 520;
          final summaryContent = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryRow(
                label: 'Subtotal',
                value: _formatRupiah(subtotal),
              ),
              SizedBox(height: isShort ? 4 : 6),
              _SummaryRow(
                label: 'Diskon',
                value: _formatRupiah(diskon),
              ),
              SizedBox(height: isShort ? 4 : 6),
              SizedBox(height: isShort ? 6 : 10),
              const Divider(height: 1),
              SizedBox(height: isShort ? 6 : 10),
              _SummaryRow(
                label: 'Total',
                value: _formatRupiah(totalBayar),
                emphasize: true,
              ),
              SizedBox(height: isShort ? 10 : 14),
              SizedBox(
                width: double.infinity,
                child: HoverButton(
                  child: ElevatedButton(
                    onPressed: onBayar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _posAccent,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(
                        vertical: isShort ? 8 : (isNarrow ? 10 : 12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Proses Pembayaran'),
                  ),
                ),
              ),
            ],
          );

          final summarySection = Container(
            padding: EdgeInsets.all(isShort ? 10 : (isNarrow ? 10 : 12)),
            decoration: BoxDecoration(
              color: surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: isShort
                ? SingleChildScrollView(child: summaryContent)
                : summaryContent,
          );

          if (compact) {
            return Column(
              children: [
                listSection,
                const SizedBox(height: 12),
                summarySection,
              ],
            );
          }

          if (isTableNarrow) {
            final listFlex = isShort ? 5 : 6;
            final summaryFlex = isShort ? 5 : 4;
            return Column(
              children: [
                Expanded(flex: listFlex, child: listSection),
                SizedBox(height: isShort ? 8 : 12),
                Expanded(flex: summaryFlex, child: summarySection),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: listSection),
              const SizedBox(width: 12),
              SizedBox(
                width: 260,
                child: summarySection,
              ),
            ],
          );
          },
        ),
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final Color? fillColor;

  const _KeypadButton({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceAlt = _posSurfaceAlt(context);
    final border = _posBorder(context);
    final text = _posTextPrimary(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? fillColor ?? _posAccent
              : surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled ? Colors.transparent : border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.black : text,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = _posTextPrimary(context);
    final isNarrow = MediaQuery.of(context).size.width < 480;
    final style = emphasize
        ? TextStyle(
            fontSize: isNarrow ? 16 : 18,
            fontWeight: FontWeight.w700,
            color: text,
          )
        : TextStyle(
            fontSize: isNarrow ? 12 : 14,
            color: text.withValues(alpha: 0.6),
          );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}

class _QtyPillButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _QtyPillButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = _posBorder(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: filled ? _posAccent : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Icon(
          icon,
          size: 16,
          color: filled ? Colors.black : _posAccent,
        ),
      ),
    );
  }
}

class _PaymentResult {
  final String method;
  final int paidAmount;
  final int change;
  final int discount;
  final int total;

  _PaymentResult({
    required this.method,
    required this.paidAmount,
    required this.change,
    required this.discount,
    required this.total,
  });
}

String _formatRupiah(int value) {
  final buffer = StringBuffer(_formatAngkaPlain(value.abs()));
  final prefix = value < 0 ? '-Rp ' : 'Rp ';
  return '$prefix${buffer.toString()}';
}

String _formatAngkaPlain(int value) {
  final buffer = StringBuffer();
  final str = value.toString();
  for (var i = 0; i < str.length; i++) {
    final pos = str.length - i;
    buffer.write(str[i]);
    if (pos > 1 && pos % 3 == 1) buffer.write('.');
  }
  return buffer.toString();
}

String _formatAngkaText(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  final value = int.tryParse(digits) ?? 0;
  return _formatAngkaPlain(value);
}

int _parseAngkaText(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(digits) ?? 0;
}

String _formatInvoice(String transaksiId) {
  final now = DateTime.now();
  final date =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  final tail = transaksiId.length > 4
      ? transaksiId.substring(transaksiId.length - 4)
      : transaksiId;
  return 'INV-$date-$tail';
}

BoxDecoration _panelDecoration(BuildContext context) {
  return BoxDecoration(
    color: _posSurface(context),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: _posBorder(context)),
    boxShadow: _luxShadow(context),
  );
}

List<BoxShadow> _luxShadow(BuildContext context) {
  return [
    BoxShadow(
      color: const Color(0x66000000),
      blurRadius: 20,
      offset: const Offset(0, 12),
    ),
  ];
}

ImageProvider? _decodeBase64Image(String? data) {
  if (data == null || data.trim().isEmpty) return null;
  try {
    return MemoryImage(base64Decode(data));
  } catch (_) {
    return null;
  }
}

const Color _posAccent = Color(0xFFF28C28);

Color _posBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFF7F6F3);

Color _posBackgroundDeep(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF111111)
        : const Color(0xFFF0EEE9);

Color _posSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF262626)
        : const Color(0xFFFFFFFF);

Color _posSurfaceAlt(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2E2E2E)
        : const Color(0xFFF1EFEB);

Color _posBorder(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3B3B3B)
        : const Color(0xFFD7D3C9);

Color _posTextPrimary(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF2EADF)
        : const Color(0xFF1C1B1A);


