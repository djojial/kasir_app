import 'dart:ui' show PointerDeviceKind;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/ui/interactive_widgets.dart';
import '../../database/services/firestore_service.dart';
import '../../utils/pdf_download.dart';
import '../../utils/pdf_save.dart';

String _activityFormatRupiahSimple(int value) {
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

String _activityRoleLabel(String role) {
  switch (role) {
    case 'admin':
      return 'Admin';
    case 'owner':
      return 'Owner';
    case 'operator':
      return 'Operator';
    default:
      return role.isEmpty ? '-' : role;
  }
}

String _activityLabelAksi(String value) {
  switch (value) {
    case 'produk_tambah':
      return 'Tambah produk';
    case 'produk_hapus':
      return 'Hapus produk';
    case 'produk_ubah':
      return 'Ubah produk';
    case 'produk_edit':
      return 'Edit produk';
    case 'stok_ubah':
      return 'Ubah stok';
    case 'harga_ubah':
      return 'Ubah harga';
    case 'diskon_ubah':
      return 'Ubah diskon grosir';
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
    case 'dashboard_reset':
      return 'Reset dashboard';
    default:
      return value.isEmpty ? '-' : value;
  }
}

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

String _activityBuildDetail(Map<String, dynamic> log) {
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
    if (meta['reset_at_label'] != null) {
      parts.add('Reset: ${meta['reset_at_label']}');
    }
    if (meta['nama_lama'] != null && meta['nama_baru'] != null) {
      parts.add('Nama ${meta['nama_lama']} -> ${meta['nama_baru']}');
    }
  }
  return parts.isEmpty ? '-' : parts.join(', ');
}

String? _activityInvoiceFromTimestampId(String rawId) {
  final id = rawId.trim();
  final millis = int.tryParse(id);
  if (millis == null || id.length < 11) return null;
  try {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final date =
        '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
    final tail = id.length > 4 ? id.substring(id.length - 4) : id;
    return 'INV-$date-$tail';
  } catch (_) {
    return null;
  }
}

String _activityResolveDetailId(Map<String, dynamic> log) {
  final action = (log['action'] ?? '').toString();
  final targetLabel = (log['target_label'] ?? '').toString().trim();
  final targetId = (log['target_id'] ?? '').toString().trim();
  final meta = log['meta'];

  if (action == 'transaksi') {
    if (targetLabel.isNotEmpty) {
      if (targetLabel.toUpperCase().startsWith('INV-')) return targetLabel;
      final invoiceFromLabel = _activityInvoiceFromTimestampId(targetLabel);
      if (invoiceFromLabel != null) return invoiceFromLabel;
      return targetLabel;
    }
    if (meta is Map) {
      final invoiceMeta = (meta['invoice'] ?? '').toString().trim();
      if (invoiceMeta.isNotEmpty) return invoiceMeta;
      final transaksiIdMeta = (meta['transaksi_id'] ?? '').toString().trim();
      final invoiceFromMeta = _activityInvoiceFromTimestampId(transaksiIdMeta);
      if (invoiceFromMeta != null) return invoiceFromMeta;
    }
    if (targetId.isNotEmpty) {
      final invoiceFromTargetId = _activityInvoiceFromTimestampId(targetId);
      if (invoiceFromTargetId != null) return invoiceFromTargetId;
      return targetId;
    }
  }

  if (targetId.isNotEmpty) return targetId;
  if (meta is Map) {
    for (final key in ['transaksi_id', 'invoice', 'ref_id', 'id']) {
      final val = meta[key];
      if (val != null && val.toString().trim().isNotEmpty) {
        return val.toString();
      }
    }
  }
  return '-';
}

String _activityBuildKeterangan(Map<String, dynamic> log) {
  final action = (log['action'] ?? '').toString();
  final targetLabel = (log['target_label'] ?? '').toString().trim();
  final meta = log['meta'];
  switch (action) {
    case 'produk_edit':
      return targetLabel.isEmpty
          ? 'Mengubah produk'
          : 'Mengubah produk $targetLabel';
    case 'produk_ubah':
      if (meta is Map &&
          meta['nama_lama'] != null &&
          meta['nama_baru'] != null) {
        return 'Mengubah produk dari ${meta['nama_lama']} ke ${meta['nama_baru']}';
      }
      return targetLabel.isEmpty
          ? 'Mengubah produk'
          : 'Mengubah produk $targetLabel';
    case 'stok_ubah':
      if (meta is Map &&
          meta['stok_lama'] != null &&
          meta['stok_baru'] != null) {
        return 'Mengubah stok $targetLabel dari ${meta['stok_lama']} ke ${meta['stok_baru']}';
      }
      return targetLabel.isEmpty
          ? 'Mengubah stok'
          : 'Mengubah stok $targetLabel';
    case 'harga_ubah':
      if (meta is Map) {
        final parts = <String>['Mengubah harga'];
        if (targetLabel.isNotEmpty) {
          parts.add(targetLabel);
        }
        if (meta['harga_lama'] != null && meta['harga_baru'] != null) {
          parts.add('jual ${meta['harga_lama']} -> ${meta['harga_baru']}');
        }
        if (meta['harga_modal_lama'] != null &&
            meta['harga_modal_baru'] != null) {
          parts.add(
            'modal ${meta['harga_modal_lama']} -> ${meta['harga_modal_baru']}',
          );
        }
        if (meta['laba_persen_lama'] != null &&
            meta['laba_persen_baru'] != null) {
          parts.add(
            'laba ${meta['laba_persen_lama']}% -> ${meta['laba_persen_baru']}%',
          );
        }
        return parts.join(' ');
      }
      return targetLabel.isEmpty
          ? 'Mengubah harga'
          : 'Mengubah harga $targetLabel';
    case 'diskon_ubah':
      if (meta is Map) {
        final parts = <String>['Mengubah diskon grosir'];
        if (targetLabel.isNotEmpty) {
          parts.add(targetLabel);
        }
        if (meta['diskon_min_qty_lama'] != null &&
            meta['diskon_min_qty_baru'] != null) {
          parts.add(
            'min ${meta['diskon_min_qty_lama']} -> ${meta['diskon_min_qty_baru']}',
          );
        }
        if (meta['diskon_harga_lama'] != null &&
            meta['diskon_harga_baru'] != null) {
          final lama = meta['diskon_harga_lama'];
          final baru = meta['diskon_harga_baru'];
          if (lama is int && baru is int) {
            parts.add(
              'harga ${_activityFormatRupiahSimple(lama)} -> ${_activityFormatRupiahSimple(baru)}',
            );
          } else {
            parts.add('harga $lama -> $baru');
          }
        }
        if (meta['diskon_persen_lama'] != null &&
            meta['diskon_persen_baru'] != null) {
          parts.add(
            'persen ${meta['diskon_persen_lama']}% -> ${meta['diskon_persen_baru']}%',
          );
        }
        return parts.join(' ');
      }
      return targetLabel.isEmpty
          ? 'Mengubah diskon grosir'
          : 'Mengubah diskon grosir $targetLabel';
    case 'role_default_update':
      final role = (meta is Map ? (meta['role'] ?? targetLabel) : targetLabel)
          .toString();
      return 'Mengubah default role ${_activityRoleLabel(role)}';
    case 'user_create':
      final role = meta is Map ? (meta['role'] ?? '') : '';
      return role.toString().isEmpty
          ? 'Membuat user $targetLabel'
          : 'Membuat user $targetLabel (role ${_activityRoleLabel(role.toString())})';
    case 'user_update_role':
      final before = meta is Map ? (meta['role_lama'] ?? '') : '';
      final after = meta is Map ? (meta['role_baru'] ?? '') : '';
      final base = targetLabel.isEmpty ? 'user' : targetLabel;
      if (before.toString().isNotEmpty && after.toString().isNotEmpty) {
        return 'Mengubah role $base dari ${_activityRoleLabel(before.toString())} ke ${_activityRoleLabel(after.toString())}';
      }
      return 'Mengubah role $base';
    case 'user_update_email':
      final before = meta is Map ? (meta['email_lama'] ?? '') : '';
      final after = meta is Map ? (meta['email_baru'] ?? '') : '';
      if (before.toString().isNotEmpty && after.toString().isNotEmpty) {
        return 'Mengubah email dari $before ke $after';
      }
      return 'Mengubah email $targetLabel';
    case 'user_update_nickname':
      final before = meta is Map ? (meta['nama_lama'] ?? '') : '';
      final after = meta is Map ? (meta['nama_baru'] ?? '') : '';
      if (before.toString().isNotEmpty && after.toString().isNotEmpty) {
        return 'Mengubah nama dari $before ke $after';
      }
      return 'Mengubah nama $targetLabel';
    case 'user_delete':
      return targetLabel.isEmpty
          ? 'Menghapus user'
          : 'Menghapus user $targetLabel';
    case 'user_disable':
      return targetLabel.isEmpty
          ? 'Menonaktifkan user'
          : 'Menonaktifkan user $targetLabel';
    case 'user_enable':
      return targetLabel.isEmpty
          ? 'Mengaktifkan user'
          : 'Mengaktifkan user $targetLabel';
    case 'reset_password':
      return targetLabel.isEmpty
          ? 'Reset password'
          : 'Reset password untuk $targetLabel';
    case 'login':
      final source = meta is Map ? (meta['source'] ?? '').toString() : '';
      if (source == 'auto_session') {
        return targetLabel.isEmpty
            ? 'Masuk aplikasi (sesi tersimpan)'
            : 'Masuk aplikasi (sesi tersimpan) $targetLabel';
      }
      return targetLabel.isEmpty
          ? 'Login aplikasi'
          : 'Login aplikasi $targetLabel';
    case 'logout':
      return targetLabel.isEmpty
          ? 'Logout aplikasi'
          : 'Logout aplikasi $targetLabel';
    case 'dashboard_reset':
      final resetAt = meta is Map
          ? (meta['reset_at_label'] ?? meta['reset_at'] ?? '').toString().trim()
          : '';
      return resetAt.isEmpty
          ? 'Mereset dashboard'
          : 'Mereset dashboard mulai $resetAt';
    case 'transaksi':
      if (meta is Map) {
        final total = meta['total'];
        final items = meta['items'];
        final diskon = meta['diskon'] ??
            meta['diskon_rp'] ??
            meta['diskon_amount'] ??
            meta['discount'];
        final diskonPersen = meta['diskon_persen'] ??
            meta['diskon_percent'] ??
            meta['discount_percent'];
        final totalText =
            total is int ? _activityFormatRupiahSimple(total) : null;
        final itemsText = items != null ? '$items item' : null;
        final diskonText =
            diskon is int ? _activityFormatRupiahSimple(diskon) : null;
        final diskonPersenText = diskonPersen != null ? '$diskonPersen%' : null;
        final parts = <String>[
          if (targetLabel.isNotEmpty) 'Transaksi $targetLabel' else 'Transaksi',
          if (totalText != null) 'total $totalText',
          if (itemsText != null) itemsText,
          if (diskonText != null) 'diskon $diskonText',
          if (diskonPersenText != null) 'diskon $diskonPersenText',
        ];
        return parts.join(' ');
      }
      return targetLabel.isNotEmpty ? 'Transaksi $targetLabel' : 'Transaksi';
    case 'produk_tambah':
      return targetLabel.isEmpty
          ? 'Menambah produk'
          : 'Menambah produk $targetLabel';
    case 'produk_hapus':
      return targetLabel.isEmpty
          ? 'Menghapus produk'
          : 'Menghapus produk $targetLabel';
    default:
      final detail = _activityBuildDetail(log);
      if (detail != '-') return detail;
      final label = _activityLabelAksi(action);
      return label == '-' ? '-' : label;
  }
}

class HalamanAktivitasSistem extends StatelessWidget {
  const HalamanAktivitasSistem({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AktivitasSistemBody();
  }
}

class _AktivitasSistemBody extends StatefulWidget {
  const _AktivitasSistemBody();

  @override
  State<_AktivitasSistemBody> createState() => _AktivitasSistemBodyState();
}

class _AktivitasSistemBodyState extends State<_AktivitasSistemBody> {
  final firestore = FirestoreService();
  late int _selectedMonth;
  late int _selectedYear;
  bool _purgeDone = false;
  bool _exporting = false;

  static const _bulan = [
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _purgeOld();
  }

  Future<void> _purgeOld() async {
    if (_purgeDone) return;
    _purgeDone = true;
    try {
      await firestore.purgeOldActivityLogs();
    } catch (_) {}
  }

  List<Map<String, dynamic>> _filterMonthly(
    List<Map<String, dynamic>> logs,
  ) {
    return logs.where((log) {
      final ts = log['created_at'] ?? log['waktu'];
      if (ts is! Timestamp) return false;
      final dt = ts.toDate();
      return dt.month == _selectedMonth && dt.year == _selectedYear;
    }).toList();
  }

  Future<void> _showMonthMenu(BuildContext context) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final box = context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<int>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<int>(
          padding: EdgeInsets.zero,
          child: _MonthGridMenu(
            labels: _bulan,
            selected: _selectedMonth,
            onSelected: (value) => Navigator.pop(context, value),
          ),
        ),
      ],
    );
    if (selected != null && mounted) {
      setState(() => _selectedMonth = selected);
    }
  }

  Future<void> _exportPdf(List<Map<String, dynamic>> logs) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
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
      final headers = ['Waktu', 'User', 'Mode', 'Keterangan', 'Detail'];
      final rows = logs.map((log) {
        final ts = log['created_at'] ?? log['waktu'];
        final dt = ts is Timestamp ? ts.toDate() : DateTime(1970);
        final waktu =
            '${dt.day.toString().padLeft(2, '0')} ${_bulan[dt.month - 1]} ${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        final user = _activityActorLabel(log);
        final mode = (log['action'] ?? '-').toString();
        final keterangan = _activityBuildKeterangan(log);
        final detail = _activityResolveDetailId(log);
        return [waktu, user, mode, keterangan, detail];
      }).toList();
      final columnWidths = <int, pw.TableColumnWidth>{
        0: const pw.FixedColumnWidth(68),
        1: const pw.FixedColumnWidth(48),
        2: const pw.FixedColumnWidth(60),
        3: const pw.FixedColumnWidth(190),
        4: const pw.FixedColumnWidth(70),
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
                      'Aktivitas Sistem',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Periode: ${_bulan[_selectedMonth - 1]} $_selectedYear',
                    ),
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
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      final filename =
          'aktivitas_sistem_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.pdf';
      if (kIsWeb) {
        await savePdfBytesWeb(bytes, filename);
      } else {
        await savePdfToDownloads(bytes, filename);
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 520;
    return Padding(
      padding: EdgeInsets.all(isNarrow ? 16 : 24),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: firestore.streamActivityLogs(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(
              child: Text('Gagal memuat aktivitas. Cek izin atau indeks.'),
            );
          }
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final logs = List<Map<String, dynamic>>.from(snap.data ?? const [])
            ..sort((a, b) {
              final aTs = a['waktu'];
              final bTs = b['waktu'];
              final aDate = aTs is Timestamp ? aTs.toDate() : DateTime(1970);
              final bDate = bTs is Timestamp ? bTs.toDate() : DateTime(1970);
              return bDate.compareTo(aDate);
            });
          final filtered = _filterMonthly(logs);

          final monthPicker = Builder(
            builder: (context) => InkWell(
              onTap: () => _showMonthMenu(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _bulan[_selectedMonth - 1],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.expand_more, size: 18),
                  ],
                ),
              ),
            ),
          );
          final exportButton = TextButton.icon(
            onPressed: _exporting ? null : () => _exportPdf(filtered),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_exporting ? 'Menyiapkan...' : 'Export'),
          );
          final countBadge = Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${filtered.length} aktivitas',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
                  if (isNarrow)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aktivitas Sistem',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            monthPicker,
                            exportButton,
                            countBadge,
                          ],
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Text(
                          'Aktivitas Sistem',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        monthPicker,
                        const SizedBox(width: 12),
                        exportButton,
                        const SizedBox(width: 12),
                        countBadge,
                      ],
                    ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const SizedBox(
                      height: 160,
                      child: Center(child: Text('Belum ada aktivitas')),
                    )
                  else
                    Expanded(
                      child: _ActivityTable(logs: filtered),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActivityTable extends StatefulWidget {
  final List<Map<String, dynamic>> logs;

  const _ActivityTable({required this.logs});

  @override
  State<_ActivityTable> createState() => _ActivityTableState();
}

class _MonthGridMenu extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  const _MonthGridMenu({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const columns = 6;
    const chipWidth = 32.0;
    const spacing = 6.0;
    final gridWidth = (chipWidth * columns) + (spacing * (columns - 1));
    return SizedBox(
      width: gridWidth,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < labels.length; i++)
              SizedBox(
                width: chipWidth,
                child: InkWell(
                  onTap: () => onSelected(i + 1),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i + 1 == selected
                          ? scheme.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: i + 1 == selected
                            ? scheme.primary.withValues(alpha: 0.4)
                            : scheme.outline.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: i + 1 == selected
                            ? scheme.onSurface
                            : scheme.onSurface.withValues(alpha: 0.7),
                      ),
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

class _ActivityTableState extends State<_ActivityTable> {
  int? _hoveredIndex;

  static const _widths = [
    170.0, // Waktu
    160.0, // User
    160.0, // Mode
    360.0, // Keterangan
    180.0, // Detail
  ];

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
      case 'dashboard_reset':
        return 'Reset dashboard';
      default:
        return value.isEmpty ? '-' : value;
    }
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

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'owner':
        return 'Owner';
      case 'operator':
        return 'Operator';
      default:
        return role.isEmpty ? '-' : role;
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
      if (meta['reset_at_label'] != null) {
        parts.add('Reset: ${meta['reset_at_label']}');
      }
      if (meta['nama_lama'] != null && meta['nama_baru'] != null) {
        parts.add('Nama ${meta['nama_lama']} -> ${meta['nama_baru']}');
      }
    }
    return parts.isEmpty ? '-' : parts.join(', ');
  }

  String _buildKeterangan(Map<String, dynamic> log) {
    final action = (log['action'] ?? '').toString();
    final targetLabel = (log['target_label'] ?? '').toString().trim();
    final meta = log['meta'];
    switch (action) {
      case 'produk_edit':
        return targetLabel.isEmpty
            ? 'Mengubah produk'
            : 'Mengubah produk $targetLabel';
      case 'produk_ubah':
        if (meta is Map &&
            meta['nama_lama'] != null &&
            meta['nama_baru'] != null) {
          return 'Mengubah produk dari ${meta['nama_lama']} ke ${meta['nama_baru']}';
        }
        return targetLabel.isEmpty
            ? 'Mengubah produk'
            : 'Mengubah produk $targetLabel';
      case 'stok_ubah':
        if (meta is Map &&
            meta['stok_lama'] != null &&
            meta['stok_baru'] != null) {
          return 'Mengubah stok $targetLabel dari ${meta['stok_lama']} ke ${meta['stok_baru']}';
        }
        return targetLabel.isEmpty
            ? 'Mengubah stok'
            : 'Mengubah stok $targetLabel';
      case 'harga_ubah':
        if (meta is Map) {
          final parts = <String>['Mengubah harga'];
          if (targetLabel.isNotEmpty) {
            parts.add(targetLabel);
          }
          if (meta['harga_lama'] != null && meta['harga_baru'] != null) {
            parts.add(
              'jual ${meta['harga_lama']} -> ${meta['harga_baru']}',
            );
          }
          if (meta['harga_modal_lama'] != null &&
              meta['harga_modal_baru'] != null) {
            parts.add(
              'modal ${meta['harga_modal_lama']} -> ${meta['harga_modal_baru']}',
            );
          }
          if (meta['laba_persen_lama'] != null &&
              meta['laba_persen_baru'] != null) {
            parts.add(
              'laba ${meta['laba_persen_lama']}% -> ${meta['laba_persen_baru']}%',
            );
          }
          return parts.join(' ');
        }
        return targetLabel.isEmpty
            ? 'Mengubah harga'
            : 'Mengubah harga $targetLabel';
      case 'diskon_ubah':
        if (meta is Map) {
          final parts = <String>['Mengubah diskon grosir'];
          if (targetLabel.isNotEmpty) {
            parts.add(targetLabel);
          }
          if (meta['diskon_min_qty_lama'] != null &&
              meta['diskon_min_qty_baru'] != null) {
            parts.add(
              'min ${meta['diskon_min_qty_lama']} -> ${meta['diskon_min_qty_baru']}',
            );
          }
          if (meta['diskon_harga_lama'] != null &&
              meta['diskon_harga_baru'] != null) {
            final lama = meta['diskon_harga_lama'];
            final baru = meta['diskon_harga_baru'];
            if (lama is int && baru is int) {
              parts.add(
                'harga ${_formatRupiahSimple(lama)} -> ${_formatRupiahSimple(baru)}',
              );
            } else {
              parts.add('harga $lama -> $baru');
            }
          }
          if (meta['diskon_persen_lama'] != null &&
              meta['diskon_persen_baru'] != null) {
            parts.add(
              'persen ${meta['diskon_persen_lama']}% -> ${meta['diskon_persen_baru']}%',
            );
          }
          return parts.join(' ');
        }
        return targetLabel.isEmpty
            ? 'Mengubah diskon grosir'
            : 'Mengubah diskon grosir $targetLabel';
      case 'role_default_update':
        final role = (meta is Map ? (meta['role'] ?? targetLabel) : targetLabel)
            .toString();
        return 'Mengubah default role ${_roleLabel(role)}';
      case 'user_create':
        final role = meta is Map ? (meta['role'] ?? '') : '';
        return role.toString().isEmpty
            ? 'Membuat user $targetLabel'
            : 'Membuat user $targetLabel (role ${_roleLabel(role.toString())})';
      case 'user_update_role':
        final before = meta is Map ? (meta['role_lama'] ?? '') : '';
        final after = meta is Map ? (meta['role_baru'] ?? '') : '';
        final base = targetLabel.isEmpty ? 'user' : targetLabel;
        if (before.toString().isNotEmpty && after.toString().isNotEmpty) {
          return 'Mengubah role $base dari ${_roleLabel(before.toString())} ke ${_roleLabel(after.toString())}';
        }
        return 'Mengubah role $base';
      case 'user_update_email':
        final before = meta is Map ? (meta['email_lama'] ?? '') : '';
        final after = meta is Map ? (meta['email_baru'] ?? '') : '';
        if (before.toString().isNotEmpty && after.toString().isNotEmpty) {
          return 'Mengubah email dari $before ke $after';
        }
        return 'Mengubah email $targetLabel';
      case 'user_update_nickname':
        final before = meta is Map ? (meta['nama_lama'] ?? '') : '';
        final after = meta is Map ? (meta['nama_baru'] ?? '') : '';
        if (before.toString().isNotEmpty && after.toString().isNotEmpty) {
          return 'Mengubah nama dari $before ke $after';
        }
        return 'Mengubah nama $targetLabel';
      case 'user_delete':
        return targetLabel.isEmpty
            ? 'Menghapus user'
            : 'Menghapus user $targetLabel';
      case 'user_disable':
        return targetLabel.isEmpty
            ? 'Menonaktifkan user'
            : 'Menonaktifkan user $targetLabel';
      case 'user_enable':
        return targetLabel.isEmpty
            ? 'Mengaktifkan user'
            : 'Mengaktifkan user $targetLabel';
      case 'reset_password':
        return targetLabel.isEmpty
            ? 'Reset password'
            : 'Reset password untuk $targetLabel';
      case 'login':
        final source = meta is Map ? (meta['source'] ?? '').toString() : '';
        if (source == 'auto_session') {
          return targetLabel.isEmpty
              ? 'Masuk aplikasi (sesi tersimpan)'
              : 'Masuk aplikasi (sesi tersimpan) $targetLabel';
        }
        return targetLabel.isEmpty
            ? 'Login aplikasi'
            : 'Login aplikasi $targetLabel';
      case 'logout':
        return targetLabel.isEmpty
            ? 'Logout aplikasi'
            : 'Logout aplikasi $targetLabel';
      case 'dashboard_reset':
        final resetAt = meta is Map
            ? (meta['reset_at_label'] ?? meta['reset_at'] ?? '')
                .toString()
                .trim()
            : '';
        return resetAt.isEmpty
            ? 'Mereset dashboard'
            : 'Mereset dashboard mulai $resetAt';
      case 'transaksi':
        if (meta is Map) {
          final total = meta['total'];
          final items = meta['items'];
          final diskon = meta['diskon'] ??
              meta['diskon_rp'] ??
              meta['diskon_amount'] ??
              meta['discount'];
          final diskonPersen = meta['diskon_persen'] ??
              meta['diskon_percent'] ??
              meta['discount_percent'];
          final totalText = total is int ? _formatRupiahSimple(total) : null;
          final itemsText = items != null ? '$items item' : null;
          final diskonText = diskon is int ? _formatRupiahSimple(diskon) : null;
          final diskonPersenText =
              diskonPersen != null ? '$diskonPersen%' : null;
          final parts = <String>[
            if (targetLabel.isNotEmpty)
              'Transaksi $targetLabel'
            else
              'Transaksi',
            if (totalText != null) 'total $totalText',
            if (itemsText != null) itemsText,
            if (diskonText != null) 'diskon $diskonText',
            if (diskonPersenText != null) 'diskon $diskonPersenText',
          ];
          return parts.join(' ');
        }
        return targetLabel.isNotEmpty ? 'Transaksi $targetLabel' : 'Transaksi';
      case 'produk_tambah':
        return targetLabel.isEmpty
            ? 'Menambah produk'
            : 'Menambah produk $targetLabel';
      case 'produk_hapus':
        return targetLabel.isEmpty
            ? 'Menghapus produk'
            : 'Menghapus produk $targetLabel';
      case 'produk_ubah':
        return targetLabel.isEmpty
            ? 'Mengubah produk'
            : 'Mengubah produk $targetLabel';
      case 'stok_ubah':
        return targetLabel.isEmpty
            ? 'Mengubah stok'
            : 'Mengubah stok $targetLabel';
      case 'harga_ubah':
        return targetLabel.isEmpty
            ? 'Mengubah harga'
            : 'Mengubah harga $targetLabel';
      case 'user_access_override':
        if (meta is Map && meta['enabled'] != null) {
          final enabled = meta['enabled'] == true;
          return enabled
              ? 'Mengaktifkan akses khusus user'
              : 'Menonaktifkan akses khusus user';
        }
        return 'Mengubah akses khusus user';
      default:
        final detail = _buildDetail(log);
        if (detail != '-') return detail;
        final label = _labelAksi(action);
        return label == '-' ? '-' : label;
    }
  }

  String _resolveDetailId(Map<String, dynamic> log) {
    return _activityResolveDetailId(log);
  }

  Widget _cell({
    double? width,
    required Widget child,
    required BuildContext context,
    required bool isLast,
    required bool isFirst,
    TextAlign align = TextAlign.left,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          left: isFirst
              ? BorderSide(color: Theme.of(context).dividerColor)
              : BorderSide.none,
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
        child: ClipRect(child: child),
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
      child: ClipRect(
        child: Row(
          children: List.generate(cells.length, (index) {
            final isLastCell = index == cells.length - 1;
            final cell = _cell(
              width: isLastCell ? null : widths[index],
              child: cells[index],
              context: context,
              isLast: isLastCell,
              isFirst: index == 0,
            );
            if (isLastCell) {
              return Expanded(child: cell);
            }
            return cell;
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final filteredLogs = <Map<String, dynamic>>[];
        final specificActions = {
          'stok_ubah',
          'harga_ubah',
          'produk_ubah',
          'diskon_ubah',
        };
        final specificTargets = <String>{
          for (final log in widget.logs)
            if (specificActions.contains((log['action'] ?? '').toString()))
              (log['target_id'] ?? '').toString()
        }..removeWhere((e) => e.isEmpty);
        for (final log in widget.logs) {
          final action = (log['action'] ?? '').toString();
          if (action == 'produk_edit') {
            final targetId = (log['target_id'] ?? '').toString();
            if (targetId.isNotEmpty && specificTargets.contains(targetId)) {
              continue;
            }
          }
          filteredLogs.add(log);
        }

        final tableBaseWidth = _widths.reduce((a, b) => a + b);
        final tableWidth = tableBaseWidth > constraints.maxWidth
            ? tableBaseWidth
            : constraints.maxWidth;
        // Compensate for cell borders + outer border to avoid 1-2px overflow.
        final safeWidth = (tableWidth - 8).clamp(0.0, double.infinity);
        final adjustedWidths = List<double>.from(_widths);
        final extra = safeWidth - tableBaseWidth;
        if (extra > 0) {
          adjustedWidths[3] += extra;
        }
        final sumWidths = adjustedWidths.reduce((a, b) => a + b);
        if (sumWidths > safeWidth) {
          final overflow = sumWidths - safeWidth;
          adjustedWidths[adjustedWidths.length - 1] =
              (adjustedWidths.last - overflow).clamp(40.0, double.infinity);
        }
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
          ),
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                width: safeWidth,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      _row(
                        context: context,
                        cells: const [
                          Text('Waktu',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          Text('User',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          Text('Mode',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          Text('Keterangan',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          Text('Detail',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                        widths: adjustedWidths,
                        isHeader: true,
                        rowIndex: null,
                      ),
                      ...filteredLogs.asMap().entries.map((entry) {
                        final log = entry.value;
                        final ts = log['created_at'] ?? log['waktu'];
                        final dt =
                            ts is Timestamp ? ts.toDate() : DateTime(1970);
                        final actorName = _activityActorLabel(log);
                        final actionRaw = (log['action'] ?? '').toString();
                        final keterangan = _buildKeterangan(log);
                        final detailId = _resolveDetailId(log);
                        return MouseRegion(
                          onEnter: (_) =>
                              setState(() => _hoveredIndex = entry.key),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: _row(
                            context: context,
                            cells: [
                              Text(_formatTanggalJam(dt)),
                              Text(
                                actorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                actionRaw.isEmpty ? '-' : actionRaw,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(keterangan),
                              Text(
                                detailId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ],
                            widths: adjustedWidths,
                            isHeader: false,
                            rowIndex: entry.key,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
