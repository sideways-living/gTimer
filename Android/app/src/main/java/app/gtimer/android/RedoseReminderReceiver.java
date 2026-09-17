package app.gtimer.android;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;

public final class RedoseReminderReceiver extends BroadcastReceiver {
    private static final int NOTIFICATION_ID = 4102;
    private static final String MESSAGE_INDEX_KEY = "redoseReminderMessageIndex";
    private static final String[] MESSAGES = {
            "Stay mindful of your choices",
            "Please consider your wellbeing before any decision.",
            "Make informed choices.",
            "This is a reminder, not a recommendation.",
            "Ask yourself 'Do I need another dose right now?'"
    };

    @Override
    public void onReceive(Context context, Intent intent) {
        if (Build.VERSION.SDK_INT >= 33
                && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            return;
        }

        ReminderScheduler.ensureNotificationChannel(context);
        Intent openApp = new Intent(context, MainActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent contentIntent = PendingIntent.getActivity(
                context,
                0,
                openApp,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        String message = nextMessage(context);
        Notification notification = new Notification.Builder(context, ReminderScheduler.CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notification_drop)
                .setContentTitle("Your minimum time between doses has passed")
                .setContentText(message)
                .setStyle(new Notification.BigTextStyle().bigText(message))
                .setContentIntent(contentIntent)
                .setAutoCancel(true)
                .build();
        context.getSystemService(NotificationManager.class).notify(NOTIFICATION_ID, notification);
    }

    private String nextMessage(Context context) {
        SharedPreferences prefs = context.getSharedPreferences("gtimer_android", Context.MODE_PRIVATE);
        int index = Math.floorMod(prefs.getInt(MESSAGE_INDEX_KEY, 0), MESSAGES.length);
        prefs.edit().putInt(MESSAGE_INDEX_KEY, (index + 1) % MESSAGES.length).apply();
        return MESSAGES[index];
    }

}
