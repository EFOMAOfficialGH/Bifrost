package com.bifrost.app

import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val sharedFiles = mutableListOf<String>()
    private lateinit var shareChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bifrost/share")
        shareChannel.setMethodCallHandler { call, result ->
            if (call.method == "getSharedFiles") {
                result.success(sharedFiles.toList())
                sharedFiles.clear()
            } else {
                result.notImplemented()
            }
        }
        collectSharedFiles(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        collectSharedFiles(intent)
        if (::shareChannel.isInitialized && sharedFiles.isNotEmpty()) {
            shareChannel.invokeMethod("sharedFiles", sharedFiles.toList())
            sharedFiles.clear()
        }
    }

    private fun collectSharedFiles(intent: Intent?) {
        if (intent == null) return
        val uris = mutableListOf<Uri>()
        val stream = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        if (stream != null) uris.add(stream)
        val clipData = intent.clipData
        if (clipData != null) {
            for (index in 0 until clipData.itemCount) uris.add(clipData.getItemAt(index).uri)
        }
        uris.distinct().forEach { uri -> copyToShareCache(uri)?.let(sharedFiles::add) }
    }

    private fun copyToShareCache(uri: Uri): String? {
        return try {
            val originalName = queryDisplayName(uri) ?: "shared-file"
            val safeName = originalName.replace(Regex("[^a-zA-Z0-9._ -]"), "_").ifBlank { "shared-file" }
            val target = File(cacheDir, "bifrost-share-${System.currentTimeMillis()}-$safeName")
            contentResolver.openInputStream(uri)?.use { input -> target.outputStream().use { output -> input.copyTo(output) } }
            if (target.exists() && target.length() > 0) target.absolutePath else null
        } catch (_: Exception) {
            null
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        if (uri.scheme == "file") return uri.lastPathSegment
        val cursor: Cursor? = contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
        return cursor?.use { if (it.moveToFirst()) it.getString(0) else null }
    }
}
