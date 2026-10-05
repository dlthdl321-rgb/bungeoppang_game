package com.todaybungeoppang.todays_bungeoppang

import android.app.Activity
import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Built when games-ids.xml has no Play Console app ID: the Play Games SDK is
 * not linked at all and online ranking reports itself as not configured.
 */
object PlayGamesBridge {
    fun initialize(application: Application) {}

    fun attach(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                result.success(if (call.method == "status") mapOf(
                    "configured" to false, "authenticated" to false) else false)
            }
    }

    private const val CHANNEL = "todays_bungeoppang/play_games"
}
