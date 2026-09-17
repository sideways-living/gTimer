package app.gtimer.android;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONException;

public final class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (!Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) return;

        SharedPreferences prefs = context.getSharedPreferences("gtimer_android", Context.MODE_PRIVATE);
        if (!prefs.getBoolean("notificationsEnabled", false)) return;

        try {
            JSONArray doses = new JSONArray(prefs.getString("doses", "[]"));
            if (doses.length() == 0) return;
            long latestDoseTime = doses.getJSONObject(0).optLong("timeMillis", 0);
            int intervalMinutes = prefs.getInt("intervalMinutes", 90);
            if (latestDoseTime > 0) {
                ReminderScheduler.schedule(context, latestDoseTime, intervalMinutes);
            }
        } catch (JSONException ignored) {
            ReminderScheduler.cancel(context);
        }
    }
}
