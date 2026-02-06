import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

Future<String?> savePdfToDownloadsImpl(Uint8List bytes, String filename) async {
  if (Platform.isAndroid) {
    try {
      const channel = MethodChannel('kasir_app/media_store');
      final uri = await channel.invokeMethod<String>('saveToDownloads', {
        'bytes': bytes,
        'filename': filename,
        'mimeType': 'application/pdf',
      });
      return uri;
    } catch (_) {
      return null;
    }
  }
  Directory? baseDir = await getDownloadsDirectory();
  baseDir ??= await getApplicationDocumentsDirectory();
  if (baseDir.path.isEmpty) {
    return null;
  }

  try {
    final file = File('${baseDir.path}${Platform.pathSeparator}$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}
