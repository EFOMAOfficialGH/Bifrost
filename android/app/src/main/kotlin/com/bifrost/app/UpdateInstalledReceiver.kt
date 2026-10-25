package com.bifrost.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.io.File

class UpdateInstalledReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val updateDirectory = File(context.filesDir, "bifrost-updates")
        updateDirectory.listFiles()?.forEach { file ->
            if (file.isFile && (file.name.endsWith(".apk") || file.name.endsWith(".apk.part"))) {
                file.delete()
            }
        }
    }
}
