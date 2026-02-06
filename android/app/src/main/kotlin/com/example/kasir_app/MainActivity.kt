package com.example.kasir_app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val channel = "kasir_app/media_store"

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
      .setMethodCallHandler { call, result ->
        if (call.method != "saveToDownloads") {
          result.notImplemented()
          return@setMethodCallHandler
        }
        val bytes = call.argument<ByteArray>("bytes")
        val filename = call.argument<String>("filename")
        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
        if (bytes == null || filename.isNullOrBlank()) {
          result.error("INVALID_ARGS", "Missing bytes or filename", null)
          return@setMethodCallHandler
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
          result.success(null)
          return@setMethodCallHandler
        }
        try {
          val resolver = applicationContext.contentResolver
          val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
          }
          val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
          if (uri == null) {
            result.success(null)
            return@setMethodCallHandler
          }
          val stream = resolver.openOutputStream(uri)
          if (stream == null) {
            resolver.delete(uri, null, null)
            result.success(null)
            return@setMethodCallHandler
          }
          stream.use { out ->
            out.write(bytes)
            out.flush()
          }
          val doneValues = ContentValues().apply {
            put(MediaStore.MediaColumns.IS_PENDING, 0)
          }
          resolver.update(uri, doneValues, null, null)
          result.success(uri.toString())
        } catch (e: Exception) {
          result.error("SAVE_FAILED", e.localizedMessage, null)
        }
      }
  }
}
