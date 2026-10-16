package com.tindahan.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Android Home Screen Widget for Tindahan (SariMe).
 * Provides quick glanceable metrics (today's sales, profit, low stock items)
 * and 1-tap direct shortcuts into POS Sell and Barcode Scanner.
 */
class SariWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val storeName = widgetData.getString("store_name", "SariMe Store") ?: "SariMe Store"
        val todaySales = widgetData.getString("today_sales", "₱0.00") ?: "₱0.00"
        val todayProfit = widgetData.getString("today_profit", "₱0.00") ?: "₱0.00"
        val lowStock = widgetData.getString("low_stock_count", "0 items") ?: "0 items"
        val lastUpdated = widgetData.getString("last_updated", "Live") ?: "Live"

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.sari_widget_layout).apply {
                // Set text fields
                setTextViewText(R.id.widget_store_name, storeName)
                setTextViewText(R.id.widget_today_sales, todaySales)
                setTextViewText(R.id.widget_today_profit, todayProfit)
                setTextViewText(R.id.widget_low_stock, lowStock)
                setTextViewText(R.id.widget_last_updated, lastUpdated)

                // Body click -> Open app
                val rootIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("tindahan://home"),
                )
                setOnClickPendingIntent(R.id.widget_root, rootIntent)

                // Quick action: Sell
                val sellIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("tindahan://sell"),
                )
                setOnClickPendingIntent(R.id.widget_btn_sell, sellIntent)

                // Quick action: Scan barcode
                val scanIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("tindahan://scan"),
                )
                setOnClickPendingIntent(R.id.widget_btn_scan, scanIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
