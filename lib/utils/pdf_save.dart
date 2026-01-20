import 'dart:typed_data';

import 'pdf_save_stub.dart'
    if (dart.library.io) 'pdf_save_io.dart';

Future<String?> savePdfToDownloads(Uint8List bytes, String filename) {
  return savePdfToDownloadsImpl(bytes, filename);
}
