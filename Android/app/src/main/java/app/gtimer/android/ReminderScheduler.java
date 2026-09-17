package app.gtimer.android;

import android.app.AlarmManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;

final class ReminderScheduler {
    static final String CHANNEL_ID = "safe_to_redose";
    private static final int ALARM_REQUEST_CODE = 4101;

    private ReminderScheduler() {
    }

    static void ensureNotificationChannel(Context context) {
        NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Minimum dose interval reminders",
                NotificationManager.IMPORTANCE_DEFAULT
        );
        channel.setDescription("Reminders when your configured minimum time between doses has passed.");
        context.getSystemService(NotificationManager.class).createNotificationChannel(channel);
    }

    static void schedule(Context context, long doseTimeMillis, int intervalMinutes) {
        long triggerAt = doseTimeMillis + Math.max(1, intervalMinutes) * 60_000L;
        if (triggerAt <= System.currentTimeMillis()) {
            cancel(context);
            return;
        }

        ensureNotificationChannel(context);
        AlarmManager alarms = context.getSystemService(AlarmManager.class);
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, reminderIntent(context));
    }

    static void cancel(Context context) {
        context.getSystemService(AlarmManager.class).cancel(reminderIntent(context));
    }

    private static PendingIntent reminderIntent(Context context) {
        Intent intent = new Intent(context, RedoseReminderReceiver.class);
        intent.setAction("app.gtimer.android.SHOW_REDOSE_REMINDER");
        return PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
    }
}
