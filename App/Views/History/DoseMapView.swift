import SwiftUI
import MapKit
import SwiftData

struct DoseMapView: View {
  @Environment(SettingsManager.self) private var settings
  @Query(sort: \DoseRecord.time, order: .reverse) private var allDoses: [DoseRecord]

  @State private var position: MapCameraPosition = .automatic
  @State private var selectedDose: DoseRecord? = nil

  private var locatedDoses: [DoseRecord] { allDoses.filter { $0.hasLocation } }

  // Determines pin color: red = logged before safe interval elapsed, blue = normal
  private func pinColor(for dose: DoseRecord) -> Color {
    guard let prev = allDoses.first(where: { $0.time < dose.time }) else {
      return AppTheme.accentBlue
    }
    let elapsed = dose.time.timeIntervalSince(prev.time)
    let intervalSecs = Double(settings.safeIntervalMinutes) * 60
    return elapsed < intervalSecs ? AppTheme.statusRed : AppTheme.accentBlue
  }

  // Most common city/locality among located doses
  private var mostCommonArea: String? {
    let names = locatedDoses.compactMap { $0.locationName?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) }
    guard !names.isEmpty else { return nil }
    let freq = Dictionary(names.map { ($0, 1) }, uniquingKeysWith: +)
    return freq.max(by: { $0.value < $1.value })?.key
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        if locatedDoses.isEmpty {
          emptyState
        } else {
          mapContent
        }
      }
      .background(AppTheme.backgroundPrimary.ignoresSafeArea())
      .navigationTitle("Dose Map")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(AppTheme.backgroundSecondary, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
    }
    .preferredColorScheme(.dark)
    .sheet(item: $selectedDose) { dose in
      DoseDetailMapSheet(dose: dose)
    }
  }

  // MARK: - Map with summary

  private var mapContent: some View {
    VStack(spacing: 0) {
      Map(position: $position) {
        ForEach(locatedDoses) { dose in
          Annotation("", coordinate: dose.coordinate, anchor: .bottom) {
            Button { selectedDose = dose } label: {
              ZStack {
                Circle()
                  .fill(pinColor(for: dose))
                  .frame(width: 24, height: 24)
                  .shadow(color: pinColor(for: dose).opacity(0.5), radius: 4)
                Image(systemName: "drop.fill")
                  .font(.system(size: 11, weight: .bold))
                  .foregroundStyle(.white)
              }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(dose.amount.formatted(.number.precision(.fractionLength(1))))\(dose.unit) at \(dose.time.formatted(date: .abbreviated, time: .shortened))")
          }
        }
      }
      .mapStyle(.standard)
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      summaryBar
    }
  }

  // MARK: - Summary bar

  private var summaryBar: some View {
    HStack(spacing: 0) {
      summaryCell(value: "\(locatedDoses.count)", label: "Locations")

      Divider().frame(height: 32).background(AppTheme.border)

      if let area = mostCommonArea {
        summaryCell(value: area, label: "Most common area")
        Divider().frame(height: 32).background(AppTheme.border)
      }

      if let last = locatedDoses.first {
        summaryCell(
          value: last.locationName?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "—",
          label: "Last logged"
        )
      }
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 16)
    .background(AppTheme.backgroundSecondary)

  }

  private func summaryCell(value: String, label: String) -> some View {
    VStack(spacing: 2) {
      Text(value)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(AppTheme.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(label)
        .font(.system(size: 11))
        .foregroundStyle(AppTheme.textMuted)
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Empty state

  private var emptyState: some View {
    VStack(spacing: 14) {
      Spacer()
      Image(systemName: "map")
        .font(.system(size: 48))
        .foregroundStyle(AppTheme.textMuted)
      Text("No Dose Locations Yet")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(AppTheme.textSecondary)
      Text("Enable \"Attach location to new doses\" in Settings to start building your dose map.")
        .font(.system(size: 14))
        .foregroundStyle(AppTheme.textMuted)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 48)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
