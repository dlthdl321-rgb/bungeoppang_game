package com.todaybungeoppang.todays_bungeoppang

import android.app.Activity
import android.app.Application
import com.google.android.gms.games.PlayGames
import com.google.android.gms.games.PlayGamesSdk
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Play Games Services v2 sign-in and leaderboards, built only with a
 * configured app ID. `serverAuthCode` hands Firebase Auth a one-time code
 * for the signed-in Play Games account (online wallet and invitations).
 */
object PlayGamesBridge {
    private const val CHANNEL = "todays_bungeoppang/play_games"
    private const val RC_LEADERBOARD_UI = 9004

    // Dart sends logical names; the Play Console IDs live in games-ids.xml.
    private val leaderboards = mapOf(
        "bestAutoRate" to R.string.leaderboard_best_auto_rate,
        "lifetime" to R.string.leaderboard_lifetime,
        "bestCombo" to R.string.leaderboard_best_combo,
    )

    fun initialize(application: Application) = PlayGamesSdk.initialize(application)

    fun attach(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val signIn = PlayGames.getGamesSignInClient(activity)
                when (call.method) {
                    "status" -> signIn.isAuthenticated().addOnCompleteListener {
                        result.success(mapOf(
                            "configured" to true,
                            "authenticated" to (it.isSuccessful &&
                                it.result.isAuthenticated)))
                    }
                    "signIn" -> signIn.signIn().addOnCompleteListener {
                        result.success(it.isSuccessful && it.result.isAuthenticated)
                    }
                    "submitScores" -> {
                        val client = PlayGames.getLeaderboardsClient(activity)
                        val scores = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                        var sent = 0
                        for ((key, value) in scores) {
                            val id = leaderboards[key]?.let(activity::getString)
                            val score = (value as? Number)?.toLong()
                            if (id.isNullOrBlank() || score == null || score < 0) continue
                            client.submitScore(id, score)
                            sent++
                        }
                        result.success(sent)
                    }
                    "serverAuthCode" -> {
                        // Firebase's Web client ID (firebase-ids.xml).
                        val clientId = activity.getString(R.string.server_client_id)
                        if (clientId.isBlank()) {
                            result.success(null)
                        } else {
                            signIn.requestServerSideAccess(clientId, false)
                                .addOnCompleteListener {
                                    result.success(if (it.isSuccessful) it.result else null)
                                }
                        }
                    }
                    "showLeaderboards" -> PlayGames.getLeaderboardsClient(activity)
                        .getAllLeaderboardsIntent()
                        .addOnSuccessListener {
                            activity.startActivityForResult(it, RC_LEADERBOARD_UI)
                            result.success(true)
                        }
                        .addOnFailureListener { result.success(false) }
                    else -> result.notImplemented()
                }
            }
    }
}
