import 'package:cloud_firestore/cloud_firestore.dart';

import 'produk_model.dart';

typedef TransaksiItem = Map<String, dynamic>;

extension TransaksiItemX on TransaksiItem {
  String get id => this['id'] as String;
  int get qty => this['qty'] as int;
  set qty(int value) => this['qty'] = value;

  Timestamp get dibuatPada => this['dibuatPada'] as Timestamp;

  Produk get produk {
    final map = Map<String, dynamic>.from(this['produk'] as Map);
    return Produk.dariMap(map, map['id']);
  }

  set produk(Produk value) {
    this['produk'] = {
      ...value.toMap(),
      'id': value.id,
    };
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'produk': Map<String, dynamic>.from(this['produk'] as Map),
      'qty': qty,
      'dibuatPada': dibuatPada,
    };
    if (this['hargaOverride'] != null) {
      map['hargaOverride'] = this['hargaOverride'];
    }
    if (this['diskonPersen'] != null) {
      map['diskonPersen'] = this['diskonPersen'];
    }
    if (this['catatan'] != null) {
      map['catatan'] = this['catatan'];
    }
    if (this['paymentMethod'] != null) {
      map['paymentMethod'] = this['paymentMethod'];
    }
    if (this['paidAmount'] != null) {
      map['paidAmount'] = this['paidAmount'];
    }
    if (this['change'] != null) {
      map['change'] = this['change'];
    }
    return map;
  }
}

class Transaksi {
  final String id;
  final DateTime tanggal;
  final List<TransaksiItem> items;
  final int total;
  final String kasir;
  final String jenis;

  Transaksi({
    required this.id,
    required this.tanggal,
    required this.items,
    required this.total,
    this.kasir = 'Kasir Utama',
    this.jenis = 'Penjualan',
  });

  factory Transaksi.dariFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawItems = data['items'] as List?;

    return Transaksi(
      id: doc.id,
      tanggal: (data['tanggal'] as Timestamp).toDate(),
      total: data['total'],
      kasir: data['kasir'] ?? 'Kasir Utama',
      jenis: data['jenis'] ?? 'Penjualan',
      items: rawItems == null
          ? <TransaksiItem>[]
          : rawItems.map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  static TransaksiItem buatItem({
    required Produk produk,
    required int qty,
    String? id,
    Timestamp? dibuatPada,
    int? hargaOverride,
    int? diskonPersen,
    String? catatan,
  }) {
    final item = <String, dynamic>{
      'id': id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'produk': {
        ...produk.toMap(),
        'id': produk.id,
      },
      'qty': qty,
      'dibuatPada': dibuatPada ?? Timestamp.now(),
    };
    if (hargaOverride != null) item['hargaOverride'] = hargaOverride;
    if (diskonPersen != null) item['diskonPersen'] = diskonPersen;
    if (catatan != null) item['catatan'] = catatan;
    return item;
  }
}
