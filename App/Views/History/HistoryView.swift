import SwiftUI
import SwiftData

struct HistoryView: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(AppNavigation.self) private var nav
  @Environment(\.modelContext) private var context
  @Query(sort: \DoseRecord.time, order: .reverse) private var allDoses: [DoseRecord]

  @State private var showDeleteAll = false
  @State private var editingDose: DoseRecord?
  @State private var showMapView = false
  @State private var showPaywall = false
  @State private var paywallFeature: ProFeature = .fullHistory
  @State private var showExportLocationWarning = false
  @State private var showExportShare = false

  private var visibleDoses: [DoseRecord] {
    if settings.proBetaAccepted { return allDoses }
    let cutoff = Date().addingTimeInterval(-24 * 3600)
    return allDoses.filter { $0.time >= cutoff }
  }

  private var locatedDoses: [DoseRecord] { allDoses.filter { $0.hasLocation } }
  private var locatedCount: Int { locatedDoses.count }

  private var mostCommonArea: String? {
    let names = locatedDoses.compactMap { $0.locationName?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) }
    guard !names.isEmpty else { return nil }
    let freq = Dictionary(names.map { ($0, 1) }, uniquingKeysWith: +)
    return freq.max(by: { $0.value < $1.value })?.key
  }

  private var earlyRedoseCount: Int {
    let intervalSecs = Double(settings.safeIntervalMinutes) * 60
    var count = 0
    for (i, dose) in allDoses.enumerated() {
      guard dose.hasLocation, i + 1 < allDoses.count else { continue }
      let prev = allDoses[i + 1]
      if dose.time.timeIntervalSince(prev.time) < intervalSecs { count += 1 }
    }
    return count
  }

  var body: some View {
    NavigationStack {
      Group {
        if allDoses.isEmpty {
          emptyState
        } else {
          doseList
        }
      }
      .navigationTitle("History")
      .toolbarBackground(AppTheme.backgroundSecondary, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          if settings.proBetaAccepted && !allDoses.isEmpty {
            exportButton
          }
          if !allDoses.isEmpty {
            Button { showDeleteAll = true } label: {
              Image(systemName: "trash").foregroundStyle(AppTheme.statusRed)
            }
            .accessibilityLabel("Delete All")
          }
        }
      }
      .confirmationDialog(
        "Delete all dose records?",
        isPresented: $showDeleteAll,
        titleVisibility: .visible
      ) {
        Button("Delete All", role: .destructive) { DoseStore.deleteAll(context: context) }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("This cannot be undone.")
      }
      .alert("Export includes location data", isPresented: $showExportLocationWarning) {
        Button("Export") { showExportShare = true }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("Your export will include GPS coordinates and location names for \(locatedCount) dose\(locatedCount == 1 ? "" : "s"). Make sure you trust the recipient.")
      }
      .sheet(isPresented: $showExportShare) {
        ShareSheet(items: [csvContent()])
      }
      .sheet(item: $editingDose) { EditDoseSheet(dose: $0) }
      .sheet(isPresented: $showMapView) { DoseMapView() }
      .sheet(isPresented: $showPaywall) { PaywallSheet(feature: paywallFeature) }
    }
    .background(AppTheme.backgroundPrimary.ignoresSafeArea())
  }

  // MARK: - List

  private var doseList: some View {
    ScrollView {
      LazyVStack(spacing: 6) {
        if !settings.proBetaAccepted {
          proNudge
        }

        if settings.proBetaAccepted && locatedCount > 0 {
          mapButton
          locationInsightsCard
        }

        if visibleDoses.isEmpty {
          Text("Older records are hidden in free mode.")
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.textMuted)
            .padding(.top, 32)
        } else {
          ForEach(visibleDoses) { dose in
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
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
    }
    .tabBarScrollClearance()
    .background(AppTheme.backgroundPrimary.ignoresSafeArea())
  }

  // MARK: - Map button

  private var mapButton: some View {
    Button {
      if settings.proBetaAccepted {
        showMapView = true
      } else {
        paywallFeature = .doseMap
        showPaywall = true
      }
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "map.fill")
          .font(.system(size: 14))
          .foregroundStyle(AppTheme.accentBlue)
        Text("View dose map · \(locatedCount) location\(locatedCount == 1 ? "" : "s")")
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(AppTheme.accentBlue)
        Spacer()
        Image(systemName: "chevron.right")
          .font(.system(size: 11))
          .foregroundStyle(AppTheme.accentBlue.opacity(0.5))
      }
      .padding(12)
      .background(AppTheme.accentBlue.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.accentBlue.opacity(0.2), lineWidth: 0.5))
    }
    .buttonStyle(.plain)
  }

  // MARK: - Location insights card

  private var locationInsightsCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("LOCATION INSIGHTS")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(AppTheme.textMuted)
          .kerning(0.5)
        Spacer()
      }

      HStack(spacing: 0) {
        insightCell(value: "\(locatedCount)", label: "Tracked doses")
        Divider().frame(height: 28).background(AppTheme.border)
        if let area = mostCommonArea {
          insightCell(value: area, label: "Most common area")
          Divider().frame(height: 28).background(AppTheme.border)
        }
        insightCell(
          value: earlyRedoseCount == 0 ? "None" : "\(earlyRedoseCount)",
          label: "Early redoses",
          valueColor: earlyRedoseCount > 0 ? AppTheme.statusAmber : AppTheme.statusGreen
        )
      }
    }
    .padding(14)
    .background(AppTheme.backgroundCard)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 0.5))
  }

  private func insightCell(value: String, label: String, valueColor: Color = AppTheme.textPrimary) -> some View {
    VStack(spacing: 2) {
      Text(value)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(valueColor)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(label)
        .font(.system(size: 11))
        .foregroundStyle(AppTheme.textMuted)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Empty state

  private var emptyState: some View {
    ScrollView {
      VStack(spacing: 14) {
        Spacer(minLength: 60)
        Image(systemName: "clock.arrow.circlepath")
          .font(.system(size: 48))
          .foregroundStyle(AppTheme.textMuted)
        Text("No doses recorded yet")
          .font(.system(size: 19, weight: .semibold))
          .foregroundStyle(AppTheme.textSecondary)
        Text("Tap \"I took…\" on the Timer tab to log your first dose.")
          .font(.system(size: 14))
          .foregroundStyle(AppTheme.textMuted)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 48)
      }
      .frame(maxWidth: .infinity)
    }
    .tabBarScrollClearance()
    .background(AppTheme.backgroundPrimary.ignoresSafeArea())
  }

  // MARK: - Pro nudge

  private var proNudge: some View {
    Button {
      paywallFeature = .fullHistory
      showPaywall = true
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "lock.fill")
          .foregroundStyle(AppTheme.proAmber)
          .font(.system(size: 13))
        Text("Showing last 24 hours. Tap to activate Pro for full history, editing & export.")
          .font(.system(size: 13))
          .foregroundStyle(AppTheme.proAmber)
          .fixedSize(horizontal: false, vertical: true)
          .multilineTextAlignment(.leading)
        Spacer()
        Image(systemName: "chevron.right")
          .foregroundStyle(AppTheme.proAmber.opacity(0.6))
          .font(.system(size: 12))
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AppTheme.proAmber.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.proAmber.opacity(0.2), lineWidth: 0.5))
    }
    .buttonStyle(.plain)
  }

  // MARK: - CSV Export

  private var exportButton: some View {
    Button {
      if locatedCount > 0 {
        showExportLocationWarning = true
      } else {
        showExportShare = true
      }
    } label: {
      Image(systemName: "square.and.arrow.up").foregroundStyle(AppTheme.accentBlue)
    }
    .accessibilityLabel("Export CSV")
  }

  private func csvContent() -> String {
    var lines = ["Date,Time,Amount,Unit,Missed,Edited,Notes,Device,Latitude,Longitude,LocationName,AccuracyMeters,LocationSource"]
    let fmt = DateFormatter(); fmt.dateStyle = .short
    let tfmt = DateFormatter(); tfmt.timeStyle = .short
    for d in allDoses {
      let row = [
        fmt.string(from: d.time),
        tfmt.string(from: d.time),
        String(d.amount),
        d.unit,
        d.missed ? "Yes" : "No",
        d.edited ? "Yes" : "No",
        "\"\(d.notes.replacingOccurrences(of: "\"", with: "\"\""))\"",
        d.deviceName,
        d.latitude.map { String(format: "%.6f", $0) } ?? "",
        d.longitude.map { String(format: "%.6f", $0) } ?? "",
        "\"\((d.locationName ?? "").replacingOccurrences(of: "\"", with: "\"\""))\"",
        d.locationAccuracyMeters.map { String(Int($0)) } ?? "",
        d.resolvedLocationSource
      ].joined(separator: ",")
      lines.append(row)
    }
    return lines.joined(separator: "\n")
  }
}
