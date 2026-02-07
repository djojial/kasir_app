import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/ui/interactive_widgets.dart';
import '../../database/models/produk_model.dart';
import '../../database/services/firestore_service.dart';
import '../../utils/pdf_download.dart';
import '../../utils/pdf_save.dart';

String _activityUsernameOnly(dynamic raw) {
  final text = (raw ?? '').toString().trim();
  if (text.isEmpty) return '';
  final atIndex = text.indexOf('@');
  if (atIndex > 0) {
    return text.substring(0, atIndex);
  }
  return text;
}

String _activityActorLabel(Map<String, dynamic> log) {
  final name = _activityUsernameOnly(log['actor_name']);
  if (name.isNotEmpty) return name;
  final emailName = _activityUsernameOnly(log['actor_email']);
  if (emailName.isNotEmpty) return emailName;
  final uid = (log['actor_uid'] ?? '').toString().trim();
  if (uid.isNotEmpty) return uid;
  return '-';
}

class HalamanLaporan extends StatefulWidget {
  const HalamanLaporan({super.key});

  @override
  State<HalamanLaporan> createState() => _HalamanLaporanState();
}

class _HalamanLaporanState extends State<HalamanLaporan> {
  final TextEditingController _tanggalC = TextEditingController();
  DateTimeRange? _rentang;
  String _filterAktifStok = 'all';
  final FirestoreService _firestore = FirestoreService();
  bool _exporting = false;

  static const List<_FilterOption> _filterOpsi = [
    _FilterOption(label: 'Semua', value: 'all'),
    _FilterOption(label: 'Masuk', value: 'masuk'),
    _FilterOption(label: 'Keluar', value: 'keluar'),
    _FilterOption(label: 'Produk Baru', value: 'init'),
    _FilterOption(label: 'Restok', value: 'restock'),
    _FilterOption(label: 'Penjualan', value: 'pos'),
    _FilterOption(label: 'Penyesuaian', value: 'edit'),
  ];
  static const List<_FilterOption> _filterOpsiAktivitas = [
    _FilterOption(label: 'Semua', value: 'all'),
    _FilterOption(label: 'Produk', value: 'produk'),
    _FilterOption(label: 'Stok', value: 'stok'),
    _FilterOption(label: 'Transaksi', value: 'transaksi'),
    _FilterOption(label: 'User', value: 'user'),
    _FilterOption(label: 'Harga', value: 'harga'),
    _FilterOption(label: 'Password', value: 'password'),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _rentang = DateTimeRange(start: today, end: today);
    _tanggalC.text = _formatTanggalRange(_rentang!);
  }

  @override
  void dispose() {
    _tanggalC.dispose();
    super.dispose();
  }

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _pilihRentangTanggal() async {
    final now = DateTime.now();
    final awal = DateTime(now.year, now.month, now.day);

    final hasil = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _rentang ??
          DateTimeRange(
            start: awal,
            end: awal,
          ),
    );

    if (hasil == null) return;

    setState(() {
      _rentang = hasil;
      _tanggalC.text = _formatTanggalRange(hasil);
    });
  }

  String _formatTanggalRange(DateTimeRange range) {
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final start =
        '${range.start.day} ${bulan[range.start.month - 1]} ${range.start.year}';
    final end =
        '${range.end.day} ${bulan[range.end.month - 1]} ${range.end.year}';
    return range.start == range.end ? start : '$start - $end';
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
              _FilterBar(
                tanggalController: _tanggalC,
                onTanggalTap: _pilihRentangTanggal,
                filterAktif: _filterAktifStok,
                filterOpsi: _filterOpsi,
                onFilterChanged: (value) =>
                    setState(() => _filterAktifStok = value),
                onExport: _exportPdf,
                exporting: _exporting,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _RingkasanTab(
                        rentang: _rentang,
                        filterAktif: _filterAktifStok,
                        wrapInScroll: false,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final produkList = await _firestore.ambilSemuaProduk().first;
      final produkMap = <String, _ProdukInfo>{
        for (final p in produkList)
          if (p.id != null)
            p.id!: _ProdukInfo(
              nama: p.nama,
              kategori: p.kategori,
              barcode: p.barcode,
              hargaModal: p.hargaModal,
              hargaJual: p.harga,
            ),
      };
      final logs = await _firestore.streamStokLog().first;
      final filtered = logs.where(_logSesuaiFilter).toList();

      const namaToko = 'ATK Wahyu Jaya';
      const alamatToko = 'Jln Lamno, Jaya, Aceh Jaya';
      const nomorHp = '082210203488';
      final emailToko = FirebaseAuth.instance.currentUser?.email ?? '-';

      pw.MemoryImage? logoImage;
      try {
        final logoBytes = await rootBundle.load('image/nira_posbaru.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {
        logoImage = null;
      }

      final doc = pw.Document();
      final rangeLabel =
          _rentang == null ? 'Semua tanggal' : _formatTanggalRange(_rentang!);
      final filterLabel = _filterOpsi
          .firstWhere((o) => o.value == _filterAktifStok,
              orElse: () => const _FilterOption(label: 'Semua', value: 'all'))
          .label;

      final headers = [
        'No',
        'Tanggal',
        'User',
        'Invoice',
        'Produk',
        'Kategori',
        'Barcode',
        'Perubahan',
        'Stok Akhir',
        'Harga Modal',
        'Laba %',
        'Laba/Unit',
        'Modal Total',
        'Laba Total',
        'Aktivitas',
      ];

      var totalModalAll = 0;
      var totalLabaAll = 0;
      final rows = <List<String>>[];
      final sorted = List<Map<String, dynamic>>.from(filtered)
        ..sort((a, b) {
          final aTs = a['waktu'];
          final bTs = b['waktu'];
          final aDate = aTs is Timestamp ? aTs.toDate() : DateTime(1970);
          final bDate = bTs is Timestamp ? bTs.toDate() : DateTime(1970);
          return bDate.compareTo(aDate);
        });

      for (var i = 0; i < sorted.length; i++) {
        final log = sorted[i];
        final ts = log['waktu'];
        final dt = ts is Timestamp ? ts.toDate() : DateTime(1970);
        final id = log['produk_id'];
        final info = id is String ? produkMap[id] : null;
        final namaProduk = log['nama_produk'];
        final nama = (namaProduk ?? info?.nama ?? 'Produk').toString();
        final perubahan = (log['perubahan'] ?? 0) as int;
        final stokAkhir = (log['stok_akhir'] ?? 0) as int;
        final sumber = (log['sumber'] ?? '').toString().toLowerCase();
        final tipe = (log['tipe'] ?? '').toString().toLowerCase();
        final kategori = (info?.kategori ?? 'Lainnya').toString();
        final barcode = (info?.barcode ?? '-').toString();
        final actorName = _activityActorLabel(log);
        final invoiceRaw = log['refId'] ?? log['transaksiId'];
        final invoice =
            sumber == 'pos' && invoiceRaw != null ? invoiceRaw.toString() : '-';
        final isHarga = tipe == 'harga';
        final labelPerubahan =
            isHarga ? '-' : (perubahan >= 0 ? '+$perubahan' : '$perubahan');
        final qty = isHarga ? 0 : perubahan.abs();
        final modalRaw = log['harga_modal'];
        final jualRaw = log['harga_jual'];
        final hasPrice = modalRaw is int || jualRaw is int || info != null;
        final modal = modalRaw is int ? modalRaw : (info?.hargaModal ?? 0);
        final jual = jualRaw is int ? jualRaw : (info?.hargaJual ?? 0);
        final labaUnit = jual - modal;
        final modalTotal = modal * qty;
        final labaTotal = labaUnit * qty;
        final labaPercent = hasPrice && modal > 0
            ? '${((labaUnit / modal) * 100).toStringAsFixed(0)}%'
            : '-';

        if (!isHarga && qty > 0) {
          totalModalAll += modalTotal;
          totalLabaAll += labaTotal;
        }

        final aktivitas = _buildAktivitasStokDetail(log);

        rows.add([
          '${i + 1}',
          _formatTanggalJam(dt),
          actorName,
          invoice,
          nama,
          kategori,
          barcode,
          labelPerubahan,
          stokAkhir.toString(),
          hasPrice ? _formatRupiahSimple(modal) : '-',
          labaPercent,
          hasPrice ? _formatRupiahSimple(labaUnit) : '-',
          isHarga ? '-' : _formatRupiahSimple(modalTotal),
          isHarga ? '-' : _formatRupiahSimple(labaTotal),
          aktivitas,
        ]);
      }

      rows.add([
        '',
        '',
        '',
        '',
        'TOTAL',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        _formatRupiahSimple(totalModalAll),
        _formatRupiahSimple(totalLabaAll),
        '',
      ]);

      final columnWidths = <int, pw.TableColumnWidth>{
        0: const pw.FixedColumnWidth(20),
        1: const pw.FixedColumnWidth(64),
        2: const pw.FixedColumnWidth(40),
        3: const pw.FixedColumnWidth(62),
        4: const pw.FixedColumnWidth(60),
        5: const pw.FixedColumnWidth(40),
        6: const pw.FixedColumnWidth(60),
        7: const pw.FixedColumnWidth(48),
        8: const pw.FixedColumnWidth(46),
        9: const pw.FixedColumnWidth(48),
        10: const pw.FixedColumnWidth(34),
        11: const pw.FixedColumnWidth(44),
        12: const pw.FixedColumnWidth(52),
        13: const pw.FixedColumnWidth(52),
        14: const pw.FixedColumnWidth(70),
      };

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoImage != null)
                  pw.Container(
                    width: 56,
                    height: 56,
                    alignment: pw.Alignment.center,
                    child: pw.Image(logoImage!, fit: pw.BoxFit.contain),
                  )
                else
                  pw.SizedBox(width: 56, height: 56),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        namaToko,
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        alamatToko,
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'HP: $nomorHp',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'Email: $emailToko',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Laporan',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('Rentang: $rangeLabel'),
                    pw.Text('Filter: $filterLabel'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: headers,
              data: rows,
              columnWidths: columnWidths,
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              headerStyle: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
              ),
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.center,
                7: pw.Alignment.center,
                8: pw.Alignment.center,
                9: pw.Alignment.center,
                10: pw.Alignment.center,
                11: pw.Alignment.center,
                12: pw.Alignment.center,
                13: pw.Alignment.center,
              },
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      await _savePdf(bytes, 'laporan.pdf');
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _savePdf(Uint8List bytes, String filename) async {
    if (kIsWeb) {
      await savePdfBytesWeb(bytes, filename);
      return;
    }
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final isMobile = isAndroid || defaultTargetPlatform == TargetPlatform.iOS;
    final savedPath = await savePdfToDownloads(bytes, filename);
    if (!mounted) return;
    if (savedPath == null) {
      if (isMobile) {
        final xfile = XFile.fromData(
          bytes,
          name: filename,
          mimeType: 'application/pdf',
        );
        await Share.shareXFiles([xfile], text: 'Simpan PDF laporan');
        if (!mounted) return;
        _snack('Pilih Bagikan > Simpan ke File', Colors.orange);
        return;
      }
      _snack('Gagal menyimpan otomatis', Colors.red);
      return;
    }
    _snack(
      isMobile
          ? (isAndroid
              ? 'PDF tersimpan di Downloads'
              : 'PDF tersimpan di penyimpanan aplikasi')
          : 'PDF tersimpan di Downloads',
      Colors.green,
    );
  }

  bool _logDalamRentang(Map<String, dynamic> log) {
    if (_rentang == null) return true;
    final ts = log['waktu'];
    if (ts is! Timestamp) return false;
    final dt = ts.toDate();
    final start = DateTime(
      _rentang!.start.year,
      _rentang!.start.month,
      _rentang!.start.day,
    );
    final end = DateTime(
      _rentang!.end.year,
      _rentang!.end.month,
      _rentang!.end.day,
      23,
      59,
      59,
    );
    return !dt.isBefore(start) && !dt.isAfter(end);
  }

  bool _logSesuaiFilter(Map<String, dynamic> log) {
    if (!_logDalamRentang(log)) return false;
    if (_filterAktifStok != 'all') {
      final sumber = (log['sumber'] ?? '').toString().toLowerCase();
      final tipe = (log['tipe'] ?? '').toString().toLowerCase();
      final isTipe =
          _filterAktifStok == 'masuk' || _filterAktifStok == 'keluar';
      if (isTipe) {
        if (tipe != _filterAktifStok) return false;
      } else {
        if (sumber != _filterAktifStok) return false;
      }
    }
    return true;
  }

  String _formatTanggalJam(DateTime dt) {
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = bulan[dt.month - 1];
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day $month $year $hour:$minute';
  }

  String _formatRupiahSimple(int value) {
    final absValue = value.abs();
    final str = absValue.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      final indexFromEnd = str.length - i;
      buffer.write(str[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }
    final prefix = value < 0 ? '-Rp ' : 'Rp ';
    return '$prefix${buffer.toString()}';
  }

  String _labelSumber(String raw) {
    switch (raw) {
      case 'init':
        return 'Produk Baru';
      case 'restock':
        return 'Restok';
      case 'pos':
        return 'Penjualan';
      case 'edit':
        return 'Penyesuaian';
      default:
        return 'Lainnya';
    }
  }

  String _labelTipe(String raw) {
    switch (raw) {
      case 'masuk':
        return 'Masuk';
      case 'keluar':
        return 'Keluar';
      case 'harga':
        return 'Harga';
      default:
        return '-';
    }
  }

  String _buildAktivitasStokDetail(Map<String, dynamic> log) {
    final sumber = (log['sumber'] ?? '').toString().toLowerCase();
    final tipe = (log['tipe'] ?? '').toString().toLowerCase();
    final perubahan = (log['perubahan'] ?? 0) as int;
    final qty = perubahan.abs();
    final catatan = (log['catatan'] ?? '').toString().trim();
    final invoiceRaw = log['refId'] ?? log['transaksiId'];
    final invoice =
        sumber == 'pos' && invoiceRaw != null ? invoiceRaw.toString() : '';

    if (tipe == 'harga') {
      final modalLama = log['harga_modal_lama'];
      final modalBaru = log['harga_modal'];
      final jualLama = log['harga_jual_lama'];
      final jualBaru = log['harga_jual'];
      final parts = <String>['Ubah harga'];
      if (modalLama is int && modalBaru is int && modalLama != modalBaru) {
        parts.add(
          'Modal ${_formatRupiahSimple(modalLama)} -> ${_formatRupiahSimple(modalBaru)}',
        );
      }
      if (jualLama is int && jualBaru is int && jualLama != jualBaru) {
        parts.add(
          'Jual ${_formatRupiahSimple(jualLama)} -> ${_formatRupiahSimple(jualBaru)}',
        );
      }
      return parts.join(' | ');
    }

    String base;
    String detail = '';
    if (sumber == 'init') {
      base = 'Produk baru';
      detail = 'Stok awal $qty';
    } else if (sumber == 'restock') {
      base = 'Restok';
      detail = perubahan >= 0 ? '+$qty' : '-$qty';
    } else if (sumber == 'pos') {
      base = 'Penjualan';
      detail = qty == 0 ? '' : '-$qty';
    } else if (sumber == 'edit' && catatan.toLowerCase() == 'hapus produk') {
      base = 'Hapus produk';
      detail = qty == 0 ? '' : '-$qty';
    } else if (sumber == 'edit') {
      base = 'Penyesuaian stok';
      detail = qty == 0 ? '' : (perubahan >= 0 ? '+$qty' : '-$qty');
    } else {
      base = _labelSumber(sumber);
      detail =
          qty == 0 ? _labelTipe(tipe) : (perubahan >= 0 ? '+$qty' : '-$qty');
    }

    final parts = <String>[base];
    if (detail.isNotEmpty) {
      parts.add(detail);
    }
    if (invoice.isNotEmpty) {
      parts.add('Inv $invoice');
    }
    if (catatan.isNotEmpty && catatan.toLowerCase() != 'hapus produk') {
      parts.add(catatan);
    }
    return parts.join(' | ');
  }
}

class _FilterBar extends StatelessWidget {
  final TextEditingController tanggalController;
  final VoidCallback onTanggalTap;
  final String filterAktif;
  final List<_FilterOption> filterOpsi;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback? onExport;
  final bool exporting;

  const _FilterBar({
    required this.tanggalController,
    required this.onTanggalTap,
    required this.filterAktif,
    required this.filterOpsi,
    required this.onFilterChanged,
    required this.onExport,
    required this.exporting,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 840;
        final tanggalField = FocusTextField(
          controller: tanggalController,
          readOnly: true,
          onTap: onTanggalTap,
          decoration: InputDecoration(
            hintText: 'Rentang tanggal',
            prefixIcon: Icon(
              Icons.date_range,
              color: Theme.of(context).colorScheme.primary,
            ),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1F1F1F)
                : const Color(0xFFF1EFEB),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
        final filterControl = _DropdownFilter(
          label: 'Filter',
          value: filterAktif,
          options: filterOpsi,
          onChanged: onFilterChanged,
        );
        final exportButton = onExport == null
            ? const SizedBox.shrink()
            : SizedBox(
                width: isNarrow ? double.infinity : null,
                child: HoverButton(
                  enabled: !exporting,
                  child: OutlinedButton.icon(
                    onPressed: exporting ? null : onExport,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(color: Theme.of(context).dividerColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.file_download_outlined),
                    label: Text(exporting ? 'Menyiapkan...' : 'Export'),
                  ),
                ),
              );

        return HoverCard(
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
                      tanggalField,
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: filterControl,
                      ),
                      const SizedBox(height: 12),
                      exportButton,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: tanggalField),
                      const SizedBox(width: 16),
                      filterControl,
                      const SizedBox(width: 16),
                      exportButton,
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String label;
  final String value;
  final List<_FilterOption> options;
  final ValueChanged<String> onChanged;

  const _DropdownFilter({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = options.firstWhere((o) => o.value == value);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final icon = _FilterOption.iconFor(selected.value);
    return Container(
      child: PopupMenuButton<String>(
        onSelected: onChanged,
        color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF6F4EF),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        itemBuilder: (context) {
          return options.map((o) {
            final isActive = o.value == value;
            final itemIcon = _FilterOption.iconFor(o.value);
            return PopupMenuItem<String>(
              value: o.value,
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isActive
                          ? scheme.primary.withValues(alpha: 0.15)
                          : scheme.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      itemIcon,
                      size: 16,
                      color: isActive
                          ? scheme.primary
                          : scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    o.label,
                    style: TextStyle(
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (isActive)
                    Icon(Icons.check, size: 16, color: scheme.primary),
                ],
              ),
            );
          }).toList();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF1EFEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    selected.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterOption {
  final String label;
  final String value;

  const _FilterOption({required this.label, required this.value});

  static IconData iconFor(String value) {
    switch (value) {
      case 'masuk':
        return Icons.south_west;
      case 'keluar':
        return Icons.north_east;
      case 'init':
        return Icons.inventory_2_outlined;
      case 'restock':
        return Icons.local_shipping_outlined;
      case 'pos':
        return Icons.point_of_sale;
      case 'edit':
        return Icons.tune;
      default:
        return Icons.filter_alt_outlined;
    }
  }
}

class _RingkasanTab extends StatelessWidget {
  final DateTimeRange? rentang;
  final String filterAktif;
  final bool wrapInScroll;
  final FirestoreService firestore = FirestoreService();

  _RingkasanTab({
    required this.rentang,
    required this.filterAktif,
    this.wrapInScroll = true,
  });

  bool _logDalamRentang(Map<String, dynamic> log) {
    if (rentang == null) return true;
    final ts = log['waktu'];
    if (ts is! Timestamp) return false;
    final dt = ts.toDate();
    final start = DateTime(
      rentang!.start.year,
      rentang!.start.month,
      rentang!.start.day,
    );
    final end = DateTime(
      rentang!.end.year,
      rentang!.end.month,
      rentang!.end.day,
      23,
      59,
      59,
    );
    return !dt.isBefore(start) && !dt.isAfter(end);
  }

  bool _activityDalamRentang(Map<String, dynamic> log) {
    if (rentang == null) return true;
    final ts = log['created_at'];
    if (ts is! Timestamp) return false;
    final dt = ts.toDate();
    final start = DateTime(
      rentang!.start.year,
      rentang!.start.month,
      rentang!.start.day,
    );
    final end = DateTime(
      rentang!.end.year,
      rentang!.end.month,
      rentang!.end.day,
      23,
      59,
      59,
    );
    return !dt.isBefore(start) && !dt.isAfter(end);
  }

  bool _logSesuaiFilter(Map<String, dynamic> log) {
    if (!_logDalamRentang(log)) return false;
    if (filterAktif != 'all') {
      final sumber = (log['sumber'] ?? '').toString().toLowerCase();
      final tipe = (log['tipe'] ?? '').toString().toLowerCase();
      final isTipe = filterAktif == 'masuk' || filterAktif == 'keluar';
      if (isTipe) {
        if (tipe != filterAktif) return false;
      } else {
        if (sumber != filterAktif) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Produk>>(
      stream: firestore.ambilSemuaProduk(),
      builder: (context, produkSnap) {
        if (!produkSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final produkList = produkSnap.data!;
        final Map<String, _ProdukInfo> produkMap = {
          for (final p in produkList)
            if (p.id != null)
              p.id!: _ProdukInfo(
                nama: p.nama,
                kategori: p.kategori,
                barcode: p.barcode,
                hargaModal: p.hargaModal,
                hargaJual: p.harga,
              ),
        };
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: firestore.streamStokLog(),
          builder: (context, logSnap) {
            if (!logSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final logs = logSnap.data!.where(_logSesuaiFilter).toList();
            var totalMasuk = 0;
            var totalKeluar = 0;

            for (final log in logs) {
              final perubahan = (log['perubahan'] ?? 0) as int;
              if (perubahan > 0) {
                totalMasuk += perubahan;
              } else {
                totalKeluar += perubahan.abs();
              }
            }

            final totalProduk = produkList.length;
            final totalStok =
                produkList.fold<int>(0, (total, p) => total + p.stok);
            final now = DateTime.now();
            final rangeStart = rentang == null
                ? DateTime(now.year, now.month, now.day)
                    .subtract(const Duration(days: 29))
                : DateTime(
                    rentang!.start.year,
                    rentang!.start.month,
                    rentang!.start.day,
                  );
            final rangeEnd = rentang == null
                ? DateTime(now.year, now.month, now.day)
                : DateTime(
                    rentang!.end.year,
                    rentang!.end.month,
                    rentang!.end.day,
                  );
            final maxDays = 30;
            final totalDays = rangeEnd.difference(rangeStart).inDays + 1;
            final daysCount = totalDays > maxDays ? maxDays : totalDays;
            final tagLabel = rentang == null ? '30 hari' : '${daysCount} hari';

            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isNarrow = width < 720;
                final isTight = width < 520;
                final gap = 16.0;
                final cardWidth = isTight ? width : (width - gap) / 2;

                final cards = [
                  _RingkasanCard(
                    title: 'Total Produk',
                    value: totalProduk.toString(),
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFFF28C28),
                  ),
                  _RingkasanCard(
                    title: 'Total Stok',
                    value: totalStok.toString(),
                    icon: Icons.stacked_bar_chart_outlined,
                    color: const Color(0xFFC76A1F),
                  ),
                  _RingkasanCard(
                    title: 'Stok Masuk',
                    value: totalMasuk.toString(),
                    icon: Icons.south_west,
                    color: const Color(0xFFE7A354),
                  ),
                  _RingkasanCard(
                    title: 'Stok Keluar',
                    value: totalKeluar.toString(),
                    icon: Icons.north_east,
                    color: const Color(0xFFF2B05A),
                  ),
                ];

                final content = Column(
                  children: [
                    if (isNarrow)
                      Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final card in cards)
                            SizedBox(width: cardWidth, child: card),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 16),
                          Expanded(child: cards[1]),
                          const SizedBox(width: 16),
                          Expanded(child: cards[2]),
                          const SizedBox(width: 16),
                          Expanded(child: cards[3]),
                        ],
                      ),
                    const SizedBox(height: 16),
                    _ChartCard(
                      title: 'Detail Log Stok',
                      tag: tagLabel,
                      child: _LogTable(
                        logs: logs,
                        produkMap: produkMap,
                      ),
                    ),
                  ],
                );

                if (wrapInScroll) {
                  return SingleChildScrollView(child: content);
                }
                return content;
              },
            );
          },
        );
      },
    );
  }
}

class _ActivityTab extends StatelessWidget {
  final DateTimeRange? rentang;
  final String filterAktif;
  final FirestoreService firestore = FirestoreService();

  _ActivityTab({
    required this.rentang,
    required this.filterAktif,
  });

  bool _logDalamRentang(Map<String, dynamic> log) {
    if (rentang == null) return true;
    final ts = log['created_at'];
    if (ts is! Timestamp) return false;
    final dt = ts.toDate();
    final start = DateTime(
      rentang!.start.year,
      rentang!.start.month,
      rentang!.start.day,
    );
    final end = DateTime(
      rentang!.end.year,
      rentang!.end.month,
      rentang!.end.day,
      23,
      59,
      59,
    );
    return !dt.isBefore(start) && !dt.isAfter(end);
  }

  bool _logSesuaiFilter(Map<String, dynamic> log) {
    if (!_logDalamRentang(log)) return false;
    if (filterAktif == 'all') return true;
    final category = (log['category'] ?? '').toString().toLowerCase();
    return category == filterAktif;
  }

  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return '-';
    final dt = ts.toDate();
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String _labelAksi(String value) {
    switch (value) {
      case 'produk_tambah':
        return 'Tambah produk';
      case 'produk_hapus':
        return 'Hapus produk';
      case 'produk_ubah':
        return 'Ubah produk';
      case 'stok_ubah':
        return 'Ubah stok';
      case 'harga_ubah':
        return 'Ubah harga';
      case 'transaksi':
        return 'Transaksi';
      case 'login':
        return 'Login';
      case 'logout':
        return 'Logout';
      case 'user_create':
        return 'Buat user';
      case 'user_update_role':
        return 'Ubah role user';
      case 'user_update_email':
        return 'Ubah email user';
      case 'user_update_nickname':
        return 'Ubah nama user';
      case 'user_delete':
        return 'Hapus user';
      case 'user_disable':
        return 'Nonaktifkan user';
      case 'user_enable':
        return 'Aktifkan user';
      case 'reset_password':
        return 'Reset password';
      case 'role_default_update':
        return 'Ubah default role';
      case 'user_access_override':
        return 'Akses khusus user';
      default:
        return value.isEmpty ? '-' : value;
    }
  }

  String _buildDetail(Map<String, dynamic> log) {
    final parts = <String>[];
    final target = (log['target_label'] ?? '').toString().trim();
    if (target.isNotEmpty) {
      parts.add(target);
    }
    final meta = log['meta'];
    if (meta is Map) {
      if (meta['total'] != null) {
        parts.add('Total: Rp ${meta['total']}');
      }
      if (meta['items'] != null) {
        parts.add('Item: ${meta['items']}');
      }
      if (meta['stok_lama'] != null && meta['stok_baru'] != null) {
        parts.add('Stok ${meta['stok_lama']} → ${meta['stok_baru']}');
      }
      if (meta['harga_lama'] != null && meta['harga_baru'] != null) {
        parts.add('Harga ${meta['harga_lama']} → ${meta['harga_baru']}');
      }
      if (meta['role_baru'] != null) {
        parts.add('Role: ${meta['role_baru']}');
      }
      if (meta['email_baru'] != null) {
        parts.add('Email: ${meta['email_baru']}');
      }
    }
    return parts.isEmpty ? '-' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: firestore.streamActivityLogs(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snap.data!.where(_logSesuaiFilter).toList();
        return HoverCard(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: _panelDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Log Aktivitas',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${logs.length} aktivitas',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: logs.isEmpty
                      ? const Center(child: Text('Belum ada aktivitas'))
                      : ListView.separated(
                          itemCount: logs.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            final action =
                                _labelAksi((log['action'] ?? '').toString());
                            final actorName = _activityActorLabel(log);
                            final time = _formatDateTime(
                              log['created_at'] as Timestamp?,
                            );
                            final detail = _buildDetail(log);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  action,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  detail,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.65),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$actorName • $time',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
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

class _LogTable extends StatefulWidget {
  final List<Map<String, dynamic>> logs;
  final Map<String, _ProdukInfo>? produkMap;

  const _LogTable({
    required this.logs,
    this.produkMap,
  });

  @override
  State<_LogTable> createState() => _LogTableState();
}

class _LogTableState extends State<_LogTable> {
  int? _hoveredIndex;

  String _formatTanggalJam(DateTime dt) {
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = bulan[dt.month - 1];
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day $month $year $hour:$minute';
  }

  String _labelSumber(String raw) {
    switch (raw) {
      case 'init':
        return 'Produk Baru';
      case 'restock':
        return 'Restok';
      case 'pos':
        return 'Penjualan';
      case 'edit':
        return 'Penyesuaian';
      default:
        return 'Lainnya';
    }
  }

  String _labelTipe(String raw) {
    switch (raw) {
      case 'masuk':
        return 'Masuk';
      case 'keluar':
        return 'Keluar';
      case 'harga':
        return 'Harga';
      default:
        return '-';
    }
  }

  String _buildAktivitasStokDetail(Map<String, dynamic> log) {
    final sumber = (log['sumber'] ?? '').toString().toLowerCase();
    final tipe = (log['tipe'] ?? '').toString().toLowerCase();
    final perubahan = (log['perubahan'] ?? 0) as int;
    final qty = perubahan.abs();
    final catatan = (log['catatan'] ?? '').toString().trim();
    final invoiceRaw = log['refId'] ?? log['transaksiId'];
    final invoice =
        sumber == 'pos' && invoiceRaw != null ? invoiceRaw.toString() : '';

    if (tipe == 'harga') {
      final modalLama = log['harga_modal_lama'];
      final modalBaru = log['harga_modal'];
      final jualLama = log['harga_jual_lama'];
      final jualBaru = log['harga_jual'];
      final parts = <String>['Ubah harga'];
      if (modalLama is int && modalBaru is int && modalLama != modalBaru) {
        parts.add(
          'Modal ${_formatRupiahSimple(modalLama)} -> ${_formatRupiahSimple(modalBaru)}',
        );
      }
      if (jualLama is int && jualBaru is int && jualLama != jualBaru) {
        parts.add(
          'Jual ${_formatRupiahSimple(jualLama)} -> ${_formatRupiahSimple(jualBaru)}',
        );
      }
      return parts.join(' | ');
    }

    String base;
    String detail = '';
    if (sumber == 'init') {
      base = 'Produk baru';
      detail = 'Stok awal $qty';
    } else if (sumber == 'restock') {
      base = 'Restok';
      detail = perubahan >= 0 ? '+$qty' : '-$qty';
    } else if (sumber == 'pos') {
      base = 'Penjualan';
      detail = qty == 0 ? '' : '-$qty';
    } else if (sumber == 'edit' && catatan.toLowerCase() == 'hapus produk') {
      base = 'Hapus produk';
      detail = qty == 0 ? '' : '-$qty';
    } else if (sumber == 'edit') {
      base = 'Penyesuaian stok';
      detail = qty == 0 ? '' : (perubahan >= 0 ? '+$qty' : '-$qty');
    } else {
      base = _labelSumber(sumber);
      detail =
          qty == 0 ? _labelTipe(tipe) : (perubahan >= 0 ? '+$qty' : '-$qty');
    }

    final parts = <String>[base];
    if (detail.isNotEmpty) {
      parts.add(detail);
    }
    if (invoice.isNotEmpty) {
      parts.add('Inv $invoice');
    }
    if (catatan.isNotEmpty && catatan.toLowerCase() != 'hapus produk') {
      parts.add(catatan);
    }
    return parts.join(' | ');
  }

  Widget _badge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _formatRupiahSimple(int value) {
    final absValue = value.abs();
    final str = absValue.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      final indexFromEnd = str.length - i;
      buffer.write(str[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }
    final prefix = value < 0 ? '-Rp ' : 'Rp ';
    return '$prefix${buffer.toString()}';
  }

  Widget _cell({
    required double width,
    required Widget child,
    required BuildContext context,
    required bool isLast,
    TextAlign align = TextAlign.left,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          right: isLast
              ? BorderSide.none
              : BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          fontSize: 13,
        ),
        textAlign: align,
        child: child,
      ),
    );
  }

  Widget _row({
    required BuildContext context,
    required List<Widget> cells,
    required List<double> widths,
    required bool isHeader,
    required int? rowIndex,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEven = rowIndex != null && rowIndex.isEven;
    final isHover = rowIndex != null && _hoveredIndex == rowIndex;
    final baseColor = isHeader
        ? (isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF7F4EF))
        : isEven
            ? (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF4F1EC))
            : (isDark ? const Color(0xFF232323) : const Color(0xFFF7F4EF));
    final hoverColor = scheme.primary.withValues(alpha: 0.08);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: isHover ? hoverColor : baseColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: List.generate(cells.length, (index) {
          return _cell(
            width: widths[index],
            child: cells[index],
            context: context,
            isLast: index == cells.length - 1,
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.logs.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1F1F1F)
              : const Color(0xFFF1EFEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Text(
          'Belum ada data log pada rentang ini',
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    final sorted = List<Map<String, dynamic>>.from(widget.logs)
      ..sort((a, b) {
        final aTs = a['waktu'];
        final bTs = b['waktu'];
        final aDate = aTs is Timestamp ? aTs.toDate() : DateTime(1970);
        final bDate = bTs is Timestamp ? bTs.toDate() : DateTime(1970);
        return bDate.compareTo(aDate);
      });
    var totalModalAll = 0;
    var totalLabaAll = 0;
    for (final log in widget.logs) {
      final id = log['produk_id'];
      final info = id is String
          ? (widget.produkMap != null ? widget.produkMap![id] : null)
          : null;
      final tipe = (log['tipe'] ?? '').toString().toLowerCase();
      if (tipe == 'harga') continue;
      final perubahan = (log['perubahan'] ?? 0) as int;
      final qty = perubahan.abs();
      if (qty == 0) continue;
      final modalRaw = log['harga_modal'];
      final jualRaw = log['harga_jual'];
      final modal = modalRaw is int ? modalRaw : (info?.hargaModal ?? 0);
      final jual = jualRaw is int ? jualRaw : (info?.hargaJual ?? 0);
      final labaUnit = jual - modal;
      totalModalAll += modal * qty;
      totalLabaAll += labaUnit * qty;
    }

    const widths = [
      60.0,
      170.0,
      140.0,
      160.0,
      200.0,
      140.0,
      140.0,
      100.0,
      110.0,
      120.0,
      90.0,
      120.0,
      130.0,
      130.0,
      160.0,
      140.0,
    ];
    final tableBaseWidth = widths.reduce((a, b) => a + b);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = math.max(tableBaseWidth, constraints.maxWidth);
        final adjustedWidths = List<double>.from(widths);
        final extra = tableWidth - tableBaseWidth;
        if (extra > 0) {
          adjustedWidths[3] += extra;
        }
        final scheme = Theme.of(context).colorScheme;
        final dragDevices = {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        };
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1F1F1F)
                : const Color(0xFFF1EFEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: dragDevices,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  children: [
                    _row(
                      context: context,
                      cells: const [
                        Text('No',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        Text('Tanggal',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        Text('User',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        Text('Invoice',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        Text('Produk',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        Text('Kategori',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        Text('Barcode',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        Text('Perubahan',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        Text('Stok Akhir',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        Text('Harga Modal',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        Text('Laba %',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        Text('Laba/Unit',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        Text('Modal Total',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        Text('Laba Total',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        Text('Aktivitas',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                      widths: adjustedWidths,
                      isHeader: true,
                      rowIndex: null,
                    ),
                    ...sorted.asMap().entries.map((entry) {
                      final no = entry.key + 1;
                      final log = entry.value;
                      final ts = log['waktu'];
                      final dt = ts is Timestamp ? ts.toDate() : DateTime(1970);
                      final id = log['produk_id'];
                      final namaProduk = log['nama_produk'];
                      final info = id is String
                          ? (widget.produkMap != null
                              ? widget.produkMap![id]
                              : null)
                          : null;
                      final nama =
                          (namaProduk ?? info?.nama ?? 'Produk').toString();
                      final kategori = (info?.kategori ?? 'Lainnya').toString();
                      final barcode = (info?.barcode ?? '-').toString();
                      final perubahan = (log['perubahan'] ?? 0) as int;
                      final stokAkhir = (log['stok_akhir'] ?? 0) as int;
                      final sumber =
                          (log['sumber'] ?? '').toString().toLowerCase();
                      final tipe = (log['tipe'] ?? '').toString().toLowerCase();
                      final invoiceRaw = log['refId'] ?? log['transaksiId'];
                      final invoice = sumber == 'pos' && invoiceRaw != null
                          ? invoiceRaw.toString()
                          : '-';
                      final isHarga = tipe == 'harga';
                      final labelPerubahan = isHarga
                          ? '-'
                          : (perubahan >= 0
                              ? '+$perubahan'
                              : perubahan.toString());
                      final qty = isHarga ? 0 : perubahan.abs();
                      final modalRaw = log['harga_modal'];
                      final jualRaw = log['harga_jual'];
                      final hasPrice =
                          modalRaw is int || jualRaw is int || info != null;
                      final modal =
                          modalRaw is int ? modalRaw : (info?.hargaModal ?? 0);
                      final jual =
                          jualRaw is int ? jualRaw : (info?.hargaJual ?? 0);
                      final labaUnit = jual - modal;
                      final modalTotal = modal * qty;
                      final labaTotal = labaUnit * qty;
                      final labaPercent = hasPrice && modal > 0
                          ? '${((labaUnit / modal) * 100).toStringAsFixed(0)}%'
                          : '-';
                      final perubahanColor = perubahan >= 0
                          ? const Color(0xFF2A9D6F)
                          : const Color(0xFFD06C64);
                      final actorName = _activityActorLabel(log);
                      final aktivitas = _buildAktivitasStokDetail(log);
                      return MouseRegion(
                        onEnter: (_) =>
                            setState(() => _hoveredIndex = entry.key),
                        onExit: (_) => setState(() => _hoveredIndex = null),
                        child: _row(
                          context: context,
                          cells: [
                            Text(no.toString(), textAlign: TextAlign.center),
                            Text(_formatTanggalJam(dt)),
                            Text(actorName),
                            Text(invoice),
                            Text(nama),
                            Text(kategori),
                            Text(barcode),
                            Text(
                              labelPerubahan,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: perubahanColor,
                              ),
                            ),
                            Text(stokAkhir.toString(),
                                textAlign: TextAlign.center),
                            Text(
                              hasPrice ? _formatRupiahSimple(modal) : '-',
                              textAlign: TextAlign.center,
                            ),
                            Text(labaPercent, textAlign: TextAlign.center),
                            Text(
                              hasPrice ? _formatRupiahSimple(labaUnit) : '-',
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              isHarga ? '-' : _formatRupiahSimple(modalTotal),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              isHarga ? '-' : _formatRupiahSimple(labaTotal),
                              textAlign: TextAlign.center,
                            ),
                            Text(aktivitas),
                          ],
                          widths: adjustedWidths,
                          isHeader: false,
                          rowIndex: entry.key,
                        ),
                      );
                    }),
                    _row(
                      context: context,
                      cells: [
                        const Text(''),
                        const Text(''),
                        const Text(''),
                        const Text(''),
                        const Text(
                          'TOTAL',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Text(''),
                        const Text(''),
                        const Text(''),
                        const Text(''),
                        const Text(''),
                        const Text(''),
                        Text(
                          _formatRupiahSimple(totalModalAll),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                        Text(
                          _formatRupiahSimple(totalLabaAll),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                        const Text(''),
                        const Text(''),
                      ],
                      widths: adjustedWidths,
                      isHeader: false,
                      rowIndex: null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MergedTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final List<Map<String, dynamic>> activityLogs;
  final Map<String, _ProdukInfo>? produkMap;

  const _MergedTimeline({
    required this.logs,
    required this.activityLogs,
    this.produkMap,
  });

  DateTime _resolveTime(Map<String, dynamic> item) {
    final kind = item['kind'];
    final data = item['data'];
    if (kind == 'aktivitas' && data is Map) {
      final ts = data['created_at'];
      return ts is Timestamp ? ts.toDate() : DateTime(1970);
    }
    if (data is Map) {
      final ts = data['waktu'];
      return ts is Timestamp ? ts.toDate() : DateTime(1970);
    }
    return DateTime(1970);
  }

  String _formatTanggalJam(DateTime dt) {
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = bulan[dt.month - 1];
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day $month $year $hour:$minute';
  }

  String _labelAksiActivity(String value) {
    switch (value) {
      case 'produk_tambah':
        return 'Tambah produk';
      case 'produk_hapus':
        return 'Hapus produk';
      case 'produk_ubah':
        return 'Ubah produk';
      case 'stok_ubah':
        return 'Ubah stok';
      case 'harga_ubah':
        return 'Ubah harga';
      case 'transaksi':
        return 'Transaksi';
      case 'login':
        return 'Login';
      case 'logout':
        return 'Logout';
      case 'user_create':
        return 'Buat user';
      case 'user_update_role':
        return 'Ubah role user';
      case 'user_update_email':
        return 'Ubah email user';
      case 'user_update_nickname':
        return 'Ubah nama user';
      case 'user_delete':
        return 'Hapus user';
      case 'user_disable':
        return 'Nonaktifkan user';
      case 'user_enable':
        return 'Aktifkan user';
      case 'reset_password':
        return 'Reset password';
      case 'role_default_update':
        return 'Ubah default role';
      case 'user_access_override':
        return 'Akses khusus user';
      default:
        return value.isEmpty ? '-' : value;
    }
  }

  String _labelSumber(String raw) {
    switch (raw) {
      case 'init':
        return 'Produk Baru';
      case 'restock':
        return 'Restok';
      case 'pos':
        return 'Penjualan';
      case 'edit':
        return 'Penyesuaian';
      default:
        return 'Lainnya';
    }
  }

  String _labelKategoriActivity(String value) {
    switch (value) {
      case 'produk':
        return 'Produk';
      case 'stok':
        return 'Stok';
      case 'transaksi':
        return 'Transaksi';
      case 'user':
        return 'User';
      case 'harga':
        return 'Harga';
      case 'password':
        return 'Password';
      default:
        return value.isEmpty ? '-' : value;
    }
  }

  String _buildDetailActivity(Map<String, dynamic> log) {
    final parts = <String>[];
    final target = (log['target_label'] ?? '').toString().trim();
    if (target.isNotEmpty) {
      parts.add(target);
    }
    final meta = log['meta'];
    if (meta is Map) {
      if (meta['total'] != null) {
        parts.add('Total: Rp ${meta['total']}');
      }
      if (meta['items'] != null) {
        parts.add('Item: ${meta['items']}');
      }
      if (meta['stok_lama'] != null && meta['stok_baru'] != null) {
        parts.add('Stok ${meta['stok_lama']} -> ${meta['stok_baru']}');
      }
      if (meta['harga_lama'] != null && meta['harga_baru'] != null) {
        parts.add('Harga ${meta['harga_lama']} -> ${meta['harga_baru']}');
      }
      if (meta['role_baru'] != null) {
        parts.add('Role: ${meta['role_baru']}');
      }
      if (meta['email_baru'] != null) {
        parts.add('Email: ${meta['email_baru']}');
      }
    }
    return parts.isEmpty ? '-' : parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final merged = <Map<String, dynamic>>[
      for (final log in logs) {'kind': 'stok', 'data': log},
      for (final log in activityLogs) {'kind': 'aktivitas', 'data': log},
    ]..sort((a, b) => _resolveTime(b).compareTo(_resolveTime(a)));

    if (merged.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(child: Text('Belum ada data log pada rentang ini')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: merged.length,
      separatorBuilder: (_, __) => const Divider(height: 20),
      itemBuilder: (context, index) {
        final item = merged[index];
        final kind = item['kind'];
        final data = item['data'];
        final time = _formatTanggalJam(_resolveTime(item));
        final scheme = Theme.of(context).colorScheme;

        if (kind == 'aktivitas' && data is Map<String, dynamic>) {
          final action = _labelAksiActivity((data['action'] ?? '').toString());
          final category = _labelKategoriActivity(
            (data['category'] ?? '').toString().toLowerCase(),
          );
          final detail = _buildDetailActivity(data);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$category • $time',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        if (data is! Map<String, dynamic>) {
          return const SizedBox.shrink();
        }

        final log = data;
        final id = log['produk_id'];
        final info = id is String ? (produkMap?[id]) : null;
        final namaProduk =
            (log['nama_produk'] ?? info?.nama ?? 'Produk').toString();
        final perubahan = (log['perubahan'] ?? 0) as int;
        final sumber = (log['sumber'] ?? '').toString().toLowerCase();
        final labelSumber = _labelSumber(sumber);
        final labelPerubahan =
            perubahan >= 0 ? '+$perubahan' : perubahan.toString();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: perubahan >= 0
                    ? const Color(0xFF2A9D6F)
                    : const Color(0xFFD06C64),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    namaProduk,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$labelSumber • $labelPerubahan',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProdukInfo {
  final String nama;
  final String kategori;
  final String barcode;
  final int hargaModal;
  final int hargaJual;

  const _ProdukInfo({
    required this.nama,
    required this.kategori,
    required this.barcode,
    required this.hargaModal,
    required this.hargaJual,
  });
}

class _RingkasanCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _RingkasanCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return HoverCard(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: _luxShadow(context),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTight = constraints.maxWidth < 140;
            final info = Column(
              crossAxisAlignment: isTight
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment:
                      isTight ? WrapAlignment.center : WrapAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Hari ini',
                        style: TextStyle(
                          fontSize: 10,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: 0.65,
                    minHeight: 6,
                    backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                    color: color,
                  ),
                ),
              ],
            );

            final iconChip = Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.45)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 26),
            );

            if (isTight) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconChip,
                  const SizedBox(height: 12),
                  info,
                ],
              );
            }

            return Row(
              children: [
                iconChip,
                const SizedBox(width: 12),
                Expanded(child: info),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final String tag;

  const _ChartCard({
    required this.title,
    required this.child,
    this.tag = '30 hari',
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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

BoxDecoration _panelDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Theme.of(context).dividerColor),
    boxShadow: _luxShadow(context),
  );
}
