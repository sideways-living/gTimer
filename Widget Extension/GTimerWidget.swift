import WidgetKit
import SwiftUI

struct GTimerEntry: TimelineEntry {
  var date: Date
  var lastDoseTime: Date?
  var lastDoseAmount: Double?
  var lastDoseUnit: String?
  var safeIntervalMinutes: Int
}

struct GTimerProvider: TimelineProvider {
  func placeholder(in context: Context) -> GTimerEntry {
    GTimerEntry(date: Date(), safeIntervalMinutes: 90)
  }

  func getSnapshot(in context: Context, completion: @escaping (GTimerEntry) -> Void) {
    completion(entry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<GTimerEntry>) -> Void) {
    let e = entry()
    var dates: [Date] = [Date()]
    // Refresh every minute while active
    if e.lastDoseTime != nil {
      for i in 1...60 {
        dates.append(Date().addingTimeInterval(Double(i) * 60))
      }
    }
    let entries = dates.map { d -> GTimerEntry in
      var en = e
      en.date = d
      return en
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }

  private func entry() -> GTimerEntry {
    var data = SharedDoseData(safeIntervalMinutes: 90)
    if let raw = AppGroup.sharedDefaults?.data(forKey: AppGroup.lastDoseKey),
       let decoded = try? JSONDecoder().decode(SharedDoseData.self, from: raw) {
      data = decoded
    }
    return GTimerEntry(
      date: Date(),
      lastDoseTime: data.lastDoseTime,
      lastDoseAmount: data.lastDoseAmount,
      lastDoseUnit: data.lastDoseUnit,
      safeIntervalMinutes: data.safeIntervalMinutes ?? 90
    )
  }
}

struct GTimerWidgetView: View {
  var entry: GTimerEntry
  @Environment(\.widgetFamily) var family

  private var elapsed: TimeInterval {
    guard let t = entry.lastDoseTime else { return 0 }
    return entry.date.timeIntervalSince(t)
  }
  private var intervalSecs: TimeInterval { Double(entry.safeIntervalMinutes) * 60 }
  private var isActive: Bool {
    guard entry.lastDoseTime != nil else { return false }
    return elapsed < 6 * 3600
  }
  private var isSafe: Bool { elapsed >= intervalSecs }
  private var progress: Double { isActive ? min(elapsed / intervalSecs, 1.0) : 0 }

  private var statusColor: Color {
    guard isActive else { return .gray }
    if progress < 0.70 { return .red }
    if progress < 1.0  { return .orange }
    return .green
  }

  private var timeString: String {
    guard isActive else { return "--:--" }
    let remaining = max(intervalSecs - elapsed, 0)
    let t = Int(isSafe ? elapsed : remaining)
    let h = t / 3600; let m = (t % 3600) / 60; let s = t % 60
    if h > 0 { return String(format: "%02d:%02d:%02d", h, m, s) }
    return String(format: "%02d:%02d", m, s)
  }

  var body: some View {
    ZStack {
      Color(red: 0.063, green: 0.086, blue: 0.118)
      VStack(spacing: 6) {
        HStack(spacing: 5) {
          Image(systemName: "drop.fill")
            .font(.system(size: 11))
            .foregroundStyle(Color(red: 0.231, green: 0.510, blue: 0.965))
          Text("G Timer")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
        }

        ZStack {
          Circle()
            .trim(from: 0.1, to: 0.9)
            .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            .rotationEffect(.degrees(90))
          if isActive {
            Circle()
              .trim(from: 0.1, to: 0.1 + 0.8 * progress)
              .stroke(statusColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
              .rotationEffect(.degrees(90))
          }
          Text(timeString)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(isActive ? statusColor : .gray)
        }
        .frame(width: 70, height: 70)

        Text(isSafe ? "Safe" : (isActive ? "Wait" : "No dose"))
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(statusColor)
      }
      .padding(8)
    }
    .containerBackground(Color(red: 0.063, green: 0.086, blue: 0.118), for: .widget)
  }
}

@main
struct GTimerWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "app.bitrig.new.cc0b1024-f41a-488c-b5dd-b6845c513c01.widget", provider: GTimerProvider()) { entry in
      GTimerWidgetView(entry: entry)
    }
    .configurationDisplayName("G Timer")
    .description("Track your GHB/GBL dosing interval.")
    .supportedFamilies([.systemSmall])
  }
}
