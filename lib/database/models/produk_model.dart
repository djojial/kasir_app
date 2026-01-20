import 'package:cloud_firestore/cloud_firestore.dart';

class Produk {
  final String? id;
  final String nama;
  final String kategori;
  final String barcode;
  final int harga;
  final int hargaModal;
  final int diskonMinQty;
  final int diskonHarga;
  final int diskonPersen;
  final String? gambarBase64;
  final int stok;
  final Timestamp? dibuatPada;

  Produk({
    this.id,
    required this.nama,
    this.kategori = 'Lainnya',
    required this.barcode,
    required this.harga,
    this.hargaModal = 0,
    this.diskonMinQty = 0,
    this.diskonHarga = 0,
    this.diskonPersen = 0,
    this.gambarBase64,
    required this.stok,
    this.dibuatPada,
  });

  /// =========================
  /// COPY WITH (WAJIB UNTUK POS)
  /// =========================
  Produk copyWith({
    String? id,
    String? nama,
    String? kategori,
    String? barcode,
    int? harga,
    int? hargaModal,
    int? diskonMinQty,
    int? diskonHarga,
    int? diskonPersen,
    String? gambarBase64,
    int? stok,
    Timestamp? dibuatPada,
  }) {
    return Produk(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      kategori: kategori ?? this.kategori,
      barcode: barcode ?? this.barcode,
      harga: harga ?? this.harga,
      hargaModal: hargaModal ?? this.hargaModal,
      diskonMinQty: diskonMinQty ?? this.diskonMinQty,
      diskonHarga: diskonHarga ?? this.diskonHarga,
      diskonPersen: diskonPersen ?? this.diskonPersen,
      gambarBase64: gambarBase64 ?? this.gambarBase64,
      stok: stok ?? this.stok,
      dibuatPada: dibuatPada ?? this.dibuatPada,
    );
  }

  factory Produk.dariMap(Map<String, dynamic> map, String docId) {
    return Produk(
      id: docId,
      nama: map['nama'],
      kategori: map['kategori'] ?? 'Lainnya',
      barcode: map['barcode'],
      harga: map['harga'],
      hargaModal: map['harga_modal'] ?? 0,
      diskonMinQty: map['diskon_min_qty'] ?? 0,
      diskonHarga: map['diskon_harga'] ?? 0,
      diskonPersen: map['diskon_persen'] ?? 0,
      gambarBase64: map['gambar_base64'],
      stok: map['stok'],
      dibuatPada: map['dibuat_pada'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'kategori': kategori,
      'barcode': barcode,
      'harga': harga,
      'harga_modal': hargaModal,
      'diskon_min_qty': diskonMinQty,
      'diskon_harga': diskonHarga,
      'diskon_persen': diskonPersen,
      'gambar_base64': gambarBase64,
      'stok': stok,
      'dibuat_pada': dibuatPada ?? Timestamp.now(),
    };
  }
}
