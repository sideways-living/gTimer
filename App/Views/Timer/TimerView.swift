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
  @State private var timer: Timer?

  private var lastDose: DoseRecord? { doses.first }

  private var isActive: Bool {
    guard let d = lastDose else { return false }
    return now.timeIntervalSince(d.time) < 6 * 3600
  }

  private var elapsed: TimeInterval {
    guard let d = lastDose else { return 0 }
    return now.timeIntervalSince(d.time)
  }

  private var intervalSeconds: TimeInterval {
    Double(settings.safeIntervalMinutes) * 60
  }

  private var isSafe: Bool { elapsed >= intervalSeconds }

  private var progress: Double {
    guard isActive else { return 0 }
    return min(elapsed / intervalSeconds, 1.0)
  }

  private var statusColor: Color {
    guard isActive else { return AppTheme.textMuted }
    if progress < 0.70 { return AppTheme.statusRed }
    if progress < 1.0  { return AppTheme.statusAmber }
    return AppTheme.statusGreen
  }

  private var displayTime: TimeInterval {
    guard isActive else { return 0 }
    if settings.countdownMode && !isSafe {
      return max(intervalSeconds - elapsed, 0)
    }
    return elapsed
  }

  private var timeString: String {
    guard isActive else { return "00:00:00" }
    let t = Int(displayTime)
    let h = t / 3600
    let m = (t % 3600) / 60
    let s = t % 60
    return String(format: "%02d:%02d:%02d", h, m, s)
  }

  private var statusLabel: String {
    guard isActive else { return "No Active G Timer" }
    if isSafe { return "Safe to redose" }
    let remaining = Int(intervalSeconds - elapsed)
    let h = remaining / 3600
    let m = (remaining % 3600) / 60
    if h > 0 { return "Wait \(h)h \(m)min" }
    return "Wait \(m)min"
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 0) {
          headerView
          gaugeSection
          statusBadge
          actionButtons
          if let d = lastDose, isActive {
            lastDoseCard(d)
          }
          Spacer(minLength: 20)
        }
      }
      .background(AppTheme.backgroundPrimary)
      .navigationBarHidden(true)
    }
    .onAppear { startTimer() }
    .onDisappear { timer?.invalidate() }
    .sheet(isPresented: $showCustomSheet) {
      CustomDoseSheet { amount in
        attemptLog(amount: amount)
      }
    }
    .sheet(isPresented: $showMissedSheet) {
      MissedDoseSheet()
    }
    .alert("Log Early?", isPresented: $showWarning) {
      Button("Cancel", role: .cancel) {}
      Button("Log Anyway", role: .destructive) {
        confirmLog(amount: pendingAmount)
      }
    } message: {
      Text("The safe interval hasn't passed yet. Logging early can increase risk.")
    }
  }

  // MARK: - Subviews

  private var headerView: some View {
    HStack(spacing: 10) {
      Image(systemName: "drop.fill")
        .font(.system(size: 22, weight: .bold))
        .foregroundStyle(AppTheme.accentBlue)
      Text("G Timer")
        .font(.system(size: 26, weight: .bold))
        .foregroundStyle(AppTheme.textPrimary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 18)
    .background(AppTheme.backgroundSecondary)
    .overlay(alignment: .bottom) {
      Divider().background(AppTheme.border)
    }
  }

  private var gaugeSection: some View {
    ArcGaugeView(
      progress: progress,
      statusColor: statusColor,
      timeString: timeString,
      statusLabel: statusLabel,
      isActive: isActive
    )
    .padding(.top, 28)
    .padding(.bottom, 8)
  }

  private var statusBadge: some View {
    Group {
      if isActive {
        HStack(spacing: 6) {
          Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
          Text(isSafe ? "Safe to redose" : "Not yet safe")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(statusColor.opacity(0.12))
        .clipShape(Capsule())
        .padding(.bottom, 20)
      }
    }
  }

  private var actionButtons: some View {
    VStack(spacing: 14) {
      // Primary log button
      Button {
        attemptLog(amount: settings.standardDose)
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "plus.circle.fill")
          Text("I took \(settings.standardDose.formatted(.number.precision(.fractionLength(1))))\(settings.unit)")
            .fontWeight(.semibold)
        }
        .font(.system(size: 18))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.accentBlue)
        .clipShape(RoundedRectangle(cornerRadius: 14))
      }
      .padding(.horizontal, 20)

      // Quick amounts
      HStack(spacing: 10) {
        ForEach(settings.quickAmounts, id: \.self) { amt in
          Button {
            attemptLog(amount: amt)
          } label: {
            Text("\(amt.formatted(.number.precision(.fractionLength(1))))\(settings.unit)")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(AppTheme.accentBlue)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
              .background(AppTheme.accentBlue.opacity(0.12))
              .clipShape(RoundedRectangle(cornerRadius: 10))
          }
        }
      }
      .padding(.horizontal, 20)

      // Secondary actions
      HStack(spacing: 12) {
        Button {
          showCustomSheet = true
        } label: {
          Label("Custom amount", systemImage: "pencil")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(AppTheme.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }

        if settings.proBetaAccepted {
          Button {
            showMissedSheet = true
          } label: {
            Label("Missed dose", systemImage: "xmark.circle")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(AppTheme.proAmber)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
              .background(AppTheme.proAmber.opacity(0.1))
              .clipShape(RoundedRectangle(cornerRadius: 10))
          }
        } else {
          Button {} label: {
            HStack(spacing: 4) {
              Image(systemName: "lock.fill")
              Text("Missed dose")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(AppTheme.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
          }
          .disabled(true)
        }
      }
      .padding(.horizontal, 20)
    }
    .padding(.bottom, 20)
  }

  private func lastDoseCard(_ dose: DoseRecord) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Last Dose")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(AppTheme.textMuted)
          .textCase(.uppercase)
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
        }

        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Text("\(dose.amount.formatted(.number.precision(.fractionLength(1))))\(dose.unit)")
              .font(.system(size: 17, weight: .bold))
              .foregroundStyle(AppTheme.textPrimary)
            if dose.missed {
              pill("Missed", color: AppTheme.statusAmber)
            }
            if dose.edited {
              pill("Edited", color: AppTheme.textMuted)
            }
          }
          Text(dose.time.formatted(date: .omitted, time: .shortened) + " · " + dose.time.formatted(.relative(presentation: .named)))
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.textSecondary)
        }

        Spacer()
      }

      if !isSafe {
        HStack(spacing: 6) {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(AppTheme.statusAmber)
            .font(.system(size: 12))
          Text("Safe interval not yet reached — please wait")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.statusAmber)
        }
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
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border, lineWidth: 1))
    .padding(.horizontal, 20)
    .padding(.bottom, 10)
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

  private func startTimer() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
      now = Date()
    }
  }

  private func attemptLog(amount: Double) {
    if isActive && !isSafe {
      pendingAmount = amount
      showWarning = true
    } else {
      confirmLog(amount: amount)
    }
  }

  private func confirmLog(amount: Double) {
    let loc = LocationManager.shared
    DoseStore.logDose(
      amount: amount,
      unit: settings.unit,
      notes: "",
      latitude: loc.currentLocation?.coordinate.latitude,
      longitude: loc.currentLocation?.coordinate.longitude,
      locationName: loc.locationName,
      deviceName: settings.deviceName,
      context: context,
      settings: settings
    )
  }
}
