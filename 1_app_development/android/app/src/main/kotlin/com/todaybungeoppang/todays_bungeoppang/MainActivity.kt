package com.todaybungeoppang.todays_bungeoppang

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var cookingTilt: CookingTiltStream? = null
    private var cookingTiltChannel: EventChannel? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val input = CookingTiltStream(this)
        cookingTilt = input
        cookingTiltChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger,
            "todays_bungeoppang/cooking_tilt").also { it.setStreamHandler(input) }
    }
    override fun onResume() { super.onResume(); cookingTilt?.setForeground(true) }
    override fun onPause() { cookingTilt?.setForeground(false); super.onPause() }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        cookingTiltChannel?.setStreamHandler(null)
        cookingTilt?.dispose()
        cookingTiltChannel = null
        cookingTilt = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
