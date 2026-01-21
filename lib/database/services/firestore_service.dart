import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/produk_model.dart';
import '../models/transaksi_model.dart';
import '../models/stok_log_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _produkRef => _db.collection('produk');
  CollectionReference get _transaksiRef => _db.collection('transaksi');
  CollectionReference get _transaksiItemRef => _db.collection('transaksi_items');
  CollectionReference get _stokLogRef => _db.collection('stok_log');
  CollectionReference get _usersRef => _db.collection('users');

  bool get _usePolling =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Stream<T> _pollWithCache<T>({
    required Future<T> Function() load,
    Future<T> Function()? loadCache,
    Duration interval = const Duration(seconds: 4),
    bool emitNullCache = false,
  }) async* {
    if (loadCache != null) {
      try {
        final cached = await loadCache();
        if (emitNullCache || cached != null) {
          yield cached;
        }
      } catch (_) {}
    }
    yield await load();
    await for (final _ in Stream<int>.periodic(interval, (tick) => tick)) {
      yield await load();
    }
  }


  // ===============================
  // PRODUK
  // ===============================

  /// TAMBAH PRODUK + LOG STOK AWAL
  Future<void> tambahProdukDenganLog(Produk p, int stokAwal) async {
    final doc = await _produkRef.add(p.toMap());

    final log = StokLog(
      produkId: doc.id,
      namaProduk: p.nama,
      perubahan: stokAwal,
      stokAkhir: stokAwal,
      tipe: 'masuk',
      waktu: Timestamp.now(),
    ).toMap();

    log['sumber'] = 'INIT';
    log['harga_modal'] = p.hargaModal;
    log['harga_jual'] = p.harga;

    await _stokLogRef.add(log);
  }

  /// AMBIL SEMUA PRODUK
  Stream<List<Produk>> ambilSemuaProduk() {
    if (_usePolling) {
      return _pollWithCache(
        load: () async {
          final snap =
              await _produkRef.orderBy('dibuat_pada', descending: true).get();
          return snap.docs
              .map(
                (d) => Produk.dariMap(
                  d.data() as Map<String, dynamic>,
                  d.id,
                ),
              )
              .toList();
        },
        loadCache: () async {
          final snap = await _produkRef
              .orderBy('dibuat_pada', descending: true)
              .get(const GetOptions(source: Source.cache));
          return snap.docs
              .map(
                (d) => Produk.dariMap(
                  d.data() as Map<String, dynamic>,
                  d.id,
                ),
              )
              .toList();
        },
      );
    }
    return _produkRef
        .orderBy('dibuat_pada', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => Produk.dariMap(
                  d.data() as Map<String, dynamic>,
                  d.id,
                ),
              )
              .toList(),
        );
  }

  /// UPDATE PRODUK
  Future<void> updateProduk(Produk p) async {
    if (p.id == null) return;
    final ref = _produkRef.doc(p.id);
    await _db.runTransaction((trx) async {
      final snap = await trx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      final stokLama = (data['stok'] ?? 0) as int;
      final hargaLama = (data['harga'] ?? 0) as int;
      final modalLama = (data['harga_modal'] ?? 0) as int;

      trx.update(ref, p.toMap());

      final now = Timestamp.now();
      if (p.stok != stokLama) {
        final perubahan = p.stok - stokLama;
        final log = StokLog(
          produkId: p.id!,
          namaProduk: p.nama,
          perubahan: perubahan,
          stokAkhir: p.stok,
          tipe: perubahan >= 0 ? 'masuk' : 'keluar',
          waktu: now,
        ).toMap();
        log['sumber'] = 'EDIT';
        log['harga_modal'] = p.hargaModal;
        log['harga_jual'] = p.harga;
        trx.set(_stokLogRef.doc(), log);
      }

      if (p.harga != hargaLama || p.hargaModal != modalLama) {
        final log = {
          'produk_id': p.id,
          'nama_produk': p.nama,
          'perubahan': 0,
          'stok_akhir': p.stok,
          'tipe': 'harga',
          'waktu': now,
          'sumber': 'EDIT',
          'harga_modal': p.hargaModal,
          'harga_jual': p.harga,
          'harga_modal_lama': modalLama,
          'harga_jual_lama': hargaLama,
        };
        trx.set(_stokLogRef.doc(), log);
      }
    });
  }

  /// HAPUS PRODUK
  Future<void> hapusProduk(String id) async {
    await _produkRef.doc(id).delete();
  }

  /// CARI PRODUK BY BARCODE
  Future<Produk?> getProdukByBarcode(String barcode) async {
    final q = await _produkRef
        .where('barcode', isEqualTo: barcode)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;

    final d = q.docs.first;
    return Produk.dariMap(d.data() as Map<String, dynamic>, d.id);
  }

  // ===============================
  // STOK
  // ===============================

  /// CEK STOK (POS)
  Future<bool> cekStokAman({
    required String produkId,
    required int qty,
  }) async {
    final snap = await _produkRef.doc(produkId).get();
    if (!snap.exists) return false;
    return (snap['stok'] as int) >= qty;
  }

  /// TAMBAH STOK + LOG
  Future<void> tambahStokProduk(Produk produk, int jumlah) async {
    final ref = _produkRef.doc(produk.id);

    await _db.runTransaction((trx) async {
      final snap = await trx.get(ref);
      final stokAwal = snap['stok'] as int;
      final stokAkhir = stokAwal + jumlah;

      trx.update(ref, {'stok': stokAkhir});

      final log = StokLog(
        produkId: produk.id!,
        namaProduk: produk.nama,
        perubahan: jumlah,
        stokAkhir: stokAkhir,
        tipe: 'masuk',
        waktu: Timestamp.now(),
      ).toMap();

      log['sumber'] = 'RESTOCK';
      log['harga_modal'] = produk.hargaModal;
      log['harga_jual'] = produk.harga;

      trx.set(_stokLogRef.doc(), log);
    });
  }

  /// KURANGI STOK + LOG (POS / AKUNTANSI)
  Future<void> kurangiStokDanCatatLog({
    required Produk produk,
    required int qty,
    String sumber = 'POS',
    String? refId,
    int? hargaJualOverride,
  }) async {
    final ref = _produkRef.doc(produk.id);

    if (_usePolling) {
      final snap = await ref.get();
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final stokAwal = (data['stok'] ?? 0) as int;
      final stokAkhir = stokAwal - qty;

      await ref.update({'stok': stokAkhir});

      final log = StokLog(
        produkId: produk.id!,
        namaProduk: produk.nama,
        perubahan: -qty,
        stokAkhir: stokAkhir,
        tipe: 'keluar',
        waktu: Timestamp.now(),
      ).toMap();

      log['sumber'] = sumber;
      if (refId != null) {
        log['refId'] = refId;
      }
      log['harga_modal'] = produk.hargaModal;
      log['harga_jual'] = hargaJualOverride ?? produk.harga;

      await _stokLogRef.add(log);
      return;
    }

    await _db.runTransaction((trx) async {
      final snap = await trx.get(ref);
      final stokAwal = snap['stok'] as int;
      final stokAkhir = stokAwal - qty;

      trx.update(ref, {'stok': stokAkhir});

      final log = StokLog(
        produkId: produk.id!,
        namaProduk: produk.nama,
        perubahan: -qty,
        stokAkhir: stokAkhir,
        tipe: 'keluar',
        waktu: Timestamp.now(),
      ).toMap();

      log['sumber'] = sumber;
      if (refId != null) {
        log['refId'] = refId;
      }
      log['harga_modal'] = produk.hargaModal;
      log['harga_jual'] = hargaJualOverride ?? produk.harga;

      trx.set(_stokLogRef.doc(), log);
    });
  }

  // ===============================
  // TRANSAKSI
  // ===============================

  Future<void> simpanTransaksi(Transaksi t) async {
    final batch = _db.batch();

    for (final item in t.items) {
      final itemRef = _transaksiItemRef.doc();
      batch.set(itemRef, {
        'transaksiId': t.id,
        'tanggal': Timestamp.fromDate(t.tanggal),
        'total': t.total,
        'kasir': t.kasir,
        'jenis': t.jenis,
        ...item.toMap(),
      });
    }

    await batch.commit();
  }

  Stream<List<Transaksi>> streamSemuaTransaksi() {
    List<Transaksi> buildList(List<QueryDocumentSnapshot> docs) {
      final Map<String, List<Map<String, dynamic>>> grouped = {};

      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final transaksiId = data['transaksiId'] as String?;
        if (transaksiId == null) continue;

        grouped.putIfAbsent(transaksiId, () => []);
        grouped[transaksiId]!.add(Map<String, dynamic>.from(data));
      }

      final list = grouped.entries.map((entry) {
        final header = entry.value.first;
        final ts = header['tanggal'] as Timestamp?;
        var tanggal = ts?.toDate();
        var total = (header['total'] ?? 0) as int;
        final kasir = (header['kasir'] ?? 'Kasir Utama') as String;
        final jenis = (header['jenis'] ?? 'Penjualan') as String;

        if (tanggal == null) {
          final timestamps = entry.value
              .map((item) => item['dibuatPada'])
              .whereType<Timestamp>()
              .map((t) => t.toDate())
              .toList();
          timestamps.sort();
          tanggal = timestamps.isEmpty ? DateTime.now() : timestamps.first;
        }

        if (total == 0) {
          total = entry.value.fold(0, (sum, item) {
            final produk = item['produk'];
            final hargaProduk =
                produk is Map ? (produk['harga'] ?? 0) as int : 0;
            final hargaOverride = (item['hargaOverride'] ?? 0) as int;
            final harga = hargaOverride > 0 ? hargaOverride : hargaProduk;
            final qty = (item['qty'] ?? 0) as int;
            final diskon = (item['diskonPersen'] ?? 0) as int;
            final subtotal = harga * qty;
            final totalItem =
                diskon > 0 ? (subtotal * (100 - diskon) / 100).round() : subtotal;
            return sum + totalItem;
          });
        }

        return Transaksi(
          id: entry.key,
          tanggal: tanggal,
          total: total,
          kasir: kasir,
          jenis: jenis,
          items: entry.value,
        );
      }).toList();

      list.sort((a, b) => b.tanggal.compareTo(a.tanggal));
      return list;
    }

    if (_usePolling) {
      return _pollWithCache(
        load: () async {
          final snap = await _transaksiItemRef.get();
          return buildList(snap.docs);
        },
        loadCache: () async {
          final snap = await _transaksiItemRef
              .get(const GetOptions(source: Source.cache));
          return buildList(snap.docs);
        },
      );
    }

    return _transaksiItemRef.snapshots().map((snap) => buildList(snap.docs));
  }

  // ===============================
  // DASHBOARD
  // ===============================

  Stream<int> streamJumlahTransaksi() =>
      streamSemuaTransaksi().map((l) => l.length);

  Stream<int> streamItemTerjual() {
    if (_usePolling) {
      return _pollWithCache(
        load: () async {
          final snap = await _transaksiItemRef.get();
          return snap.docs.fold<int>(
            0,
            (sum, doc) => sum + ((doc['qty'] ?? 0) as int),
          );
        },
        loadCache: () async {
          final snap = await _transaksiItemRef
              .get(const GetOptions(source: Source.cache));
          return snap.docs.fold<int>(
            0,
            (sum, doc) => sum + ((doc['qty'] ?? 0) as int),
          );
        },
      );
    }
    return _transaksiItemRef.snapshots().map(
          (snap) => snap.docs.fold<int>(
            0,
            (sum, doc) => sum + ((doc['qty'] ?? 0) as int),
          ),
        );
  }

  Stream<int> streamPendapatan() => streamSemuaTransaksi()
      .map((list) => list.fold(0, (s, t) => s + t.total));

  // ===============================
  // MIGRASI (TRANSAKSI ITEMS)
  // ===============================

  Future<int> migrasiTransaksiItems() async {
    final snap = await _transaksiRef.get();
    var totalMigrated = 0;

    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['migratedItems'] == true) continue;

      final rawItems = data['items'];
      final ts = data['tanggal'] as Timestamp?;
      final total = (data['total'] ?? 0) as int;
      final kasir = (data['kasir'] ?? 'Kasir Utama') as String;
      final jenis = (data['jenis'] ?? 'Penjualan') as String;

      final existingItems = await _transaksiItemRef
          .where('transaksiId', isEqualTo: doc.id)
          .get();

      final batch = _db.batch();
      if (existingItems.docs.isEmpty && rawItems is List && rawItems.isNotEmpty) {
        for (final raw in rawItems) {
          final item = Map<String, dynamic>.from(raw as Map);
          batch.set(_transaksiItemRef.doc(), {
            'transaksiId': doc.id,
            if (ts != null) 'tanggal': ts,
            'total': total,
            'kasir': kasir,
            'jenis': jenis,
            ...item,
          });
          totalMigrated++;
        }
      } else if (existingItems.docs.isNotEmpty) {
        for (final itemDoc in existingItems.docs) {
          batch.update(itemDoc.reference, {
            if (ts != null) 'tanggal': ts,
            'total': total,
            'kasir': kasir,
            'jenis': jenis,
          });
        }
      } else {
        await _transaksiRef.doc(doc.id).update({'migratedItems': true});
        continue;
      }

      batch.update(_transaksiRef.doc(doc.id), {
        'migratedItems': true,
        'items': FieldValue.delete(),
      });

      await batch.commit();
    }

    return totalMigrated;
  }

  // ===============================
  // 📊 LAPORAN AKUNTANSI STOK
  // ===============================

  Stream<List<Map<String, dynamic>>> streamRekapStokAkuntansi() {
    List<Map<String, dynamic>> buildList(List<QueryDocumentSnapshot> docs) {
      final Map<String, Map<String, dynamic>> rekap = {};

      for (final d in docs) {
        final data = d.data() as Map<String, dynamic>;
        final id = data['produk_id'];
        if (id == null) continue;

        rekap.putIfAbsent(id, () {
          return {
            'produkId': id,
            'nama': data['nama_produk'],
            'stok_awal': 0,
            'masuk': 0,
            'keluar': 0,
            'stok_akhir': 0,
          };
        });

        final row = rekap[id]!;
        final perubahan = data['perubahan'] as int;

        if (perubahan > 0) {
          row['masuk'] += perubahan;
        } else {
          row['keluar'] += perubahan.abs();
        }

        row['stok_akhir'] = data['stok_akhir'];
      }

      return rekap.values.toList();
    }

    if (_usePolling) {
      return _pollWithCache(
        load: () async {
          final snap = await _stokLogRef.orderBy('waktu').get();
          return buildList(snap.docs);
        },
        loadCache: () async {
          final snap = await _stokLogRef
              .orderBy('waktu')
              .get(const GetOptions(source: Source.cache));
          return buildList(snap.docs);
        },
      );
    }

    return _stokLogRef
        .orderBy('waktu')
        .snapshots()
        .map((snap) => buildList(snap.docs));
  }

  Stream<List<Map<String, dynamic>>> streamStokLog() {
    if (_usePolling) {
      return _pollWithCache(
        load: () async {
          final snap = await _stokLogRef.orderBy('waktu', descending: true).get();
          return snap.docs
              .map((d) => Map<String, dynamic>.from(d.data() as Map))
              .toList();
        },
        loadCache: () async {
          final snap = await _stokLogRef
              .orderBy('waktu', descending: true)
              .get(const GetOptions(source: Source.cache));
          return snap.docs
              .map((d) => Map<String, dynamic>.from(d.data() as Map))
              .toList();
        },
      );
    }
    return _stokLogRef.orderBy('waktu', descending: true).snapshots().map(
          (snap) => snap.docs
              .map((d) => Map<String, dynamic>.from(d.data() as Map))
              .toList(),
        );
  }

  Stream<String?> streamUserRole(String uid) {
    if (_usePolling) {
      return _pollWithCache(
        load: () async {
          final doc = await _usersRef.doc(uid).get();
          if (!doc.exists) return null;
          final data = doc.data() as Map<String, dynamic>;
          return (data['role'] ?? 'operator').toString().toLowerCase();
        },
        loadCache: () async {
          final doc = await _usersRef
              .doc(uid)
              .get(const GetOptions(source: Source.cache));
          if (!doc.exists) return null;
          final data = doc.data() as Map<String, dynamic>;
          return (data['role'] ?? 'operator').toString().toLowerCase();
        },
      );
    }
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      final role = (data['role'] ?? 'operator').toString().toLowerCase();
      return role;
    });
  }

  Stream<Map<String, dynamic>?> streamUserProfile(
    String uid, {
    String? email,
  }) {
    Future<Map<String, dynamic>?> load() async {
      final doc = await _usersRef.doc(uid).get();
      if (doc.exists) {
        return {
          'id': doc.id,
          ...(doc.data() as Map<String, dynamic>),
        };
      }

      final emailRaw = (email ?? '').trim();
      final lookupEmail = emailRaw.toLowerCase();
      if (lookupEmail.isEmpty) return null;

      QuerySnapshot q = await _usersRef
          .where('email', isEqualTo: lookupEmail)
          .limit(1)
          .get();
      if (q.docs.isEmpty && emailRaw.isNotEmpty && emailRaw != lookupEmail) {
        q = await _usersRef.where('email', isEqualTo: emailRaw).limit(1).get();
      }
      if (q.docs.isEmpty) return null;

      final alt = q.docs.first;
      final data = alt.data() as Map<String, dynamic>;
      if (alt.id != uid) {
        try {
          await _usersRef.doc(uid).set({
            ...data,
            'email': lookupEmail,
            'updatedAt': Timestamp.now(),
          }, SetOptions(merge: true));
          await _usersRef.doc(alt.id).delete();
          return {
            'id': uid,
            ...data,
            'email': lookupEmail,
          };
        } catch (_) {
          // Fallback when migration is blocked by rules/permissions.
          return {
            'id': alt.id,
            ...data,
            'email': data['email'] ?? lookupEmail,
          };
        }
      }

      return {
        'id': alt.id,
        ...data,
      };
    }

    if (_usePolling) {
      Future<Map<String, dynamic>?> loadCache() async {
        final doc = await _usersRef
            .doc(uid)
            .get(const GetOptions(source: Source.cache));
        if (doc.exists) {
          return {
            'id': doc.id,
            ...(doc.data() as Map<String, dynamic>),
          };
        }

        final emailRaw = (email ?? '').trim();
        final lookupEmail = emailRaw.toLowerCase();
        if (lookupEmail.isEmpty) return null;

        QuerySnapshot q = await _usersRef
            .where('email', isEqualTo: lookupEmail)
            .limit(1)
            .get(const GetOptions(source: Source.cache));
        if (q.docs.isEmpty && emailRaw.isNotEmpty && emailRaw != lookupEmail) {
          q = await _usersRef
              .where('email', isEqualTo: emailRaw)
              .limit(1)
              .get(const GetOptions(source: Source.cache));
        }
        if (q.docs.isEmpty) return null;

        final alt = q.docs.first;
        final data = alt.data() as Map<String, dynamic>;
        return {
          'id': alt.id,
          ...data,
        };
      }

      return _pollWithCache(
        load: load,
        loadCache: loadCache,
        emitNullCache: false,
      );
    }
    return _usersRef.doc(uid).snapshots().asyncMap((_) => load());
  }

  Future<void> upsertUserRole({
    required String uid,
    required String email,
    required String role,
    String? namaPanggilan,
    bool? disabled,
  }) async {
    final payload = <String, dynamic>{
      'email': email,
      'role': role.toLowerCase(),
      'updatedAt': Timestamp.now(),
    };
    if (namaPanggilan != null && namaPanggilan.trim().isNotEmpty) {
      payload['nama_panggilan'] = namaPanggilan.trim();
    }
    if (disabled != null) {
      payload['disabled'] = disabled;
    }
    await _usersRef.doc(uid).set(payload, SetOptions(merge: true));
  }

  Future<void> setUserDisabled(String uid, bool disabled) async {
    await _usersRef.doc(uid).set({
      'disabled': disabled,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUserEmail(String uid, String email) async {
    await _usersRef.doc(uid).set({
      'email': email.toLowerCase(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUserNickname(String uid, String namaPanggilan) async {
    await _usersRef.doc(uid).set({
      'nama_panggilan': namaPanggilan.trim(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> streamUsers() {
    Future<List<Map<String, dynamic>>> load() async {
      final snap = await _usersRef.get();
      final users = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final email = (data['email'] ?? '').toString();
        final fallbackEmail =
            email.isNotEmpty ? email : (doc.id.contains('@') ? doc.id : '');
        return {
          'id': doc.id,
          ...data,
          if (fallbackEmail.isNotEmpty) 'email': fallbackEmail,
        };
      }).toList();
      users.sort((a, b) {
        final aEmail = (a['email'] ?? '').toString().toLowerCase();
        final bEmail = (b['email'] ?? '').toString().toLowerCase();
        return aEmail.compareTo(bEmail);
      });
      return users;
    }

    if (_usePolling) {
      Future<List<Map<String, dynamic>>> loadCache() async {
        final snap =
            await _usersRef.get(const GetOptions(source: Source.cache));
        final users = snap.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final email = (data['email'] ?? '').toString();
          final fallbackEmail =
              email.isNotEmpty ? email : (doc.id.contains('@') ? doc.id : '');
          return {
            'id': doc.id,
            ...data,
            if (fallbackEmail.isNotEmpty) 'email': fallbackEmail,
          };
        }).toList();
        users.sort((a, b) {
          final aEmail = (a['email'] ?? '').toString().toLowerCase();
          final bEmail = (b['email'] ?? '').toString().toLowerCase();
          return aEmail.compareTo(bEmail);
        });
        return users;
      }

      return _pollWithCache(load: load, loadCache: loadCache);
    }

    return _usersRef.snapshots().asyncMap((_) => load());
  }

  Future<void> hapusUser(String uid) async {
    await _usersRef.doc(uid).delete();
  }
}
