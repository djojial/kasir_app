import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String?> savePdfToDownloadsImpl(Uint8List bytes, String filename) async {
  Directory? baseDir = await getDownloadsDirectory();
  if (baseDir == null && Platform.isAndroid) {
    final dirs = await getExternalStorageDirectories(
      type: StorageDirectory.downloads,
    );
    if (dirs != null && dirs.isNotEmpty) {
      baseDir = dirs.first;
    }
  }
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
