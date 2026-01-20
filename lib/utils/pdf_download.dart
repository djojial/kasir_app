import 'dart:typed_data';

import 'pdf_download_stub.dart'
    if (dart.library.html) 'pdf_download_web.dart';

Future<void> savePdfBytesWeb(Uint8List bytes, String filename) {
  return savePdfBytesWebImpl(bytes, filename);
}
