import SwiftUI
import SwiftData
import CoreLocation

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
  @State private var pendingEarlyBySeconds: TimeInterval?
  @State private var ticker: Timer?
  @State private var editingDose: DoseRecord?

  private var lastDose: DoseRecord? { doses.first }
  private var visibleDoses: [DoseRecord] {
    if settings.proBetaAccepted { return doses }
    let cutoff = Date().addingTimeInterval(-24 * 3600)
    return doses.filter { $0.time >= cutoff }
  }

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
    guard isActive else { return "No Active gTimer" }
    if isSafe { return "Safe to redose" }
    let r = Int(intervalSeconds - elapsed)
    let h = r / 3600; let m = (r % 3600) / 60
    return h > 0 ? "Wait \(h)h \(m)min" : "Wait \(m)min"
  }

  #if os(macOS)
  private let macBottomBarReservedHeight: CGFloat = 116
  #endif
  private let quickDoseButtonHeight: CGFloat = 52
  private let quickDoseGridSpacing: CGFloat = 8
  private let doseButtonGroupSpacing: CGFloat = 10
  private var quickDoseGridHeight: CGFloat {
    quickDoseButtonHeight * 2 + quickDoseGridSpacing
  }

  var body: some View {
    NavigationStack {
      #if os(macOS)
      macTimerLayout
      #else
      phoneTimerLayout
      #endif
    }
    .background(AppTheme.backgroundPrimary.ignoresSafeArea())
    .onAppear {
      startTicker()
      DoseStore.backfillMissingEarlyDoseTiming(context: context, settings: settings)
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
    .sheet(item: $editingDose) { EditDoseSheet(dose: $0) }
    .alert("Log Early?", isPresented: $showWarning) {
      Button("Cancel", role: .cancel) { pendingEarlyBySeconds = nil }
      Button("Log Anyway", role: .destructive) {
        confirmLog(amount: pendingAmount, notes: pendingNotes, earlyBySeconds: pendingEarlyBySeconds)
      }
    } message: {
      Text("The safe interval hasn't passed yet. This would be logged as \(formattedEarlyBy(pendingEarlyBySeconds)) early.")
    }
  }

  private var phoneTimerLayout: some View {
    ScrollView {
      timerStack(includeLastDose: true)
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
          Text("gTimer")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(AppTheme.textPrimary)
        }
      }
    }
    .platformNavigationBarStyle()
  }

  #if os(macOS)
  private var macTimerLayout: some View {
    GeometryReader { geo in
      let showsHistory = geo.size.width >= 860
      let timerPanelHeight = max(geo.size.height - macBottomBarReservedHeight, 520)
      HStack(alignment: .top, spacing: 0) {
        macTimerPanel(includeLastDose: !showsHistory)
          .frame(maxWidth: 460)
          .frame(maxWidth: .infinity)
          .frame(height: timerPanelHeight)
          .padding(.horizontal, showsHistory ? 28 : 20)
        .background(AppTheme.backgroundPrimary)

        if showsHistory {
          Divider().background(AppTheme.border)
          macHistoryPanel
            .frame(minWidth: 340, idealWidth: 390, maxWidth: 460)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .background(AppTheme.backgroundPrimary.ignoresSafeArea())
    .navigationTitle("gTimer")
  }
  #endif

  #if os(macOS)
  private func macTimerPanel(includeLastDose: Bool) -> some View {
    VStack(spacing: 0) {
      Spacer(minLength: 8)
      Spacer(minLength: 8)
      Spacer(minLength: 8)
      gaugeSection
      Spacer(minLength: 8)
      Spacer(minLength: 8)
      statusBadge
      Spacer(minLength: 8)
      Spacer(minLength: 8)
      actionButtons
      if includeLastDose, let d = lastDose, isActive {
        Spacer(minLength: 8)
        lastDoseCard(d)
      }
      Spacer(minLength: 8)
    }
  }
  #endif

  private func timerStack(includeLastDose: Bool) -> some View {
    VStack(spacing: 0) {
      gaugeSection
        .padding(.top, 20)
      statusBadge
      actionButtons
        .padding(.top, 8)
      if includeLastDose, let d = lastDose, isActive {
        lastDoseCard(d)
          .padding(.top, 6)
      }
    }
    .padding(.horizontal, 0)
  }

  #if os(macOS)
  private var macHistoryPanel: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("Recent History")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)
          Text(settings.proBetaAccepted ? "All dose records" : "Last 24 hours")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textMuted)
        }
        Spacer()
        Button {
          nav.selectedTab = 1
        } label: {
          Image(systemName: "arrow.right")
            .font(.system(size: 14, weight: .semibold))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(AppTheme.accentBlue)
        .accessibilityLabel("Open full history")
      }

      if visibleDoses.isEmpty {
        VStack(spacing: 10) {
          Image(systemName: "clock.arrow.circlepath")
            .font(.system(size: 30))
            .foregroundStyle(AppTheme.textMuted)
          Text(doses.isEmpty ? "No doses recorded yet" : "Older records are hidden in free mode.")
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.textMuted)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 8) {
            ForEach(Array(visibleDoses.prefix(8))) { dose in
              DoseRowView(
                dose: dose,
                isPro: settings.proBetaAccepted,
                locationApproximate: settings.locationApproximate
              ) {
                if settings.proBetaAccepted { editingDose = dose }
              } onDelete: {
                DoseStore.delete(dose, context: context)
              }
            }
          }
          .padding(.bottom, 96)
        }
      }
    }
    .padding(20)
    .background(AppTheme.backgroundSecondary)
  }
  #endif

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
    VStack(spacing: doseButtonGroupSpacing) {
      HStack(alignment: .top, spacing: 10) {
        primaryDoseButton
          .frame(height: quickDoseGridHeight)
        quickAmountsGrid
          .frame(height: quickDoseGridHeight)
      }
      .frame(height: quickDoseGridHeight)
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

  // Large primary button is constrained by the shared top control-group height.
  private var primaryDoseButton: some View {
    Button { attemptLog(amount: settings.standardDose) } label: {
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 24)
          .fill(
            LinearGradient(
              colors: [AppTheme.primaryButton, AppTheme.primaryButtonD],
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
    .buttonStyle(.plain)
  }

  private var quickAmountsGrid: some View {
    let amounts = Array(settings.quickAmounts.prefix(4))
    return VStack(spacing: quickDoseGridSpacing) {
      switch amounts.count {
      case 0:
        quickAmountSettingsButton
          .frame(height: quickDoseGridHeight)
      case 1:
        quickDoseButton(amounts[0])
          .frame(height: quickDoseGridHeight)
      case 2:
        quickDoseButton(amounts[0])
          .frame(height: quickDoseButtonHeight)
        quickDoseButton(amounts[1])
          .frame(height: quickDoseButtonHeight)
      case 3:
        quickDoseButton(amounts[0])
          .frame(height: quickDoseButtonHeight)
        HStack(spacing: quickDoseGridSpacing) {
          quickDoseButton(amounts[1])
          quickDoseButton(amounts[2])
        }
        .frame(height: quickDoseButtonHeight)
      default:
        ForEach(0..<2, id: \.self) { row in
          HStack(spacing: quickDoseGridSpacing) {
            ForEach(0..<2, id: \.self) { col in
              quickDoseButton(amounts[row * 2 + col])
            }
          }
          .frame(height: quickDoseButtonHeight)
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
          RoundedRectangle(cornerRadius: 12)
            .fill(isDefault
              ? AppTheme.primaryButton.opacity(0.25)
              : AppTheme.quickButton)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
              isDefault ? AppTheme.primaryButton : AppTheme.border,
              lineWidth: isDefault ? 1.5 : 0.5
            )
        )
    }
    .accessibilityLabel("Log \(amount.formatted(.number.precision(.fractionLength(1))))\(settings.unit)")
    .buttonStyle(.plain)
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
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.accentBlue.opacity(0.25), lineWidth: 0.75))
    }
    .accessibilityLabel("Open quick dose settings")
    .buttonStyle(.plain)
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
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 0.5))
    }
    .accessibilityLabel("Log custom amount")
    .buttonStyle(.plain)
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
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(settings.proBetaAccepted
              ? AppTheme.proAmber.opacity(0.3)
              : AppTheme.border,
              lineWidth: 0.5)
        )
      }
      .accessibilityLabel("Log missed dose")
      .buttonStyle(.plain)

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
            if dose.wasTakenEarly { pill("Early", color: AppTheme.statusRed) }
            if dose.missed { pill("Missed", color: AppTheme.statusAmber) }
            if dose.edited { pill("Edited", color: AppTheme.textMuted) }
          }
          Text(dose.time.formatted(date: .omitted, time: .shortened) + " · " + relativeDoseAge)
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.textSecondary)
          if let earlyBy = dose.formattedEarlyBy {
            HStack(spacing: 4) {
              Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
              Text("Taken \(earlyBy) early")
                .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(AppTheme.statusRed)
          }
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
      pendingEarlyBySeconds = max(intervalSeconds - elapsed, 0)
      showWarning = true
    } else {
      confirmLog(amount: amount, notes: notes)
    }
  }

  private func confirmLog(amount: Double, notes: String = "", earlyBySeconds: TimeInterval? = nil) {
    let loc = LocationManager.shared
    let captureLocation = settings.proBetaAccepted && settings.attachLocationToDoses
    let earlyBySeconds = earlyBySeconds.flatMap { $0 > 0 ? $0 : nil }

    if captureLocation {
      Task { @MainActor in
        let captured = await loc.captureForDose()
        #if os(macOS)
        let fallback = captured == nil ? await homeFallbackLocation() : nil
        let doseLocation = captured ?? fallback?.location
        let doseLocationName = captured == nil ? fallback?.name : loc.locationName
        let doseLocationSource = captured == nil && fallback != nil ? "home-fallback" : "automatic"
        #else
        let doseLocation = captured
        let doseLocationName = loc.locationName
        let doseLocationSource = "automatic"
        #endif
        DoseStore.logDose(
          amount: amount,
          unit: settings.unit,
          notes: notes,
          earlyBySeconds: earlyBySeconds,
          capturedLocation: doseLocation,
          locationName: doseLocationName,
          locationSource: doseLocationSource,
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
        earlyBySeconds: earlyBySeconds,
        deviceName: settings.deviceName,
        context: context,
        settings: settings
      )
    }
    pendingEarlyBySeconds = nil
  }

  private func formattedEarlyBy(_ seconds: TimeInterval?) -> String {
    guard let seconds, seconds > 0 else { return "0m" }
    let totalMinutes = max(Int((seconds / 60).rounded()), 1)
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
    if hours > 0 { return "\(hours)h" }
    return "\(minutes)m"
  }

  #if os(macOS)
  private func homeFallbackLocation() async -> (location: CLLocation, name: String)? {
    let context = ManualLocationSearchContext(
      homeCity: settings.homeCity,
      homeCountryCode: settings.homeCountryCode,
      homeAddress: settings.homeAddress,
      homeCoordinate: homeCoordinate,
      currentCoordinate: LocationManager.shared.currentLocation?.coordinate
    )
    guard let fallback = await ManualLocationStore.shared.homeFallbackLocation(context: context) else { return nil }
    ManualLocationStore.shared.save(
      name: fallback.name,
      latitude: fallback.latitude,
      longitude: fallback.longitude
    )
    return (
      CLLocation(latitude: fallback.latitude, longitude: fallback.longitude),
      fallback.name
    )
  }

  private var homeCoordinate: CLLocationCoordinate2D? {
    guard let latitude = settings.homeLatitude,
          let longitude = settings.homeLongitude,
          (-90...90).contains(latitude),
          (-180...180).contains(longitude)
    else { return nil }
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
  #endif
}
