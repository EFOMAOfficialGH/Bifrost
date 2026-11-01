package com.bifrost.app

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInstaller
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

/** Native operations for the explicitly user-initiated app transfer feature. */
class AppTransferPlugin(
    private val activity: Activity,
    private val channel: MethodChannel,
) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "bifrost/app_transfer"
        private const val INSTALL_RESULT = "com.bifrost.app.APP_TRANSFER_INSTALL_RESULT"
        private const val COPY_BUFFER_SIZE = 128 * 1024
        private const val MAX_ENTRY_SIZE = 32L * 1024 * 1024 * 1024
    }

    private val worker = java.util.concurrent.Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var pendingInstall: MethodChannel.Result? = null
    @Volatile private var installQueued = false
    @Volatile private var pendingXapk: File? = null
    @Volatile private var pendingStaging: File? = null
    @Volatile private var pendingObbEntries: List<String> = emptyList()
    @Volatile private var pendingPackageName: String? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listInstalledUserApps" -> worker.execute {
                try {
                    val apps = listApps()
                    mainHandler.post { result.success(apps) }
                } catch (e: Exception) {
                    mainHandler.post { result.error("APP_LIST_FAILED", e.localizedMessage, null) }
                }
            }
            "canInstallUnknownApps" -> result.success(Build.VERSION.SDK_INT < 26 || activity.packageManager.canRequestPackageInstalls())
            "requestInstallUnknownApps" -> {
                if (Build.VERSION.SDK_INT >= 26 && !activity.packageManager.canRequestPackageInstalls()) {
                    activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}")))
                }
                result.success(null)
            }
            "hasAllFilesAccess" -> result.success(Build.VERSION.SDK_INT < 30 || Environment.isExternalStorageManager())
            "requestAllFilesAccess" -> {
                requestAllFilesAccess()
                result.success(null)
            }
            "prepareAppTransfer" -> prepareAppTransfer(call, result)
            "deleteTemporaryExport" -> {
                val path = call.argument<String>("path")
                worker.execute {
                    val deleted = path != null && deleteTemporaryExport(path)
                    mainHandler.post { result.success(deleted) }
                }
            }
            "cleanupTemporaryExports" -> {
                val retained = call.argument<List<String>>("retainedPaths") ?: emptyList()
                worker.execute {
                    cleanupTemporaryExports(retained)
                    mainHandler.post { result.success(null) }
                }
            }
            "installXapk" -> installXapk(call, result)
            else -> result.notImplemented()
        }
    }

    private fun requestAllFilesAccess() {
        if (Build.VERSION.SDK_INT >= 30 && !Environment.isExternalStorageManager()) {
            activity.startActivity(Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:${activity.packageName}")))
        }
    }

    private fun listApps(): List<Map<String, Any?>> {
        val pm = activity.packageManager
        val apps = if (Build.VERSION.SDK_INT >= 33) {
            pm.getInstalledApplications(android.content.pm.PackageManager.ApplicationInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.getInstalledApplications(0)
        }
        return apps.asSequence()
            .filter { (it.flags and ApplicationInfo.FLAG_SYSTEM) == 0 }
            .mapNotNull { app ->
                try {
                    val info = if (Build.VERSION.SDK_INT >= 33) {
                        pm.getPackageInfo(app.packageName, android.content.pm.PackageManager.PackageInfoFlags.of(0))
                    } else {
                        @Suppress("DEPRECATION")
                        pm.getPackageInfo(app.packageName, 0)
                    }
                    val apkPaths = listOfNotNull(app.sourceDir) + (app.splitSourceDirs?.toList() ?: emptyList())
                    val apkNames = apkPaths.mapIndexed { index, path ->
                        if (index == 0) "base.apk" else File(path).name
                    }
                    val apkSize = apkPaths.sumOf { File(it).length() }
                    val obbRoot = File(Environment.getExternalStorageDirectory(), "Android/obb/${app.packageName}")
                    val hasObb = (Build.VERSION.SDK_INT < 30 || Environment.isExternalStorageManager()) &&
                        obbRoot.isDirectory && obbRoot.walkTopDown().any { it.isFile && it.extension.equals("obb", ignoreCase = true) }
                    mapOf(
                        "name" to pm.getApplicationLabel(app).toString(),
                        "packageName" to app.packageName,
                        "versionName" to info.versionName.orEmpty(),
                        "versionCode" to if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong(),
                        "sizeBytes" to apkSize,
                        "apkSizeBytes" to apkSize,
                        "apkPaths" to apkPaths,
                        "apkNames" to apkNames,
                        "hasObb" to hasObb,
                        "iconPng" to iconBytes(app),
                    )
                } catch (_: Exception) {
                    null
                }
            }
            .sortedBy { it["name"].toString().lowercase() }
            .toList()
    }

    private fun iconBytes(app: ApplicationInfo): ByteArray? = try {
        val drawable = activity.packageManager.getApplicationIcon(app)
        val bitmap = if (drawable is android.graphics.drawable.BitmapDrawable && drawable.bitmap != null) {
            drawable.bitmap
        } else {
            val width = drawable.intrinsicWidth.coerceAtLeast(1)
            val height = drawable.intrinsicHeight.coerceAtLeast(1)
            android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888).also {
                val canvas = android.graphics.Canvas(it)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
            }
        }
        java.io.ByteArrayOutputStream().use { output ->
            bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, output)
            output.toByteArray()
        }
    } catch (_: Exception) {
        null
    }

    private fun collectFiles(directory: File): List<File> {
        val canonicalRoot = directory.canonicalFile
        val children = directory.listFiles() ?: throw IOException("Cannot read ${directory.path}")
        val files = mutableListOf<File>()
        for (child in children) {
            val canonical = child.canonicalFile
            if (!canonical.path.startsWith(canonicalRoot.path + File.separator)) continue
            if (child.isDirectory) files += collectFiles(child)
            else if (child.isFile) files += child
        }
        return files
    }

    private fun prepareAppTransfer(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name") ?: "App"
        val packageName = call.argument<String>("packageName")
        val versionName = call.argument<String>("versionName") ?: ""
        val versionCode = (call.argument<Number>("versionCode"))?.toLong() ?: 0L
        val apkPaths = call.argument<List<String>>("apkPaths")
        val apkNames = call.argument<List<String>>("apkNames")
        val includeObb = call.argument<Boolean>("includeObb") ?: false
        val safeName = name.replace(Regex("[^A-Za-z0-9._-]+"), "_").trim('.').ifBlank { packageName ?: "App" }
        if (packageName.isNullOrBlank() || !packageName.matches(Regex("^[A-Za-z0-9_]+(\\.[A-Za-z0-9_]+)+$")) || apkPaths.isNullOrEmpty() || apkNames == null || apkNames.size != apkPaths.size || apkPaths.any { !File(it).isFile } || apkNames.firstOrNull() != "base.apk" || apkNames.any { !it.matches(Regex("^[A-Za-z0-9._-]+\\.apk$")) } || apkNames.toSet().size != apkNames.size) {
            result.error("INVALID_APP", "The app's APK files could not be found.", null)
            return
        }
        if (includeObb && Build.VERSION.SDK_INT >= 30 && !Environment.isExternalStorageManager()) {
            result.error("ALL_FILES_ACCESS_REQUIRED", "Grant All files access to check for and include optional OBB files.", null)
            return
        }
        worker.execute {
            var output: File? = null
            try {
                val obbRoot = File(Environment.getExternalStorageDirectory(), "Android/obb/$packageName")
                val obbFiles = if (includeObb && obbRoot.isDirectory) collectFiles(obbRoot).sortedBy { it.path } else emptyList()
                val apkFiles = apkPaths.map(::File)
                if (apkFiles.size == 1 && obbFiles.isEmpty()) {
                    val directArtifact = mapOf(
                        "path" to apkFiles.first().absolutePath,
                        "remoteName" to "$safeName.apk",
                        "temporary" to false,
                        "isArchive" to false,
                    )
                    mainHandler.post { result.success(directArtifact) }
                    return@execute
                }
                val totalBytes = (apkFiles + obbFiles).sumOf { it.length() }.coerceAtLeast(1L)
                val outputDirectory = activity.getExternalFilesDir("BifrostExports") ?: File(activity.cacheDir, "BifrostExports")
                if (!outputDirectory.exists() && !outputDirectory.mkdirs()) throw IOException("Cannot create the app export folder")
                output = File(outputDirectory, "$safeName-${System.currentTimeMillis()}.xapk")
                var copied = 0L
                var lastProgressAt = 0L
                ZipOutputStream(BufferedOutputStream(FileOutputStream(output))).use { zip ->
                    val manifest = JSONObject()
                        .put("package_name", packageName)
                        .put("version_name", versionName)
                        .put("version_code", versionCode)
                        .put("apk_files", JSONArray(apkNames))
                        .put("has_obb", obbFiles.isNotEmpty())
                    zip.putNextEntry(ZipEntry("manifest.json"))
                    zip.write(manifest.toString(2).toByteArray(Charsets.UTF_8))
                    zip.closeEntry()
                    for ((index, file) in apkFiles.withIndex()) {
                        copied = writeFileEntry(zip, file, "apks/${apkNames[index]}", copied, totalBytes) { progress ->
                            val now = SystemClock.elapsedRealtime()
                            if (now - lastProgressAt >= 200) {
                                lastProgressAt = now
                                reportProgress(progress)
                            }
                        }
                    }
                    val canonicalObbRoot = obbRoot.canonicalFile
                    for (file in obbFiles) {
                        val relative = file.canonicalPath.removePrefix(canonicalObbRoot.path + File.separator).replace(File.separatorChar, '/')
                        if (relative.isBlank() || relative.split('/').any { it.isBlank() || it == "." || it == ".." }) continue
                        copied = writeFileEntry(zip, file, "Android/obb/$packageName/$relative", copied, totalBytes) { progress ->
                            val now = SystemClock.elapsedRealtime()
                            if (now - lastProgressAt >= 200) {
                                lastProgressAt = now
                                reportProgress(progress)
                            }
                        }
                    }
                }
                reportProgress(1.0)
                val artifact = mapOf(
                    "path" to output.absolutePath,
                    "remoteName" to "$safeName.xapk",
                    "temporary" to true,
                    "isArchive" to true,
                )
                mainHandler.post { result.success(artifact) }
            } catch (e: Exception) {
                output?.delete()
                mainHandler.post { result.error("APP_TRANSFER_PREPARE_FAILED", e.localizedMessage ?: "Could not prepare this app.", null) }
            }
        }
    }

    private fun exportDirectories(): List<File> = listOfNotNull(
        activity.getExternalFilesDir("BifrostExports"),
        File(activity.cacheDir, "BifrostExports"),
    ).map { it.canonicalFile }.distinctBy { it.path }

    private fun deleteTemporaryExport(path: String): Boolean {
        val target = File(path).canonicalFile
        val isOwnedExport = exportDirectories().any { root ->
            target.path.startsWith(root.path + File.separator)
        }
        if (!isOwnedExport || !target.isFile || !target.name.endsWith(".xapk", ignoreCase = true)) return false
        return target.delete()
    }

    private fun cleanupTemporaryExports(retainedPaths: List<String>) {
        val retained = retainedPaths.mapNotNull { path ->
            try { File(path).canonicalPath } catch (_: Exception) { null }
        }.toSet()
        for (root in exportDirectories()) {
            root.listFiles()?.filter { file ->
                file.isFile && file.name.endsWith(".xapk", ignoreCase = true) && file.canonicalPath !in retained
            }?.forEach { it.delete() }
        }
    }

    private fun writeFileEntry(
        zip: ZipOutputStream,
        source: File,
        entryName: String,
        completedBefore: Long,
        totalBytes: Long,
        onProgress: (Double) -> Unit,
    ): Long {
        if (!source.isFile || !source.canRead()) throw IOException("Cannot read ${source.path}")
        zip.putNextEntry(ZipEntry(entryName))
        var copied = completedBefore
        BufferedInputStream(FileInputStream(source), COPY_BUFFER_SIZE).use { input ->
            val buffer = ByteArray(COPY_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                zip.write(buffer, 0, count)
                copied += count
                onProgress((copied.toDouble() / totalBytes).coerceIn(0.0, 1.0))
            }
        }
        zip.closeEntry()
        return copied
    }

    private fun reportProgress(progress: Double) {
        mainHandler.post { channel.invokeMethod("packagingProgress", progress) }
    }

    private fun installXapk(call: MethodCall, result: MethodChannel.Result) {
        synchronized(this) {
            if (installQueued || pendingInstall != null) {
                result.error("INSTALL_BUSY", "Another app installation is still in progress.", null)
                return
            }
            installQueued = true
        }
        if (Build.VERSION.SDK_INT >= 26 && !activity.packageManager.canRequestPackageInstalls()) {
            synchronized(this) { installQueued = false }
            result.error("UNKNOWN_SOURCES_NOT_ALLOWED", "Enable Install unknown apps for Bifrost, then retry.", null)
            return
        }
        val xapk = File(call.argument<String>("path") ?: "")
        if (!xapk.isFile) {
            synchronized(this) { installQueued = false }
            result.error("INVALID_XAPK", "The received XAPK file could not be found.", null)
            return
        }
        worker.execute {
            var staging: File? = null
            var sessionId: Int? = null
            try {
                ZipFile(xapk).use { archive ->
                    val manifestEntry = archive.getEntry("manifest.json") ?: throw IOException("This XAPK is missing manifest.json")
                    if (manifestEntry.size <= 0 || manifestEntry.size > 1024 * 1024) throw IOException("The XAPK manifest has an invalid size")
                    val manifest = archive.getInputStream(manifestEntry).bufferedReader(Charsets.UTF_8).use { JSONObject(it.readText()) }
                    val packageName = manifest.optString("package_name")
                    if (!packageName.matches(Regex("^[A-Za-z0-9_]+(\\.[A-Za-z0-9_]+)+$"))) throw IOException("The XAPK manifest contains an invalid package name")
                    val apkArray = manifest.optJSONArray("apk_files") ?: throw IOException("The XAPK manifest is missing its APK file list")
                    if (apkArray.length() == 0) throw IOException("The XAPK contains no APK files")
                    val apkNames = (0 until apkArray.length()).map { apkArray.getString(it) }
                    if (apkNames.any { !it.matches(Regex("^[A-Za-z0-9._-]+\\.apk$")) || it == ".apk" }) throw IOException("The XAPK contains an unsafe APK file name")
                    if (apkNames.first() != "base.apk" || apkNames.toSet().size != apkNames.size) throw IOException("The XAPK APK list is duplicated or does not start with base.apk")
                    val obbPrefix = "Android/obb/$packageName/"
                    val obbNames = mutableListOf<String>()
                    val entries = archive.entries()
                    while (entries.hasMoreElements()) {
                        val entry = entries.nextElement()
                        if (!entry.name.startsWith(obbPrefix)) continue
                        val relative = entry.name.removePrefix(obbPrefix)
                        if (entry.isDirectory) continue
                        if (relative.isBlank() || relative.contains('\\') || relative.split('/').any { it.isBlank() || it == "." || it == ".." }) throw IOException("The XAPK contains an unsafe OBB path")
                        if (entry.size > MAX_ENTRY_SIZE) throw IOException("An OBB file in this XAPK is too large to safely restore")
                        obbNames += entry.name
                    }
                    if (obbNames.isNotEmpty() && Build.VERSION.SDK_INT >= 30 && !Environment.isExternalStorageManager()) {
                        mainHandler.post {
                            synchronized(this) { installQueued = false }
                            requestAllFilesAccess()
                            result.error("ALL_FILES_ACCESS_REQUIRED", "Grant All files access to Bifrost, then retry. Shizuku is a documented alternative if direct OBB access is unavailable.", null)
                        }
                        return@execute
                    }
                    staging = File(activity.cacheDir, "bifrost-install-${System.currentTimeMillis()}")
                    if (!staging!!.mkdirs()) throw IOException("Could not create temporary install files")
                    val stagedApks = mutableListOf<Pair<File, String>>()
                    val sessionNames = mutableSetOf<String>()
                    for (name in apkNames) {
                        val entry = archive.getEntry("apks/$name") ?: throw IOException("APK file $name is missing from the XAPK")
                        if (entry.isDirectory || entry.size <= 0 || entry.size > MAX_ENTRY_SIZE) throw IOException("APK file $name has an invalid size")
                        val destination = File(staging, name)
                        copyZipEntry(archive, entry, destination, entry.size)
                        val packageInfo = if (Build.VERSION.SDK_INT >= 33) {
                            activity.packageManager.getPackageArchiveInfo(destination.path, android.content.pm.PackageManager.PackageInfoFlags.of(0))
                        } else {
                            @Suppress("DEPRECATION")
                            activity.packageManager.getPackageArchiveInfo(destination.path, 0)
                        } ?: throw IOException("APK file $name is invalid")
                        if (packageInfo.packageName != packageName) throw IOException("The APK package name does not match the XAPK manifest")
                        val splitNames = packageInfo.splitNames?.toList().orEmpty()
                        val sessionName = if (name == "base.apk") {
                            if (splitNames.isNotEmpty()) throw IOException("The XAPK APK list does not start with a base APK")
                            "base.apk"
                        } else {
                            splitNames.singleOrNull()?.let { "split_$it.apk" } ?: name
                        }
                        if (!sessionNames.add(sessionName)) throw IOException("The XAPK contains duplicate package splits")
                        stagedApks += destination to sessionName
                    }

                    val installer = activity.packageManager.packageInstaller
                    val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
                    sessionId = installer.createSession(params)
                    installer.openSession(sessionId!!).use { session ->
                        for ((file, sessionName) in stagedApks) {
                            session.openWrite(sessionName, 0, file.length()).use { output ->
                                FileInputStream(file).use { input -> input.copyTo(output, COPY_BUFFER_SIZE) }
                                session.fsync(output)
                            }
                        }
                        synchronized(this) {
                            pendingInstall = result
                            pendingXapk = xapk
                            pendingStaging = staging
                            pendingObbEntries = obbNames
                            pendingPackageName = packageName
                        }
                        val intent = Intent(activity, PackageInstallResultReceiver::class.java).setAction(INSTALL_RESULT)
                        val mutabilityFlag = if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
                        val pending = PendingIntent.getBroadcast(
                            activity,
                            sessionId!!,
                            intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or mutabilityFlag,
                        )
                        session.commit(pending.intentSender)
                    }
                }
            } catch (e: Exception) {
                sessionId?.let { try { activity.packageManager.packageInstaller.abandonSession(it) } catch (_: Exception) {} }
                staging?.deleteRecursively()
                mainHandler.post {
                    synchronized(this) {
                      if (pendingInstall === result) clearPendingInstall()
                      else installQueued = false
                    }
                    val detail = e.localizedMessage ?: "Could not start the installation."
                    result.error("XAPK_INSTALL_FAILED", installErrorMessage(detail), detail)
                }
            }
        }
    }

    private fun copyZipEntry(archive: ZipFile, entry: ZipEntry, destination: File, expectedSize: Long) {
        var copied = 0L
        archive.getInputStream(entry).use { input ->
            BufferedOutputStream(FileOutputStream(destination), COPY_BUFFER_SIZE).use { output ->
                val buffer = ByteArray(COPY_BUFFER_SIZE)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    copied += count
                    if (copied > expectedSize || copied > MAX_ENTRY_SIZE) throw IOException("The XAPK entry size is invalid")
                    output.write(buffer, 0, count)
                }
                output.flush()
            }
        }
        if (copied != expectedSize) throw IOException("The XAPK entry is incomplete")
    }

    fun onInstallBroadcast(context: Context, intent: Intent) {
        val callback = pendingInstall ?: return
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            val confirmation = if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_INTENT)
            }
            if (confirmation != null) {
                confirmation.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(confirmation)
            } else {
                finishInstall(callback, "Android requires an installation confirmation, but could not open it.")
            }
            return
        }
        if (status == PackageInstaller.STATUS_SUCCESS) {
            val obbEntries = pendingObbEntries
            if (obbEntries.isEmpty()) {
                finishInstall(callback, null)
            } else {
                worker.execute {
                    try {
                        copyObbFiles(pendingXapk ?: throw IOException("The XAPK was not retained"), pendingPackageName ?: throw IOException("The package name was not retained"), obbEntries)
                        finishInstall(callback, null)
                    } catch (error: Exception) {
                        finishInstall(callback, "App installed, but its OBB data could not be copied: ${error.localizedMessage ?: "storage access failed"}. Grant All files access and retry; see the Shizuku fallback guidance if direct access remains blocked.")
                    }
                }
            }
        } else {
            val detail = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE).orEmpty()
            finishInstall(callback, installErrorMessage(detail.ifBlank { "Android rejected the installation (status $status)." }))
        }
    }

    private fun copyObbFiles(xapk: File, packageName: String, entryNames: List<String>) {
        if (Build.VERSION.SDK_INT >= 30 && !Environment.isExternalStorageManager()) throw IOException("All files access is not granted")
        val targetRoot = File(Environment.getExternalStorageDirectory(), "Android/obb/$packageName").canonicalFile
        if (!targetRoot.exists() && !targetRoot.mkdirs()) throw IOException("Cannot create ${targetRoot.path}")
        ZipFile(xapk).use { archive ->
            for (name in entryNames) {
                val prefix = "Android/obb/$packageName/"
                if (!name.startsWith(prefix)) throw IOException("Invalid OBB path")
                val relative = name.removePrefix(prefix)
                if (relative.isBlank() || relative.contains('\\') || relative.split('/').any { it.isBlank() || it == "." || it == ".." }) throw IOException("Unsafe OBB path")
                val destination = File(targetRoot, relative).canonicalFile
                if (!destination.path.startsWith(targetRoot.path + File.separator)) throw IOException("Unsafe OBB destination")
                val entry = archive.getEntry(name) ?: throw IOException("OBB file is missing from the XAPK")
                if (entry.size > MAX_ENTRY_SIZE) throw IOException("OBB file is too large")
                destination.parentFile?.let { if (!it.exists() && !it.mkdirs()) throw IOException("Cannot create OBB folder") }
                copyZipEntry(archive, entry, destination, entry.size)
            }
        }
    }

    private fun installErrorMessage(detail: String): String = when {
        detail.contains("UPDATE_INCOMPATIBLE", ignoreCase = true) -> "Signature conflict: the installed app was signed with a different key."
        detail.contains("VERSION_DOWNGRADE", ignoreCase = true) -> "This package is an older version than the installed app."
        detail.contains("INSUFFICIENT_STORAGE", ignoreCase = true) -> "There is not enough storage to install this app."
        detail.contains("NO_MATCHING_ABIS", ignoreCase = true) || detail.contains("CPU_ABI", ignoreCase = true) -> "This app is not compatible with this device's processor architecture."
        else -> detail.ifBlank { "Could not install the app package." }
    }

    private fun finishInstall(callback: MethodChannel.Result, error: String?) {
        mainHandler.post {
            synchronized(this) {
                if (pendingInstall !== callback) return@post
                val staging = pendingStaging
                clearPendingInstall()
                staging?.deleteRecursively()
            }
            if (error == null) callback.success(null) else callback.error("PACKAGE_INSTALL_FAILED", error, null)
        }
    }

    private fun clearPendingInstall() {
        installQueued = false
        pendingInstall = null
        pendingXapk = null
        pendingStaging = null
        pendingObbEntries = emptyList()
        pendingPackageName = null
    }
}

class PackageInstallResultReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AppTransferReceiverRegistry.handler?.invoke(context, intent)
    }
}

object AppTransferReceiverRegistry {
    var handler: ((Context, Intent) -> Unit)? = null
}
