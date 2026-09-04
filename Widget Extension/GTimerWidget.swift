import WidgetKit
import SwiftUI

// MARK: - Entry

struct GTimerEntry: TimelineEntry {
  var date: Date
  var lastDoseTime: Date?
  var lastDoseAmount: Double
  var lastDoseUnit: String
  var safeIntervalMinutes: Int
  var countdownMode: Bool
}

// MARK: - Provider

struct GTimerProvider: TimelineProvider {

  func placeholder(in context: Context) -> GTimerEntry {
    GTimerEntry(
      date: Date(),
      lastDoseTime: Date().addingTimeInterval(-45 * 60),
      lastDoseAmount: 1.5,
      lastDoseUnit: "ml",
      safeIntervalMinutes: 90,
      countdownMode: true
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (GTimerEntry) -> Void) {
    completion(makeEntry(at: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<GTimerEntry>) -> Void) {
    let now = Date()
    let base = makeEntry(at: now)

    guard let doseTime = base.lastDoseTime,
          now.timeIntervalSince(doseTime) < 6 * 3600 else {
      // No active timer – low-frequency refresh
      completion(Timeline(entries: [base], policy: .after(now.addingTimeInterval(30 * 60))))
      return
    }

    let intervalSecs = Double(base.safeIntervalMinutes) * 60
    let safeDate = doseTime.addingTimeInterval(intervalSecs)

    if now >= safeDate {
      // Already safe – low-frequency refresh
      completion(Timeline(entries: [base], policy: .after(now.addingTimeInterval(15 * 60))))
      return
    }

    // Not yet safe: entries at adaptive stride so full remaining span is covered
    // within ≤60 entries, then an exact boundary entry and one entry 1 min after.
    let remaining = safeDate.timeIntervalSince(now)
    // Divide remaining into ≤60 steps, minimum 2-minute stride
    let strideSeconds = max(2 * 60.0, ceil(remaining / 60.0))

    var entries: [GTimerEntry] = []
    var t = now
    while t < safeDate && entries.count < 60 {
      entries.append(makeEntry(at: t))
      t = t.addingTimeInterval(strideSeconds)
    }
    // Exact boundary: widget flips to Safe state at this moment
    entries.append(makeEntry(at: safeDate))
    entries.append(makeEntry(at: safeDate.addingTimeInterval(60)))

    // Reload 15 min after safe in case user logs another dose
    completion(Timeline(entries: entries, policy: .after(safeDate.addingTimeInterval(15 * 60))))
  }

  private func makeEntry(at date: Date) -> GTimerEntry {
    var doseTime: Date? = nil
    var amount = 1.5
    var unit = "ml"
    var interval = 90
    var countdown = true

    if let raw = AppGroup.sharedDefaults?.data(forKey: AppGroup.lastDoseKey),
       let data = try? JSONDecoder().decode(SharedDoseData.self, from: raw) {
      doseTime = data.lastDoseTime
      amount   = data.lastDoseAmount ?? 1.5
      unit     = data.lastDoseUnit ?? "ml"
      interval = data.safeIntervalMinutes ?? 90
      countdown = data.countdownMode ?? true
    }
    return GTimerEntry(
      date: date,
      lastDoseTime: doseTime,
      lastDoseAmount: amount,
      lastDoseUnit: unit,
      safeIntervalMinutes: interval,
      countdownMode: countdown
    )
  }
}

// MARK: - Computed state

private struct TimerState {
  let isActive: Bool
  let isSafe: Bool
  let progress: Double         // 0…1
  let phase: Phase
  let timeLabel: String        // e.g. "35m", "1h 20m", "< 1m"
  let timeSuffix: String       // "left", "elapsed", or ""
  let statusLabel: String

  enum Phase { case inactive, unsafe, almostSafe, safe }

  static func from(entry: GTimerEntry) -> TimerState {
    guard let doseTime = entry.lastDoseTime else { return .inactive }
    let elapsed = entry.date.timeIntervalSince(doseTime)
    guard elapsed >= 0, elapsed < 6 * 3600 else { return .inactive }

    let intervalSecs = Double(entry.safeIntervalMinutes) * 60
    let isSafe   = elapsed >= intervalSecs
    let progress = min(elapsed / intervalSecs, 1.0)
    let phase: Phase = isSafe ? .safe : (progress >= 0.70 ? .almostSafe : .unsafe)

    // Time label: countdown mode shows remaining until safe; count-up shows elapsed.
    // Both safe states show elapsed.
    let timeLabel: String
    let timeSuffix: String
    if isSafe {
      let t = Int(elapsed)
      let h = t / 3600; let m = (t % 3600) / 60
      timeLabel  = h > 0 ? "\(h)h \(m)m" : (m > 0 ? "\(m)m" : "< 1m")
      timeSuffix = "elapsed"
    } else if entry.countdownMode {
      let r = max(Int(intervalSecs - elapsed), 0)
      let h = r / 3600; let m = (r % 3600) / 60
      timeLabel  = h > 0 ? "\(h)h \(m)m" : (m > 0 ? "\(m)m" : "< 1m")
      timeSuffix = "left"
    } else {
      // Count-up: show elapsed even while unsafe
      let t = Int(elapsed)
      let h = t / 3600; let m = (t % 3600) / 60
      timeLabel  = h > 0 ? "\(h)h \(m)m" : (m > 0 ? "\(m)m" : "< 1m")
      timeSuffix = ""
    }

    let statusLabel: String
    switch phase {
    case .inactive:   statusLabel = "No active timer"
    case .unsafe, .almostSafe:
      let r = max(Int(intervalSecs - elapsed), 0)
      let h = r / 3600; let m = (r % 3600) / 60
      statusLabel = h > 0 ? "Wait \(h)h \(m)m" : "Wait \(m)m"
    case .safe: statusLabel = "Safe to redose"
    }

    return TimerState(isActive: true, isSafe: isSafe, progress: progress,
                      phase: phase, timeLabel: timeLabel, timeSuffix: timeSuffix,
                      statusLabel: statusLabel)
  }

  private static var inactive: TimerState {
    TimerState(isActive: false, isSafe: false, progress: 0,
               phase: .inactive, timeLabel: "--:--", timeSuffix: "",
               statusLabel: "No active timer")
  }

  var color: Color {
    switch phase {
    case .inactive:    return WT.textMuted
    case .unsafe:      return WT.statusRed
    case .almostSafe:  return WT.statusAmber
    case .safe:        return WT.statusGreen
    }
  }
}

// MARK: - Widget theme (hex values mirror AppTheme exactly)

private enum WT {
  static let bg            = Color(red: 16/255,  green: 22/255,  blue: 32/255)   // #101620
  static let accentBlue    = Color(red: 59/255,  green: 130/255, blue: 246/255)  // #3B82F6
  static let statusRed     = Color(red: 239/255, green: 68/255,  blue: 68/255)   // #EF4444
  static let statusAmber   = Color(red: 245/255, green: 158/255, blue: 11/255)   // #F59B0B
  static let statusGreen   = Color(red: 48/255,  green: 209/255, blue: 88/255)   // #30D158
  static let textPrimary   = Color.white
  static let textSecondary = Color(white: 0.62)
  static let textMuted     = Color(white: 0.38)
  static let trackFill     = Color(white: 1.0, opacity: 0.07)
  static let border        = Color(white: 1.0, opacity: 0.10)
}

// MARK: - Small widget

private struct SmallWidgetView: View {
  let entry: GTimerEntry
  private var state: TimerState { TimerState.from(entry: entry) }

  var body: some View {
    VStack(spacing: 0) {
      // Header row
      HStack(spacing: 4) {
        Image(systemName: "drop.fill")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(WT.accentBlue)
        Text("G TIMER")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(WT.textSecondary)
          .kerning(0.4)
        Spacer()
      }
      .padding(.bottom, 6)

      // Arc gauge
      ZStack {
        // Track
        Circle()
          .trim(from: 0.1, to: 0.9)
          .stroke(WT.trackFill, style: StrokeStyle(lineWidth: 8, lineCap: .round))
          .rotationEffect(.degrees(90))
        // Fill
        if state.isActive {
          Circle()
            .trim(from: 0.1, to: 0.1 + 0.8 * state.progress)
            .stroke(state.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .rotationEffect(.degrees(90))
        }
        // Centre text
        VStack(spacing: 2) {
          Text(state.timeLabel)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(state.isActive ? state.color : WT.textMuted)
            .minimumScaleFactor(0.65)
            .lineLimit(1)
          if state.isSafe {
            Image(systemName: "checkmark")
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(WT.statusGreen)
          } else if state.isActive && !state.timeSuffix.isEmpty {
            Text(state.timeSuffix)
              .font(.system(size: 9, weight: .medium))
              .foregroundStyle(WT.textSecondary)
          }
        }
        .padding(.horizontal, 10)
      }
      .frame(width: 84, height: 84)

      Spacer(minLength: 4)

      // Status label
      Text(state.statusLabel)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(state.color)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .padding(12)
    .containerBackground(WT.bg, for: .widget)
    .widgetURL(URL(string: "gtimer://timer"))
  }
}

// MARK: - Medium widget

private struct MediumWidgetView: View {
  let entry: GTimerEntry
  private var state: TimerState { TimerState.from(entry: entry) }

  private var doseTimeString: String {
    guard let t = entry.lastDoseTime, state.isActive else { return "—" }
    return t.formatted(date: .omitted, time: .shortened)
  }

  var body: some View {
    HStack(spacing: 0) {
      leftColumn
      // Custom divider — Divider().background() is unreliable in widgets
      Rectangle()
        .fill(WT.border)
        .frame(width: 0.5)
        .padding(.vertical, 10)
      rightColumn
    }
    .containerBackground(WT.bg, for: .widget)
    .widgetURL(URL(string: "gtimer://timer"))
  }

  // Left: title / status badge / big time / progress bar
  private var leftColumn: some View {
    VStack(alignment: .leading, spacing: 5) {
      // Title
      HStack(spacing: 5) {
        Image(systemName: "drop.fill")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(WT.accentBlue)
        Text("gTimer")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(WT.textPrimary)
      }

      // Status badge
      HStack(spacing: 4) {
        Circle()
          .fill(state.color)
          .frame(width: 6, height: 6)
        Text(state.statusLabel)
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(state.color)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .padding(.horizontal, 7)
      .padding(.vertical, 4)
      .background(state.color.opacity(0.12))
      .clipShape(Capsule())

      Spacer(minLength: 0)

      // Big time display
      HStack(alignment: .lastTextBaseline, spacing: 3) {
        Text(state.timeLabel)
          .font(.system(size: 26, weight: .bold, design: .monospaced))
          .foregroundStyle(state.isActive ? state.color : WT.textMuted)
          .lineLimit(1)
          .minimumScaleFactor(0.55)
        if state.isActive && !state.timeSuffix.isEmpty {
          Text(state.timeSuffix)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(WT.textSecondary)
            .lineLimit(1)
        }
      }

      // Progress bar
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(WT.trackFill)
            .frame(height: 5)
          if state.isActive {
            Capsule()
              .fill(state.color)
              .frame(width: max(geo.size.width * state.progress, 0), height: 5)
          }
        }
      }
      .frame(height: 5)
    }
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }

  // Right: dose details or empty-state prompt
  private var rightColumn: some View {
    VStack(alignment: .leading, spacing: 8) {
      if state.isActive {
        // Amount + unit
        HStack(alignment: .lastTextBaseline, spacing: 2) {
          Text(entry.lastDoseAmount.formatted(.number.precision(.fractionLength(1))))
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(WT.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
          Text(entry.lastDoseUnit)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(WT.textSecondary)
        }

        // Time of dose
        HStack(spacing: 4) {
          Image(systemName: "clock")
            .font(.system(size: 10))
            .foregroundStyle(WT.textMuted)
          Text(doseTimeString)
            .font(.system(size: 11))
            .foregroundStyle(WT.textSecondary)
            .lineLimit(1)
        }

        Spacer(minLength: 0)

        // Safe interval setting
        HStack(spacing: 4) {
          Image(systemName: "shield.fill")
            .font(.system(size: 9))
            .foregroundStyle(WT.textMuted)
          Text("\(entry.safeIntervalMinutes)m interval")
            .font(.system(size: 11))
            .foregroundStyle(WT.textMuted)
            .lineLimit(1)
        }
      } else {
        // No active dose
        Spacer()
        VStack(spacing: 6) {
          Image(systemName: "drop")
            .font(.system(size: 20))
            .foregroundStyle(WT.textMuted)
          Text("No Active\ngTimer")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(WT.textMuted)
            .multilineTextAlignment(.center)
            .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        Spacer()
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

// MARK: - Entry view dispatcher

struct GTimerWidgetView: View {
  var entry: GTimerEntry
  @Environment(\.widgetFamily) var family

  var body: some View {
    switch family {
    case .systemMedium:
      MediumWidgetView(entry: entry)
    default:
      SmallWidgetView(entry: entry)
    }
  }
}

// MARK: - Widget declaration

@main
struct GTimerWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: "app.bitrig.new.cc0b1024-f41a-488c-b5dd-b6845c513c01.widget",
      provider: GTimerProvider()
    ) { entry in
      GTimerWidgetView(entry: entry)
    }
    .configurationDisplayName("gTimer")
    .description("Track your GHB/GBL dosing interval.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
