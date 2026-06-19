package com.memory.memory_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import java.io.File

class MemoryWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_layout)

        // Read data saved by Flutter's HomeWidget package
        val prefs = context.getSharedPreferences("HomeWidgetPrefs", Context.MODE_PRIVATE)

        val username = prefs.getString("widget_username", "Memory App")
        val timestamp = prefs.getString("widget_timestamp", "No memories yet")
        val imagePath = prefs.getString("widget_image", null)
        val avatarPath = prefs.getString("widget_avatar", null)

        // Set Text details
        views.setTextViewText(R.id.widget_username, username)
        views.setTextViewText(R.id.widget_timestamp, timestamp)

        // Load Memory Image (bypass sandbox access permission issues by loading inside app process context)
        if (imagePath != null && File(imagePath).exists()) {
            try {
                val bitmap = BitmapFactory.decodeFile(imagePath)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_image, bitmap)
                } else {
                    views.setImageViewResource(R.id.widget_image, 0)
                }
            } catch (e: Exception) {
                views.setImageViewResource(R.id.widget_image, 0)
            }
        } else {
            // Placeholder/Clear
            views.setImageViewResource(R.id.widget_image, 0)
        }

        // Load Avatar
        if (avatarPath != null && File(avatarPath).exists()) {
            try {
                val avatarBitmap = BitmapFactory.decodeFile(avatarPath)
                if (avatarBitmap != null) {
                    views.setViewVisibility(R.id.widget_avatar, View.VISIBLE)
                    views.setImageViewBitmap(R.id.widget_avatar, avatarBitmap)
                } else {
                    views.setViewVisibility(R.id.widget_avatar, View.GONE)
                }
            } catch (e: Exception) {
                views.setViewVisibility(R.id.widget_avatar, View.GONE)
            }
        } else {
            views.setViewVisibility(R.id.widget_avatar, View.GONE)
        }

        // Configure click intent to open the app (MainActivity)
        val intent = Intent(context, MainActivity::class.java).apply {
            action = "com.memory.memory_app.ACTION_LAUNCH"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra("route", "/feed")
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            appWidgetId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        // Instruct the widget manager to update the widget
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // If home_widget triggers update via broadcast
        if (AppWidgetManager.ACTION_APPWIDGET_UPDATE == intent.action) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, MemoryWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }
}
