package com.zoezidesk.staff

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The channel app notifications arrive on (the server sends
        // channel_id "general"). Creating it again is harmless.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "general",
                "Gym alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "Class changes, the evening summary and front-desk PIN lockouts" }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
