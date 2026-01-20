import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String?> savePdfToDownloadsImpl(Uint8List bytes, String filename) async {
  Directory? baseDir = await getDownloadsDirectory();
  baseDir ??= await getApplicationDocumentsDirectory();
  if (baseDir.path.isEmpty) {
    return null;
  }

  final file = File('${baseDir.path}${Platform.pathSeparator}$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
