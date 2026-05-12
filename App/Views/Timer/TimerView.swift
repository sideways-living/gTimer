import SwiftUI
import SwiftData

struct TimerView: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(\.modelContext) private var context
  @Query(sort: \DoseRecord.time, order: .reverse) private var doses: [DoseRecord]

  @State private var now = Date()
  @State private var showCustomSheet = false
  @State private var showMissedSheet = false
  @State private var showWarning = false
  @State private var pendingAmount: Double = 0
  @State private var ticker: Timer?

  private var lastDose: DoseRecord? { doses.first }

  private var isActive: Bool {
    guard let d = lastDose else { return false }
    return now.timeIntervalSince(d.time) < 6 * 3600
  }

  private var elapsed: TimeInterval {
    guard let d = lastDose else { return 0 }
    return now.timeIntervalSince(d.time)
  }

  private var intervalSeconds: TimeInterval { Double(settings.safeIntervalMinutes) * 60 }
  private var isSafe: Bool { elapsed >= intervalSeconds }
  private var progress: Double { isActive ? min(elapsed / intervalSeconds, 1.0) : 0 }

  private var statusColor: Color {
    guard isActive else { return AppTheme.textMuted }
    if progress < 0.70 { return AppTheme.statusRed }
    if progress < 1.0  { return AppTheme.statusAmber }
    return AppTheme.statusGreen
  }

  private var displayTime: TimeInterval {
    guard isActive else { return 0 }
    if settings.countdownMode && !isSafe { return max(intervalSeconds - elapsed, 0) }
    return elapsed
  }

  private var timeString: String {
    guard isActive else { return "00:00:00" }
    let t = Int(displayTime)
    return String(format: "%02d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60)
  }

  private var statusLabel: String {
    guard isActive else { return "No Active G Timer" }
    if isSafe { return "Safe to redose" }
    let r = Int(intervalSeconds - elapsed)
    let h = r / 3600; let m = (r % 3600) / 60
    return h > 0 ? "Wait \(h)h \(m)min" : "Wait \(m)min"
  }

  var body: some View {
    NavigationStack {
      ZStack(alignment: .top) {
        AppTheme.backgroundPrimary.ignoresSafeArea()
        ScrollView {
          VStack(spacing: 0) {
            gaugeSection
              .padding(.top, 24)
            statusBadge
            actionButtons
              .padding(.top, 8)
            if let d = lastDose, isActive {
              lastDoseCard(d)
                .padding(.top, 4)
            }
          }
          .padding(.bottom, 100)
        }
      }
      .navigationTitle("")
      .toolbar {
        ToolbarItem(placement: .principal) {
          HStack(spacing: 7) {
            Image(systemName: "drop.fill")
              .font(.system(size: 17, weight: .bold))
              .foregroundStyle(AppTheme.accentBlue)
            Text("G Timer")
              .font(.system(size: 20, weight: .bold))
              .foregroundStyle(AppTheme.textPrimary)
          }
        }
      }
      .toolbarColorScheme(.dark, for: .navigationBar)
    }
    .onAppear { startTicker() }
    .onDisappear { ticker?.invalidate() }
    .sheet(isPresented: $showCustomSheet) {
      CustomDoseSheet { attemptLog(amount: $0) }
    }
    .sheet(isPresented: $showMissedSheet) {
      MissedDoseSheet()
    }
    .alert("Log Early?", isPresented: $showWarning) {
      Button("Cancel", role: .cancel) {}
      Button("Log Anyway", role: .destructive) { confirmLog(amount: pendingAmount) }
    } message: {
      Text("The safe interval hasn't passed yet. Logging early can increase risk.")
    }
  }

  // MARK: - Gauge

  private var gaugeSection: some View {
    ArcGaugeView(
      progress: progress,
      statusColor: statusColor,
      timeString: timeString,
      statusLabel: statusLabel,
      isActive: isActive
    )
  }

  // MARK: - Status pill

  private var statusBadge: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(isActive ? statusColor : AppTheme.textMuted)
        .frame(width: 8, height: 8)
      Text(isActive ? (isSafe ? "Safe to redose" : "Not yet safe") : "No active timer")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(isActive ? statusColor : AppTheme.textMuted)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 7)
    .background((isActive ? statusColor : AppTheme.textMuted).opacity(0.12))
    .clipShape(Capsule())
    .padding(.top, 12)
    .padding(.bottom, 20)
  }

  // MARK: - Action buttons

  private var actionButtons: some View {
    VStack(spacing: 12) {
      Button {
        attemptLog(amount: settings.standardDose)
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 18))
          Text("I took \(settings.standardDose.formatted(.number.precision(.fractionLength(1))))\(settings.unit)")
            .font(.system(size: 18, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 17)
        .background(AppTheme.accentBlue)
        .clipShape(RoundedRectangle(cornerRadius: 16))
      }
      .padding(.horizontal, 20)

      // Quick amounts — 4-column compact row
      HStack(spacing: 8) {
        ForEach(settings.quickAmounts.prefix(4), id: \.self) { amt in
          Button {
            attemptLog(amount: amt)
          } label: {
            Text("\(amt.formatted(.number.precision(.fractionLength(1))))\(settings.unit)")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(AppTheme.accentBlue)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 9)
              .background(AppTheme.accentBlue.opacity(0.13))
              .clipShape(RoundedRectangle(cornerRadius: 10))
          }
        }
      }
      .padding(.horizontal, 20)

      // Custom + Missed row
      HStack(spacing: 10) {
        Button {
          showCustomSheet = true
        } label: {
          HStack(spacing: 5) {
            Image(systemName: "pencil")
            Text("Custom")
          }
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(AppTheme.textSecondary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 11)
          .background(AppTheme.backgroundCard)
          .clipShape(RoundedRectangle(cornerRadius: 11))
          .overlay(RoundedRectangle(cornerRadius: 11).stroke(AppTheme.border, lineWidth: 0.5))
        }

        if settings.proBetaAccepted {
          Button {
            showMissedSheet = true
          } label: {
            HStack(spacing: 5) {
              Image(systemName: "xmark.circle")
              Text("Missed dose")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.proAmber)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(AppTheme.proAmber.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(AppTheme.proAmber.opacity(0.25), lineWidth: 0.5))
          }
        } else {
          HStack(spacing: 5) {
            Image(systemName: "lock.fill")
              .font(.system(size: 12))
            Text("Missed dose")
              .font(.system(size: 14, weight: .medium))
          }
          .foregroundStyle(AppTheme.textMuted)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 11)
          .background(AppTheme.backgroundCard.opacity(0.5))
          .clipShape(RoundedRectangle(cornerRadius: 11))
          .overlay(RoundedRectangle(cornerRadius: 11).stroke(AppTheme.border.opacity(0.4), lineWidth: 0.5))
        }
      }
      .padding(.horizontal, 20)
    }
  }

  // MARK: - Last dose card

  private func lastDoseCard(_ dose: DoseRecord) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("LAST DOSE")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(AppTheme.textMuted)
          .kerning(0.5)
        Spacer()
        NavigationLink(destination: HistoryView()) {
          Text("View Full History")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.accentBlue)
        }
      }

      HStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(AppTheme.accentBlue.opacity(0.15))
            .frame(width: 44, height: 44)
          Image(systemName: "drop.fill")
            .foregroundStyle(AppTheme.accentBlue)
            .font(.system(size: 18))
        }

        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Text("\(dose.amount.formatted(.number.precision(.fractionLength(1))))\(dose.unit)")
              .font(.system(size: 18, weight: .bold))
              .foregroundStyle(AppTheme.textPrimary)
            if dose.missed { pill("Missed", color: AppTheme.statusAmber) }
            if dose.edited { pill("Edited", color: AppTheme.textMuted) }
          }
          Text(dose.time.formatted(date: .omitted, time: .shortened) + " · " + relativeDoseAge)
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.textSecondary)
        }
        Spacer()
      }

      if !isSafe, isActive {
        HStack(spacing: 6) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 11))
            .foregroundStyle(AppTheme.statusAmber)
          Text("Safe interval not yet reached — please wait")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.statusAmber)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppTheme.statusAmber.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
      } else if isSafe {
        HStack(spacing: 6) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 11))
            .foregroundStyle(AppTheme.statusGreen)
          Text("Safe interval reached")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.statusGreen)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppTheme.statusGreen.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }

      if !dose.notes.isEmpty {
        Text(dose.notes)
          .font(.system(size: 13))
          .foregroundStyle(AppTheme.textSecondary)
          .lineLimit(2)
      }
    }
    .padding(16)
    .background(AppTheme.backgroundCard)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border, lineWidth: 0.75))
    .padding(.horizontal, 20)
  }

  private var relativeDoseAge: String {
    guard let d = lastDose else { return "" }
    let secs = Int(now.timeIntervalSince(d.time))
    if secs < 60 { return "just now" }
    if secs < 3600 { return "\(secs / 60)m ago" }
    let h = secs / 3600; let m = (secs % 3600) / 60
    return m > 0 ? "\(h)h \(m)m ago" : "\(h)h ago"
  }

  private func pill(_ text: String, color: Color) -> some View {
    Text(text)
      .font(.system(size: 10, weight: .semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 7)
      .padding(.vertical, 2)
      .background(color.opacity(0.15))
      .clipShape(Capsule())
  }

  // MARK: - Logic

  private func startTicker() {
    ticker?.invalidate()
    ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in now = Date() }
  }

  private func attemptLog(amount: Double) {
    if isActive && !isSafe {
      pendingAmount = amount; showWarning = true
    } else {
      confirmLog(amount: amount)
    }
  }

  private func confirmLog(amount: Double) {
    let loc = LocationManager.shared
    DoseStore.logDose(
      amount: amount,
      unit: settings.unit,
      latitude: loc.currentLocation?.coordinate.latitude,
      longitude: loc.currentLocation?.coordinate.longitude,
      locationName: loc.locationName,
      deviceName: settings.deviceName,
      context: context,
      settings: settings
    )
  }
}
