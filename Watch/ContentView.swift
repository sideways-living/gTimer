import SwiftUI

struct ContentView: View {
  @State private var now = Date()
  @State private var ticker: Timer?
  @State private var doseData: SharedDoseData?

  private var elapsed: TimeInterval {
    guard let t = doseData?.lastDoseTime else { return 0 }
    return now.timeIntervalSince(t)
  }
  private var intervalSecs: TimeInterval {
    Double(doseData?.safeIntervalMinutes ?? 90) * 60
  }
  private var isActive: Bool {
    guard doseData?.lastDoseTime != nil else { return false }
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
    let t = Int(isSafe ? elapsed : max(intervalSecs - elapsed, 0))
    let h = t / 3600; let m = (t % 3600) / 60; let s = t % 60
    return String(format: "%02d:%02d:%02d", h, m, s)
  }

  var body: some View {
    ZStack {
      Color(red: 0.063, green: 0.086, blue: 0.118).ignoresSafeArea()
      VStack(spacing: 8) {
        HStack(spacing: 5) {
          Image(systemName: "drop.fill")
            .foregroundStyle(Color(red: 0.231, green: 0.510, blue: 0.965))
          Text("gTimer")
            .font(.headline)
            .foregroundStyle(.white)
        }

        ZStack {
          Circle()
            .trim(from: 0.1, to: 0.9)
            .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .rotationEffect(.degrees(90))
          if isActive {
            Circle()
              .trim(from: 0.1, to: 0.1 + 0.8 * progress)
              .stroke(statusColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
              .rotationEffect(.degrees(90))
              .animation(.easeInOut(duration: 0.5), value: progress)
          }
          Text(isActive ? timeString : "--:--:--")
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundStyle(isActive ? statusColor : .gray)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
        }
        .frame(width: 110, height: 110)

        Text(isActive ? (isSafe ? "Safe to redose" : "Not yet safe") : "No active timer")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(statusColor)

        if let d = doseData, let amt = d.lastDoseAmount {
          Text("Last: \(amt.formatted(.number.precision(.fractionLength(1))))\(d.lastDoseUnit ?? "ml")")
            .font(.system(size: 11))
            .foregroundStyle(.gray)
        }
      }
      .padding()
    }
    .onAppear {
      loadData()
      ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
        now = Date()
        loadData()
      }
    }
    .onDisappear { ticker?.invalidate() }
  }

  private func loadData() {
    guard let raw = AppGroup.sharedDefaults?.data(forKey: AppGroup.lastDoseKey),
          let decoded = try? JSONDecoder().decode(SharedDoseData.self, from: raw) else { return }
    doseData = decoded
  }
}
