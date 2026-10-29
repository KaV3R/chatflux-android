package com.fluxer

import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.Process
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class AppRestartBridge(
    private val activity: MainActivity,
) {
    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_RESTART -> {
                    result.success(null)
                    Handler(Looper.getMainLooper()).post { restart() }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun restart() {
        val intent =
            Intent(activity, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            }
        activity.startActivity(intent)
        activity.finishAffinity()
        Process.killProcess(Process.myPid())
    }

    companion object {
        const val CHANNEL_NAME = "fluxer_app/app_restart"
        const val METHOD_RESTART = "restart"
    }
}
