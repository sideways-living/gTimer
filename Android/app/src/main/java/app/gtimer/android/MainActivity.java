package app.gtimer.android;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.EditorInfo;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.GridLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

public final class MainActivity extends Activity {
    private static final String PREFS = "gtimer_android";
    private static final String DOSES_KEY = "doses";
    private static final String CHANNEL_ID = "safe_to_redose";

    private static final int BACKGROUND = Color.rgb(11, 17, 24);
    private static final int PANEL = Color.rgb(17, 25, 36);
    private static final int SURFACE = Color.rgb(31, 41, 55);
    private static final int TEXT = Color.rgb(245, 247, 251);
    private static final int MUTED = Color.rgb(156, 163, 175);
    private static final int BLUE = Color.rgb(59, 130, 246);
    private static final int RED = Color.rgb(248, 71, 73);
    private static final int GREEN = Color.rgb(45, 212, 123);
    private static final int GOLD = Color.rgb(245, 183, 51);

    private final Handler handler = new Handler(Looper.getMainLooper());
    private final List<DoseRecord> doses = new ArrayList<>();
    private SharedPreferences prefs;
    private FrameLayout content;
    private LinearLayout navBar;
    private Settings settings;
    private int selectedTab = 0;

    private final Runnable ticker = new Runnable() {
        @Override
        public void run() {
            if (selectedTab == 0) renderTimer();
            handler.postDelayed(this, 1000);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        settings = Settings.load(prefs);
        loadDoses();
        createNotificationChannel();

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(BACKGROUND);
        content = new FrameLayout(this);
        navBar = new LinearLayout(this);
        navBar.setGravity(Gravity.CENTER);
        navBar.setPadding(dp(10), dp(8), dp(10), dp(10));
        navBar.setBackgroundColor(Color.rgb(20, 29, 42));
        root.addView(content, new LinearLayout.LayoutParams(-1, 0, 1));
        root.addView(navBar, new LinearLayout.LayoutParams(-1, dp(74)));
        setContentView(root);

        renderNav();
        renderTimer();
        handler.post(ticker);
    }

    @Override
    protected void onDestroy() {
        handler.removeCallbacks(ticker);
        super.onDestroy();
    }

    private void renderNav() {
        navBar.removeAllViews();
        addNavButton("gTimer", 0);
        addNavButton("History", 1);
        addNavButton("Map", 2);
        addNavButton("Health", 3);
        addNavButton("Settings", 4);
        addNavButton("gTimer Pro", 5);
    }

    private void addNavButton(String label, int tab) {
        Button button = new Button(this);
        button.setText(label);
        button.setAllCaps(false);
        button.setTextColor(tab == 5 ? Color.WHITE : TEXT);
        button.setTextSize(11);
        button.setBackgroundColor(tab == 5 ? GOLD : (selectedTab == tab ? BLUE : SURFACE));
        button.setOnClickListener(v -> {
            selectedTab = tab;
            renderNav();
            if (tab == 0) renderTimer();
            if (tab == 1) renderHistory();
            if (tab == 2) renderMap();
            if (tab == 3) renderHealth();
            if (tab == 4) renderSettings();
            if (tab == 5) renderPro();
        });
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dp(50), 1);
        lp.setMargins(dp(3), 0, dp(3), 0);
        navBar.addView(button, lp);
    }

    private void renderTimer() {
        selectedTab = 0;
        content.removeAllViews();

        LinearLayout page = page();
        TextView title = title("gTimer");
        page.addView(title);

        DoseRecord latest = latestDose();
        TimerState state = timerState(latest);
        TimerGaugeView gauge = new TimerGaugeView(this);
        gauge.setState(state, settings.countdownMode);
        page.addView(gauge, new LinearLayout.LayoutParams(-1, 0, 1.15f));

        LinearLayout status = pill(state.safe ? GREEN : (state.active ? RED : MUTED), 8);
        TextView line = label(state.statusText, 15, true, state.safe ? GREEN : (state.active ? RED : MUTED));
        status.addView(line);
        if (settings.proBeta && settings.showSafeElapsedTimer && state.active && state.safe) {
            status.addView(label(formatDuration(state.safeElapsedSeconds), 15, true, GREEN));
        }
        LinearLayout.LayoutParams statusLp = new LinearLayout.LayoutParams(-2, -2);
        statusLp.gravity = Gravity.CENTER_HORIZONTAL;
        statusLp.setMargins(0, 0, 0, dp(14));
        page.addView(status, statusLp);

        GridLayout doseGrid = new GridLayout(this);
        doseGrid.setColumnCount(2);
        doseGrid.setRowCount(3);
        doseGrid.setUseDefaultMargins(false);
        addDoseButton(doseGrid, "I took\n" + formatAmount(settings.standardDose), settings.standardDose, true);
        for (double amount : settings.validQuickAmounts()) {
            addDoseButton(doseGrid, formatAmount(amount), amount, false);
        }
        Button custom = flatButton("Different amount", SURFACE, TEXT);
        custom.setOnClickListener(v -> showCustomDoseDialog());
        doseGrid.addView(custom, cell(false));
        Button missed = flatButton("Missed dose", Color.rgb(42, 38, 34), GOLD);
        missed.setOnClickListener(v -> showInfo("Missed dose", "The full missed-dose form with location entry is planned for the next Android parity slice."));
        doseGrid.addView(missed, cell(false));
        page.addView(doseGrid, new LinearLayout.LayoutParams(-1, -2));

        content.addView(page);
    }

    private void addDoseButton(GridLayout grid, String label, double amount, boolean primary) {
        Button button = flatButton(label, primary ? BLUE : SURFACE, TEXT);
        button.setTextSize(primary ? 20 : 16);
        button.setOnClickListener(v -> attemptLogDose(amount));
        grid.addView(button, cell(primary));
    }

    private GridLayout.LayoutParams cell(boolean primary) {
        GridLayout.LayoutParams lp = new GridLayout.LayoutParams();
        lp.width = 0;
        lp.height = primary ? dp(104) : dp(68);
        lp.columnSpec = GridLayout.spec(GridLayout.UNDEFINED, primary ? 2 : 1, 1f);
        lp.setMargins(dp(4), dp(4), dp(4), dp(4));
        return lp;
    }

    private void renderHistory() {
        selectedTab = 1;
        content.removeAllViews();
        ScrollView scroll = new ScrollView(this);
        LinearLayout page = page();
        page.addView(title("History"));
        int max = settings.proBeta ? doses.size() : Math.min(doses.size(), 10);
        if (max == 0) {
            page.addView(body("No doses recorded yet."));
        }
        for (int i = 0; i < max; i++) {
            DoseRecord dose = doses.get(i);
            LinearLayout row = card();
            row.addView(label(formatAmount(dose.amount), 22, true, TEXT));
            row.addView(body(formatDate(dose.timeMillis)));
            if (dose.earlySeconds > 0) {
                row.addView(label("Taken early by " + formatDuration(dose.earlySeconds), 13, true, GOLD));
            }
            if (!dose.notes.isEmpty()) row.addView(body(dose.notes));
            page.addView(row);
        }
        if (!settings.proBeta && doses.size() > max) {
            page.addView(body("gTimer Pro unlocks full history."));
        }
        scroll.addView(page);
        content.addView(scroll);
    }

    private void renderMap() {
        selectedTab = 2;
        content.removeAllViews();
        LinearLayout page = page();
        page.addView(title("Map"));
        page.addView(body(settings.proBeta
                ? "Android map view will use native map controls in the next parity slice."
                : "Dose maps are a gTimer Pro feature."));
        content.addView(page);
    }

    private void renderHealth() {
        selectedTab = 3;
        content.removeAllViews();
        ScrollView scroll = new ScrollView(this);
        LinearLayout page = page();
        page.addView(title("Health"));
        page.addView(body("This information is harm-reduction guidance, not medical advice."));
        page.addView(section("Stay mindful", "Avoid redosing early, avoid mixing substances, and ask for help if someone is hard to wake, breathing slowly, or unwell."));
        page.addView(section("Emergency help", "Use the local emergency number for the country you are in. Localised emergency-number parity will be carried across from the Apple app."));
        scroll.addView(page);
        content.addView(scroll);
    }

    private void renderSettings() {
        selectedTab = 4;
        content.removeAllViews();
        ScrollView scroll = new ScrollView(this);
        LinearLayout page = page();
        page.addView(title("Settings"));

        EditText standard = numberField(settings.standardDose);
        EditText interval = integerField(settings.intervalMinutes);
        CheckBox countdown = checkbox("Countdown mode", settings.countdownMode);
        CheckBox notifications = checkbox("Safe-to-redose notifications", settings.notificationsEnabled);
        CheckBox showSafeElapsed = checkbox("Time since safe (gTimer Pro)", settings.showSafeElapsedTimer);
        showSafeElapsed.setEnabled(settings.proBeta);

        page.addView(fieldBlock("Standard dose", standard));
        page.addView(fieldBlock("Interval minutes", interval));
        page.addView(label("Quick doses", 14, true, MUTED));
        LinearLayout quickRow = new LinearLayout(this);
        quickRow.setOrientation(LinearLayout.HORIZONTAL);
        EditText[] quickFields = new EditText[4];
        for (int i = 0; i < 4; i++) {
            quickFields[i] = settings.quickAmounts[i] > 0 ? numberField(settings.quickAmounts[i]) : numberField("");
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dp(54), 1);
            lp.setMargins(dp(3), dp(4), dp(3), dp(12));
            quickRow.addView(quickFields[i], lp);
        }
        page.addView(quickRow);
        page.addView(countdown);
        page.addView(notifications);
        page.addView(showSafeElapsed);

        Button save = flatButton("Save settings", BLUE, TEXT);
        save.setOnClickListener(v -> {
            settings.standardDose = readDouble(standard, settings.standardDose);
            settings.intervalMinutes = Math.max(1, readInt(interval, settings.intervalMinutes));
            for (int i = 0; i < 4; i++) settings.quickAmounts[i] = Math.max(0, readDouble(quickFields[i], 0));
            settings.countdownMode = countdown.isChecked();
            settings.notificationsEnabled = notifications.isChecked();
            settings.showSafeElapsedTimer = settings.proBeta && showSafeElapsed.isChecked();
            settings.save(prefs);
            if (settings.notificationsEnabled) requestNotificationPermissionIfNeeded();
            renderTimer();
        });
        page.addView(save, new LinearLayout.LayoutParams(-1, dp(56)));

        scroll.addView(page);
        content.addView(scroll);
    }

    private void renderPro() {
        selectedTab = 5;
        content.removeAllViews();
        LinearLayout page = page();
        page.addView(title("gTimer Pro"));
        page.addView(body("The Android port currently mirrors the beta Pro gate locally. Store billing and sync-device registration are next-stage work."));
        Button toggle = flatButton(settings.proBeta ? "Disable beta Pro" : "Enable beta Pro", GOLD, Color.WHITE);
        toggle.setOnClickListener(v -> {
            settings.proBeta = !settings.proBeta;
            if (!settings.proBeta) settings.showSafeElapsedTimer = false;
            settings.save(prefs);
            renderPro();
            renderNav();
        });
        page.addView(toggle, new LinearLayout.LayoutParams(-1, dp(56)));
        content.addView(page);
    }

    private void attemptLogDose(double amount) {
        TimerState state = timerState(latestDose());
        if (state.active && !state.safe) {
            new AlertDialog.Builder(this)
                    .setTitle("Log dose early?")
                    .setMessage("Your minimum time between doses has not passed. This would be logged as early by " + formatDuration(state.remainingSeconds) + ".")
                    .setNegativeButton("Cancel", null)
                    .setPositiveButton("Log anyway", (dialog, which) -> logDose(amount, state.remainingSeconds))
                    .show();
            return;
        }
        logDose(amount, 0);
    }

    private void logDose(double amount, long earlySeconds) {
        doses.add(0, new DoseRecord(UUID.randomUUID().toString(), amount, System.currentTimeMillis(), earlySeconds, ""));
        saveDoses();
        if (settings.notificationsEnabled) requestNotificationPermissionIfNeeded();
        renderTimer();
    }

    private void showCustomDoseDialog() {
        EditText input = numberField("");
        input.setHint("Amount");
        new AlertDialog.Builder(this)
                .setTitle("Log different amount")
                .setView(input)
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Log dose", (dialog, which) -> attemptLogDose(readDouble(input, settings.standardDose)))
                .show();
    }

    private TimerState timerState(DoseRecord latest) {
        if (latest == null) return TimerState.inactive();
        long elapsed = Math.max(0, (System.currentTimeMillis() - latest.timeMillis) / 1000);
        long interval = settings.intervalMinutes * 60L;
        boolean safe = elapsed >= interval;
        long display = settings.countdownMode ? Math.max(interval - elapsed, 0) : elapsed;
        float progress = settings.countdownMode
                ? 1f - Math.min(1f, elapsed / (float) interval)
                : Math.min(1f, elapsed / (float) interval);
        String status = safe ? "Safe to redose" : "Not yet safe";
        return new TimerState(true, safe, display, progress, Math.max(interval - elapsed, 0), Math.max(elapsed - interval, 0), status);
    }

    private DoseRecord latestDose() {
        return doses.isEmpty() ? null : doses.get(0);
    }

    private void loadDoses() {
        doses.clear();
        String raw = prefs.getString(DOSES_KEY, "[]");
        try {
            JSONArray array = new JSONArray(raw);
            for (int i = 0; i < array.length(); i++) {
                doses.add(DoseRecord.fromJson(array.getJSONObject(i)));
            }
        } catch (JSONException ignored) {
            doses.clear();
        }
    }

    private void saveDoses() {
        JSONArray array = new JSONArray();
        for (DoseRecord dose : doses) array.put(dose.toJson());
        prefs.edit().putString(DOSES_KEY, array.toString()).apply();
    }

    private void createNotificationChannel() {
        NotificationChannel channel = new NotificationChannel(CHANNEL_ID, "Safe to redose", NotificationManager.IMPORTANCE_DEFAULT);
        channel.setDescription("Reminders when your configured minimum time between doses has passed.");
        getSystemService(NotificationManager.class).createNotificationChannel(channel);
    }

    private void requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 1001);
        }
    }

    private LinearLayout page() {
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(dp(20), dp(22), dp(20), dp(18));
        page.setBackgroundColor(BACKGROUND);
        return page;
    }

    private LinearLayout card() {
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(dp(16), dp(14), dp(16), dp(14));
        card.setBackgroundColor(PANEL);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.setMargins(0, dp(6), 0, dp(6));
        card.setLayoutParams(lp);
        return card;
    }

    private LinearLayout pill(int color, int pad) {
        LinearLayout pill = new LinearLayout(this);
        pill.setOrientation(LinearLayout.VERTICAL);
        pill.setGravity(Gravity.CENTER);
        pill.setPadding(dp(18), dp(pad), dp(18), dp(pad));
        pill.setBackgroundColor(argb(color, 0.16f));
        return pill;
    }

    private View section(String heading, String text) {
        LinearLayout card = card();
        card.addView(label(heading, 18, true, TEXT));
        card.addView(body(text));
        return card;
    }

    private View fieldBlock(String label, EditText field) {
        LinearLayout block = new LinearLayout(this);
        block.setOrientation(LinearLayout.VERTICAL);
        block.addView(label(label, 14, true, MUTED));
        block.addView(field, new LinearLayout.LayoutParams(-1, dp(54)));
        return block;
    }

    private TextView title(String text) {
        return label(text, 30, true, TEXT);
    }

    private TextView body(String text) {
        TextView view = label(text, 15, false, MUTED);
        view.setPadding(0, dp(4), 0, dp(10));
        return view;
    }

    private TextView label(String text, int size, boolean bold, int color) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextColor(color);
        view.setTextSize(size);
        view.setGravity(Gravity.CENTER_VERTICAL);
        if (bold) view.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        return view;
    }

    private Button flatButton(String text, int background, int textColor) {
        Button button = new Button(this);
        button.setAllCaps(false);
        button.setText(text);
        button.setTextColor(textColor);
        button.setTextSize(14);
        button.setBackgroundColor(background);
        button.setGravity(Gravity.CENTER);
        return button;
    }

    private CheckBox checkbox(String label, boolean checked) {
        CheckBox box = new CheckBox(this);
        box.setText(label);
        box.setTextColor(TEXT);
        box.setTextSize(15);
        box.setChecked(checked);
        box.setButtonTintList(android.content.res.ColorStateList.valueOf(BLUE));
        return box;
    }

    private EditText numberField(double value) {
        return numberField(value > 0 ? String.format(Locale.US, "%.1f", value) : "");
    }

    private EditText integerField(int value) {
        return numberField(String.valueOf(value));
    }

    private EditText numberField(String value) {
        EditText field = new EditText(this);
        field.setText(value);
        field.setSingleLine(true);
        field.setTextColor(TEXT);
        field.setHintTextColor(MUTED);
        field.setTextSize(18);
        field.setInputType(InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_FLAG_DECIMAL);
        field.setImeOptions(EditorInfo.IME_ACTION_DONE);
        field.setBackgroundColor(PANEL);
        field.setPadding(dp(12), 0, dp(12), 0);
        return field;
    }

    private double readDouble(EditText input, double fallback) {
        try {
            return Double.parseDouble(input.getText().toString().trim());
        } catch (NumberFormatException ex) {
            return fallback;
        }
    }

    private int readInt(EditText input, int fallback) {
        try {
            return Integer.parseInt(input.getText().toString().trim());
        } catch (NumberFormatException ex) {
            return fallback;
        }
    }

    private String formatAmount(double amount) {
        return String.format(Locale.US, "%.1f%s", amount, settings.unit);
    }

    private String formatDate(long millis) {
        return new SimpleDateFormat("d MMM yyyy 'at' h:mm a", Locale.getDefault()).format(new Date(millis));
    }

    private String formatDuration(long seconds) {
        long h = seconds / 3600;
        long m = (seconds % 3600) / 60;
        long s = seconds % 60;
        return String.format(Locale.US, "%02d:%02d:%02d", h, m, s);
    }

    private int argb(int rgb, float alpha) {
        return Color.argb(Math.round(255 * alpha), Color.red(rgb), Color.green(rgb), Color.blue(rgb));
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private void showInfo(String title, String message) {
        new AlertDialog.Builder(this)
                .setTitle(title)
                .setMessage(message)
                .setPositiveButton("OK", null)
                .show();
    }

    private static final class Settings {
        double standardDose = 2.8;
        String unit = "ml";
        int intervalMinutes = 90;
        double[] quickAmounts = new double[]{1.5, 2.0, 2.5, 3.0};
        boolean countdownMode = true;
        boolean notificationsEnabled = false;
        boolean proBeta = false;
        boolean showSafeElapsedTimer = false;

        static Settings load(SharedPreferences prefs) {
            Settings s = new Settings();
            s.standardDose = Double.longBitsToDouble(prefs.getLong("standardDose", Double.doubleToLongBits(2.8)));
            s.unit = prefs.getString("unit", "ml");
            s.intervalMinutes = prefs.getInt("intervalMinutes", 90);
            for (int i = 0; i < 4; i++) {
                s.quickAmounts[i] = Double.longBitsToDouble(prefs.getLong("quick" + i, Double.doubleToLongBits(s.quickAmounts[i])));
            }
            s.countdownMode = prefs.getBoolean("countdownMode", true);
            s.notificationsEnabled = prefs.getBoolean("notificationsEnabled", false);
            s.proBeta = prefs.getBoolean("proBeta", false);
            s.showSafeElapsedTimer = prefs.getBoolean("showSafeElapsedTimer", false);
            return s;
        }

        void save(SharedPreferences prefs) {
            SharedPreferences.Editor e = prefs.edit();
            e.putLong("standardDose", Double.doubleToLongBits(standardDose));
            e.putString("unit", unit);
            e.putInt("intervalMinutes", intervalMinutes);
            for (int i = 0; i < 4; i++) e.putLong("quick" + i, Double.doubleToLongBits(quickAmounts[i]));
            e.putBoolean("countdownMode", countdownMode);
            e.putBoolean("notificationsEnabled", notificationsEnabled);
            e.putBoolean("proBeta", proBeta);
            e.putBoolean("showSafeElapsedTimer", showSafeElapsedTimer);
            e.apply();
        }

        List<Double> validQuickAmounts() {
            List<Double> values = new ArrayList<>();
            for (double amount : quickAmounts) {
                if (amount > 0) values.add(amount);
            }
            return values;
        }
    }

    private static final class DoseRecord {
        final String id;
        final double amount;
        final long timeMillis;
        final long earlySeconds;
        final String notes;

        DoseRecord(String id, double amount, long timeMillis, long earlySeconds, String notes) {
            this.id = id;
            this.amount = amount;
            this.timeMillis = timeMillis;
            this.earlySeconds = earlySeconds;
            this.notes = notes;
        }

        JSONObject toJson() {
            JSONObject json = new JSONObject();
            try {
                json.put("id", id);
                json.put("amount", amount);
                json.put("timeMillis", timeMillis);
                json.put("earlySeconds", earlySeconds);
                json.put("notes", notes);
            } catch (JSONException ignored) {
            }
            return json;
        }

        static DoseRecord fromJson(JSONObject json) {
            return new DoseRecord(
                    json.optString("id", UUID.randomUUID().toString()),
                    json.optDouble("amount", 0),
                    json.optLong("timeMillis", System.currentTimeMillis()),
                    json.optLong("earlySeconds", 0),
                    json.optString("notes", "")
            );
        }
    }

    private static final class TimerState {
        final boolean active;
        final boolean safe;
        final long displaySeconds;
        final float progress;
        final long remainingSeconds;
        final long safeElapsedSeconds;
        final String statusText;

        TimerState(boolean active, boolean safe, long displaySeconds, float progress, long remainingSeconds, long safeElapsedSeconds, String statusText) {
            this.active = active;
            this.safe = safe;
            this.displaySeconds = displaySeconds;
            this.progress = progress;
            this.remainingSeconds = remainingSeconds;
            this.safeElapsedSeconds = safeElapsedSeconds;
            this.statusText = statusText;
        }

        static TimerState inactive() {
            return new TimerState(false, false, 0, 0, 0, 0, "No active timer");
        }
    }

    private final class TimerGaugeView extends View {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final RectF arc = new RectF();
        private final Path drop = new Path();
        private TimerState state = TimerState.inactive();
        private boolean countdownMode = true;

        TimerGaugeView(Context context) {
            super(context);
            setMinimumHeight(dp(280));
        }

        void setState(TimerState state, boolean countdownMode) {
            this.state = state;
            this.countdownMode = countdownMode;
            invalidate();
        }

        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            int w = getWidth();
            int h = getHeight();
            float size = Math.min(w - dp(46), h - dp(18));
            float left = (w - size) / 2f;
            float top = (h - size) / 2f;
            arc.set(left, top, left + size, top + size);

            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeCap(Paint.Cap.ROUND);
            paint.setStrokeWidth(dp(20));
            paint.setColor(SURFACE);
            canvas.drawArc(arc, 135, 270, false, paint);

            int color = state.safe ? GREEN : (state.active ? RED : MUTED);
            paint.setColor(color);
            float sweep = 270f * state.progress;
            float start = countdownMode ? 135f : 135f;
            canvas.drawArc(arc, start, sweep, false, paint);

            paint.setStyle(Paint.Style.FILL);
            paint.setColor(BLUE);
            float cx = w / 2f;
            float cy = h / 2f - dp(42);
            drop.reset();
            drop.moveTo(cx, cy - dp(28));
            drop.cubicTo(cx + dp(24), cy + dp(4), cx + dp(18), cy + dp(34), cx, cy + dp(34));
            drop.cubicTo(cx - dp(18), cy + dp(34), cx - dp(24), cy + dp(4), cx, cy - dp(28));
            canvas.drawPath(drop, paint);

            paint.setTextAlign(Paint.Align.CENTER);
            paint.setTypeface(android.graphics.Typeface.create(android.graphics.Typeface.MONOSPACE, android.graphics.Typeface.BOLD));
            paint.setTextSize(dp(44));
            paint.setColor(color);
            canvas.drawText(formatDuration(state.displaySeconds), cx, h / 2f + dp(52), paint);
        }
    }
}
