import SwiftUI
import SwiftData

struct TimerView: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(AppNavigation.self) private var nav
  @Environment(\.modelContext) private var context
  @Query(sort: \DoseRecord.time, order: .reverse) private var doses: [DoseRecord]

  @State private var now = Date()
  @State private var showCustomSheet = false
  @State private var showMissedSheet = false
  @State private var showPaywall = false
  @State private var paywallFeature: ProFeature = .missedDose
  @State private var showWarning = false
  @State private var pendingAmount: Double = 0
  @State private var pendingNotes: String = ""
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
    if settings.countdownMode { return max(intervalSeconds - elapsed, 0) }
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
      ScrollView {
        VStack(spacing: 0) {
          gaugeSection
            .padding(.top, 20)
          statusBadge
          actionButtons
            .padding(.top, 8)
          if let d = lastDose, isActive {
            lastDoseCard(d)
              .padding(.top, 6)
          }
        }
        .padding(.horizontal, 0)
      }
      .tabBarScrollClearance()
      .background(AppTheme.backgroundPrimary.ignoresSafeArea())
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
      .platformNavigationBarStyle()
    }
    .background(AppTheme.backgroundPrimary.ignoresSafeArea())
    .onAppear {
      startTicker()
      // Warm up a location fix if Pro location recording is enabled
      if settings.proBetaAccepted && settings.attachLocationToDoses {
        LocationManager.shared.requestLocationInBackground()
      }
    }
    .onDisappear { ticker?.invalidate() }
    .sheet(isPresented: $showCustomSheet) {
      CustomDoseSheet { amount, notes in attemptLog(amount: amount, notes: notes) }
    }
    .sheet(isPresented: $showMissedSheet) {
      MissedDoseSheet()
    }
    .sheet(isPresented: $showPaywall) {
      PaywallSheet(feature: paywallFeature)
    }
    .alert("Log Early?", isPresented: $showWarning) {
      Button("Cancel", role: .cancel) {}
      Button("Log Anyway", role: .destructive) { confirmLog(amount: pendingAmount, notes: pendingNotes) }
    } message: {
      Text("The safe interval hasn't passed yet. Logging early can increase risk.")
    }
  }

  // MARK: - Gauge

  private var gaugeSection: some View {
    ArcGaugeView(
      progress: progress,
      countdownMode: settings.countdownMode,
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
    .padding(.top, 10)
    .padding(.bottom, 18)
  }

  // MARK: - Action buttons

  private var actionButtons: some View {
    VStack(spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        primaryDoseButton
        quickAmountsGrid
      }
      .padding(.horizontal, 20)

      // Bottom row: widths derived from the top row's column geometry.
      // Top splits equally (spacing 10), quick grid has two columns (spacing 8).
      // Left = primary width + half of one quick column; right gets the remainder.
      GeometryReader { geo in
        let W = max(geo.size.width, 80)         // guard against zero on first pass
        let leftW = max((5 * W - 66) / 8, 44)
        let rightW = max(W - leftW - 10, 44)
        HStack(spacing: 10) {
          customDoseButton.frame(width: leftW)
          missedDoseButton.frame(width: rightW)
        }
      }
      .frame(height: 48)
      .padding(.horizontal, 20)
    }
  }

  // Large primary button — stretches to match quick grid height
  private var primaryDoseButton: some View {
    Button { attemptLog(amount: settings.standardDose) } label: {
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 24)
          .fill(
            LinearGradient(
              colors: [AppTheme.accentBlue, AppTheme.accentBlueD],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
        HStack(alignment: .center, spacing: 0) {
          Image(systemName: "plus")
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(.white.opacity(0.95))
            .frame(width: 44)
          VStack(alignment: .leading, spacing: 1) {
            Text("I took")
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(.white.opacity(0.80))
            Text("\(settings.standardDose.formatted(.number.precision(.fractionLength(1))))\(settings.unit)")
              .font(.system(size: 22, weight: .bold))
              .foregroundStyle(.white)
              .minimumScaleFactor(0.7)
              .lineLimit(1)
          }
          Spacer(minLength: 8)
        }
        .padding(.horizontal, 14)
      }
      .frame(maxHeight: .infinity)
    }
    .accessibilityLabel("Log \(settings.standardDose.formatted(.number.precision(.fractionLength(1))))\(settings.unit)")
  }

  private var quickAmountsGrid: some View {
    let amounts = Array(settings.quickAmounts.prefix(4))
    return VStack(spacing: 8) {
      switch amounts.count {
      case 0:
        quickAmountSettingsButton
          .frame(height: 112)
      case 1:
        quickDoseButton(amounts[0])
          .frame(height: 112)
      case 2:
        quickDoseButton(amounts[0])
          .frame(height: 52)
        quickDoseButton(amounts[1])
          .frame(height: 52)
      case 3:
        quickDoseButton(amounts[0])
          .frame(height: 52)
        HStack(spacing: 8) {
          quickDoseButton(amounts[1])
          quickDoseButton(amounts[2])
        }
        .frame(height: 52)
      default:
        ForEach(0..<2, id: \.self) { row in
          HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { col in
              quickDoseButton(amounts[row * 2 + col])
            }
          }
          .frame(height: 52)
        }
      }
    }
  }

  private func quickDoseButton(_ amount: Double) -> some View {
    let isDefault = abs(amount - settings.standardDose) < 0.001
    return Button { attemptLog(amount: amount) } label: {
      Text("\(amount.formatted(.number.precision(.fractionLength(1))))\(settings.unit)")
        .font(.system(size: 15, weight: .bold))
        .foregroundStyle(isDefault ? .white : Color(white: 0.82))
        .minimumScaleFactor(0.75)
        .lineLimit(1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
          RoundedRectangle(cornerRadius: 20)
            .fill(isDefault
              ? AppTheme.accentBlue.opacity(0.25)
              : AppTheme.backgroundElevated)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 20)
            .strokeBorder(
              isDefault ? AppTheme.accentBlue : AppTheme.border,
              lineWidth: isDefault ? 1.5 : 0.5
            )
        )
    }
    .accessibilityLabel("Log \(amount.formatted(.number.precision(.fractionLength(1))))\(settings.unit)")
  }

  private var quickAmountSettingsButton: some View {
    Button {
      nav.selectedTab = 3
      nav.settingsScrollTarget = .quickAmounts
    } label: {
      VStack(spacing: 7) {
        Image(systemName: "slider.horizontal.3")
          .font(.system(size: 18, weight: .semibold))
        Text("Set quick doses")
          .font(.system(size: 13, weight: .semibold))
          .minimumScaleFactor(0.8)
          .lineLimit(1)
      }
      .foregroundStyle(AppTheme.accentBlue)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(AppTheme.accentBlue.opacity(0.10))
      .clipShape(RoundedRectangle(cornerRadius: 20))
      .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.accentBlue.opacity(0.25), lineWidth: 0.75))
    }
    .accessibilityLabel("Open quick dose settings")
  }

  private var customDoseButton: some View {
    Button { showCustomSheet = true } label: {
      HStack(spacing: 6) {
        Image(systemName: "pencil").font(.system(size: 13))
        Text("I took a different amount")
          .font(.system(size: 13, weight: .medium))
          .minimumScaleFactor(0.75)
          .lineLimit(1)
      }
      .foregroundStyle(AppTheme.textSecondary)
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .background(AppTheme.backgroundElevated)
      .clipShape(RoundedRectangle(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border, lineWidth: 0.5))
    }
    .accessibilityLabel("Log custom amount")
  }

  private var missedDoseButton: some View {
    ZStack(alignment: .topTrailing) {
      Button {
        if settings.proBetaAccepted {
          showMissedSheet = true
        } else {
          paywallFeature = .missedDose
          showPaywall = true
        }
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "xmark.circle").font(.system(size: 13))
          Text("Missed dose")
            .font(.system(size: 13, weight: .medium))
            .minimumScaleFactor(0.75)
            .lineLimit(1)
        }
        .foregroundStyle(settings.proBetaAccepted ? AppTheme.proAmber : AppTheme.textMuted)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(settings.proBetaAccepted
          ? AppTheme.proAmber.opacity(0.10)
          : AppTheme.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
          RoundedRectangle(cornerRadius: 14)
            .stroke(settings.proBetaAccepted
              ? AppTheme.proAmber.opacity(0.3)
              : AppTheme.border,
              lineWidth: 0.5)
        )
      }
      .accessibilityLabel("Log missed dose")

      if !settings.proBetaAccepted {
        Text("PRO")
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(.black)
          .padding(.horizontal, 5)
          .padding(.vertical, 2)
          .background(AppTheme.proAmber)
          .clipShape(Capsule())
          .offset(x: -6, y: -6)
      }
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
          Circle().fill(AppTheme.accentBlue.opacity(0.15)).frame(width: 44, height: 44)
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
          // Location line (Pro)
          if let locLabel = dose.displayLocation(approximate: settings.locationApproximate) {
            HStack(spacing: 4) {
              Image(systemName: "location.fill")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.accentBlue)
              Text(locLabel)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
            }
          }
        }
        Spacer()
      }

      if !isSafe {
        statusBanner(
          icon: "exclamationmark.triangle.fill",
          text: "Safe interval not yet reached — please wait",
          color: AppTheme.statusAmber
        )
      } else {
        statusBanner(
          icon: "checkmark.circle.fill",
          text: "Safe interval reached",
          color: AppTheme.statusGreen
        )
      }

      if !dose.notes.isEmpty {
        Text(dose.notes)
          .font(.system(size: 13))
          .foregroundStyle(AppTheme.textSecondary)
          .lineLimit(2)
      }

      // Throttled location nudge for free users
      if !settings.proBetaAccepted &&
         !PaywallThrottle.shared.wasDismissed(.doseLocations) {
        Button {
          paywallFeature = .doseLocations
          showPaywall = true
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "location.fill")
              .font(.system(size: 11))
              .foregroundStyle(AppTheme.accentBlue)
            Text("Add location context with Pro")
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(AppTheme.accentBlue)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.system(size: 10))
              .foregroundStyle(AppTheme.accentBlue.opacity(0.5))
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .background(AppTheme.accentBlue.opacity(0.07))
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.accentBlue.opacity(0.2), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(16)
    .background(AppTheme.backgroundCard)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border, lineWidth: 0.75))
    .padding(.horizontal, 20)
  }

  private func statusBanner(icon: String, text: String, color: Color) -> some View {
    HStack(spacing: 6) {
      Image(systemName: icon).font(.system(size: 11)).foregroundStyle(color)
      Text(text).font(.system(size: 12)).foregroundStyle(color)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(color.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private var relativeDoseAge: String {
    guard let d = lastDose else { return "" }
    let s = Int(now.timeIntervalSince(d.time))
    if s < 60 { return "just now" }
    if s < 3600 { return "\(s / 60)m ago" }
    let h = s / 3600; let m = (s % 3600) / 60
    return m > 0 ? "\(h)h \(m)m ago" : "\(h)h ago"
  }

  private func pill(_ text: String, color: Color) -> some View {
    Text(text)
      .font(.system(size: 10, weight: .semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 7).padding(.vertical, 2)
      .background(color.opacity(0.15))
      .clipShape(Capsule())
  }

  // MARK: - Logic

  private func startTicker() {
    ticker?.invalidate()
    ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in now = Date() }
  }

  private func attemptLog(amount: Double, notes: String = "") {
    if isActive && !isSafe {
      pendingAmount = amount
      pendingNotes = notes
      showWarning = true
    } else {
      confirmLog(amount: amount, notes: notes)
    }
  }

  private func confirmLog(amount: Double, notes: String = "") {
    let loc = LocationManager.shared
    let captureLocation = settings.proBetaAccepted && settings.attachLocationToDoses

    if captureLocation {
      Task { @MainActor in
        let captured = await loc.captureForDose()
        DoseStore.logDose(
          amount: amount,
          unit: settings.unit,
          notes: notes,
          capturedLocation: captured,
          locationName: loc.locationName,
          locationSource: "automatic",
          deviceName: settings.deviceName,
          context: context,
          settings: settings
        )
      }
    } else {
      DoseStore.logDose(
        amount: amount,
        unit: settings.unit,
        notes: notes,
        deviceName: settings.deviceName,
        context: context,
        settings: settings
      )
    }
  }
}
