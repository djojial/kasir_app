import 'package:cloud_firestore/cloud_firestore.dart';

class StokLog {
  final String produkId;
  final String namaProduk;
  final int perubahan;
  final int stokAkhir;
  final String tipe; // masuk / keluar
  final Timestamp waktu;

  StokLog({
    required this.produkId,
    required this.namaProduk,
    required this.perubahan,
    required this.stokAkhir,
    required this.tipe,
    required this.waktu,
  });

  Map<String, dynamic> toMap() {
    return {
      'produk_id': produkId,
      'nama_produk': namaProduk,
      'perubahan': perubahan,
      'stok_akhir': stokAkhir,
      'tipe': tipe,
      'waktu': waktu,
    };
  }
}
