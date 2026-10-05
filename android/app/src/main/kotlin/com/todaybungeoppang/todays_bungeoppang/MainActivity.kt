package com.todaybungeoppang.todays_bungeoppang

import android.app.Application
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/** Starts Play Games Services when this build includes it (see build.gradle.kts). */
class GamesApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        PlayGamesBridge.initialize(this)
    }
}

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PlayGamesBridge.attach(this, flutterEngine)
    }
}
