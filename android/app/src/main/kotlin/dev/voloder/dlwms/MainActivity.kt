package dev.voloder.dlwms

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // "Dodaj u kalendar": opens the calendar app's new-event screen with
        // the exam filled in. No calendar permission is needed because the
        // user confirms (and saves) the event in the calendar app.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.voloder.dlwms/calendar")
            .setMethodCallHandler { call, result ->
                if (call.method != "insertEvent") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val intent = Intent(Intent.ACTION_INSERT)
                    .setData(CalendarContract.Events.CONTENT_URI)
                    .putExtra(CalendarContract.Events.TITLE, call.argument<String>("title"))
                    .putExtra(CalendarContract.Events.DESCRIPTION, call.argument<String>("description"))
                    .putExtra(CalendarContract.Events.EVENT_LOCATION, call.argument<String>("location"))
                    .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, call.argument<Number>("begin")?.toLong() ?: 0L)
                    .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, call.argument<Number>("end")?.toLong() ?: 0L)

                try {
                    startActivity(intent)
                    result.success(true)
                } catch (e: ActivityNotFoundException) {
                    result.success(false)
                }
            }
    }
}
