package com.inovaara.inkling

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StyleSpan
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

/**
 * Inkling's home-screen widget. The app pushes a JSON snapshot (see widget_sync.dart);
 * everything that depends on "today" is worked out here so the widget stays right
 * after midnight even when the app isn't running.
 */
class InklingWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val state = WidgetState.read(widgetData)
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, WidgetRenderer.render(context, state, appWidgetManager.getAppWidgetOptions(id)))
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val state = WidgetState.read(HomeWidgetPlugin.getData(context))
        appWidgetManager.updateAppWidget(appWidgetId, WidgetRenderer.render(context, state, newOptions))
    }
}

internal class WidgetState(
    private val entryDates: Set<LocalDate>,
    private val runEnd: LocalDate?,
    private val runLength: Int,
    val snippet: String,
    val snippetDate: LocalDate?,
    val firstWeekday: Int,
    val colors: Map<String, Pair<Int, Int>>,
) {
    /** A streak stays alive until the day after its last entry is over. */
    fun streak(today: LocalDate): Int =
        if (runEnd != null && (runEnd == today || runEnd == today.minusDays(1))) runLength else 0

    fun writtenOn(day: LocalDate) = day in entryDates

    companion object {
        fun read(prefs: SharedPreferences): WidgetState {
            val json = try {
                JSONObject(prefs.getString("inkling_state", null) ?: "{}")
            } catch (e: Exception) {
                JSONObject()
            }
            val dates = mutableSetOf<LocalDate>()
            json.optJSONArray("entryDates")?.let { array ->
                for (i in 0 until array.length()) parseDate(array.optString(i))?.let(dates::add)
            }
            val colors = mutableMapOf<String, Pair<Int, Int>>()
            json.optJSONObject("colors")?.let { obj ->
                for (key in obj.keys()) {
                    val pair = obj.optJSONArray(key) ?: continue
                    if (pair.length() == 2) colors[key] = pair.optLong(0).toInt() to pair.optLong(1).toInt()
                }
            }
            return WidgetState(
                entryDates = dates,
                runEnd = parseDate(json.optString("runEnd")),
                runLength = json.optInt("runLength", 0),
                snippet = json.optString("snippet", ""),
                snippetDate = parseDate(json.optString("snippetDate")),
                firstWeekday = json.optInt("firstWeekday", 1).coerceIn(1, 7),
                colors = colors,
            )
        }

        // optString() turns JSON null into "null".
        private fun parseDate(s: String?): LocalDate? = try {
            if (s.isNullOrBlank() || s == "null") null else LocalDate.parse(s)
        } catch (e: Exception) {
            null
        }
    }
}

internal object WidgetRenderer {
    private val CELLS = intArrayOf(R.id.day0, R.id.day1, R.id.day2, R.id.day3, R.id.day4, R.id.day5, R.id.day6)
    private val LABELS = intArrayOf(
        R.id.day0_label, R.id.day1_label, R.id.day2_label, R.id.day3_label,
        R.id.day4_label, R.id.day5_label, R.id.day6_label,
    )
    private val DOTS = intArrayOf(
        R.id.day0_dot, R.id.day1_dot, R.id.day2_dot, R.id.day3_dot,
        R.id.day4_dot, R.id.day5_dot, R.id.day6_dot,
    )
    private val NUMS = intArrayOf(
        R.id.day0_num, R.id.day1_num, R.id.day2_num, R.id.day3_num,
        R.id.day4_num, R.id.day5_num, R.id.day6_num,
    )

    fun render(context: Context, state: WidgetState, options: Bundle?): RemoteViews {
        val today = LocalDate.now()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // The launcher picks the biggest layout that fits as the widget is resized.
            return RemoteViews(
                mapOf(
                    SizeF(100f, 40f) to small(context, state, today),
                    SizeF(220f, 100f) to full(context, state, today, tall = false),
                    SizeF(220f, 160f) to full(context, state, today, tall = true),
                ),
            )
        }
        val width = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0
        val height = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT) ?: 0
        return if (width in 1 until 220 || height in 1 until 100) {
            small(context, state, today)
        } else {
            full(context, state, today, tall = height >= 160)
        }
    }

    private fun full(context: Context, state: WidgetState, today: LocalDate, tall: Boolean): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.inkling_widget)
        val paint = Painter(context, views, state.colors)
        val streak = state.streak(today)
        val written = state.writtenOn(today)

        paint.tint(R.id.bg, "bg")
        paint.text(R.id.title, "fg")
        paint.text(R.id.streak, "fg")
        paint.text(R.id.message, "fg")
        paint.tint(R.id.write_bg, "accent")
        paint.tint(R.id.write_icon, "onAccent")
        paint.text(R.id.write_label, "onAccent")

        views.setTextViewText(R.id.streak, if (streak > 0) "🔥 $streak" else "✨")
        views.setTextViewText(R.id.write_label, context.getString(if (written) R.string.widget_add else R.string.widget_write))
        views.setTextViewText(R.id.message, message(context, state, today, streak, written))
        views.setInt(R.id.message, "setMaxLines", if (tall) 4 else 2)
        // Tall widgets have room for Inky in the corner; keep the text clear of it.
        views.setViewVisibility(R.id.mascot, if (tall) View.VISIBLE else View.GONE)
        val inkySpace = if (tall) (72 * context.resources.displayMetrics.density).toInt() else 0
        views.setViewPadding(R.id.message, 0, 0, inkySpace, 0)

        val offset = ((today.dayOfWeek.value - state.firstWeekday) % 7 + 7) % 7
        val start = today.minusDays(offset.toLong())
        val locale = Locale.getDefault()
        for (i in 0 until 7) {
            val day = start.plusDays(i.toLong())
            val isToday = day == today
            val future = day.isAfter(today)
            views.setTextViewText(LABELS[i], day.dayOfWeek.getDisplayName(TextStyle.NARROW, locale))
            views.setTextViewText(NUMS[i], day.dayOfMonth.toString())
            paint.text(LABELS[i], "muted")
            when {
                state.writtenOn(day) -> {
                    views.setImageViewResource(DOTS[i], if (isToday) R.drawable.widget_dot_today_filled else R.drawable.widget_dot_filled)
                    views.setViewVisibility(DOTS[i], View.VISIBLE)
                    paint.tint(DOTS[i], "accent")
                    paint.text(NUMS[i], "onAccent")
                }
                isToday -> {
                    views.setImageViewResource(DOTS[i], R.drawable.widget_dot_ring)
                    views.setViewVisibility(DOTS[i], View.VISIBLE)
                    paint.tint(DOTS[i], "accent")
                    paint.text(NUMS[i], "accent")
                }
                else -> {
                    views.setViewVisibility(DOTS[i], View.INVISIBLE)
                    if (future) paint.text(NUMS[i], "muted", alpha = 0.45f) else paint.text(NUMS[i], "fg")
                }
            }
            if (!future) views.setOnClickPendingIntent(CELLS[i], launch(context, "inkling://write?date=$day"))
        }

        views.setOnClickPendingIntent(R.id.widget_root, launch(context, "inkling://write"))
        views.setOnClickPendingIntent(R.id.write_btn, launch(context, "inkling://write"))
        views.setOnClickPendingIntent(R.id.title, launch(context, "inkling://calendar"))
        return views
    }

    private fun small(context: Context, state: WidgetState, today: LocalDate): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.inkling_widget_small)
        val paint = Painter(context, views, state.colors)
        val streak = state.streak(today)

        paint.tint(R.id.bg, "bg")
        paint.text(R.id.message, "fg")
        paint.text(R.id.streak, "muted")
        paint.tint(R.id.write_bg, "accent")
        paint.tint(R.id.write_icon, "onAccent")

        views.setTextViewText(
            R.id.message,
            context.getString(if (state.writtenOn(today)) R.string.widget_written else R.string.widget_prompt),
        )
        views.setTextViewText(
            R.id.streak,
            if (streak > 0) context.getString(R.string.widget_streak, streak) else context.getString(R.string.widget_start_streak),
        )
        views.setOnClickPendingIntent(R.id.widget_root, launch(context, "inkling://write"))
        return views
    }

    private fun message(context: Context, state: WidgetState, today: LocalDate, streak: Int, written: Boolean): CharSequence =
        when {
            written && state.snippetDate == today && state.snippet.isNotBlank() ->
                SpannableString("“${state.snippet}”").apply {
                    setSpan(StyleSpan(Typeface.ITALIC), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                }
            written -> context.getString(R.string.widget_written)
            streak > 0 -> context.getString(R.string.widget_keep_streak, streak)
            else -> context.getString(R.string.widget_prompt)
        }

    private fun launch(context: Context, uri: String): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))
}

/** Applies the app's light/dark colours, falling back to the XML defaults before the first sync. */
private class Painter(
    context: Context,
    private val views: RemoteViews,
    private val colors: Map<String, Pair<Int, Int>>,
) {
    private val resources = context.resources
    private val night =
        (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

    fun tint(id: Int, name: String) = apply(id, "setColorFilter", name, 1f)

    fun text(id: Int, name: String, alpha: Float = 1f) = apply(id, "setTextColor", name, alpha)

    private fun apply(id: Int, method: String, name: String, alpha: Float) {
        val pair = colors[name]
        if (pair == null) {
            val res = FALLBACKS[name] ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setColor(id, method, res)
            } else {
                @Suppress("DEPRECATION")
                views.setInt(id, method, resources.getColor(res))
            }
            return
        }
        val light = withAlpha(pair.first, alpha)
        val dark = withAlpha(pair.second, alpha)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setColorInt(id, method, light, dark)
        } else {
            views.setInt(id, method, if (night) dark else light)
        }
    }

    private fun withAlpha(color: Int, alpha: Float): Int =
        if (alpha >= 1f) color else (color and 0x00FFFFFF) or ((255 * alpha).toInt() shl 24)

    companion object {
        private val FALLBACKS = mapOf(
            "bg" to R.color.widget_bg,
            "fg" to R.color.widget_fg,
            "muted" to R.color.widget_muted,
            "accent" to R.color.widget_accent,
            "onAccent" to R.color.widget_on_accent,
        )
    }
}
