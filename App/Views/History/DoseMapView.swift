import SwiftUI
import MapKit
import SwiftData

struct DoseMapView: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \DoseRecord.time, order: .reverse) private var allDoses: [DoseRecord]

  @State private var position: MapCameraPosition = .automatic
  @State private var selectedDose: DoseRecord? = nil
  @State private var highlightedDoseID: UUID? = nil

  private var activeDoses: [DoseRecord] { allDoses.filter { !$0.isDeletedForSync } }
  private var locatedDoses: [DoseRecord] { activeDoses.filter { $0.hasLocation } }

  // Determines pin color: red = logged before safe interval elapsed, blue = normal
  private func pinColor(for dose: DoseRecord) -> Color {
    guard let prev = activeDoses.first(where: { $0.time < dose.time }) else {
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
        HStack {
          Text("Dose Map")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(AppTheme.textPrimary)
          Spacer()
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(AppTheme.textSecondary)
              .frame(width: 32, height: 32)
              .background(AppTheme.backgroundCard)
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Close")
        }
        .padding(16)

        if locatedDoses.isEmpty {
          emptyState
        } else {
          mapContent
        }
      }
      .background(AppTheme.backgroundPrimary.ignoresSafeArea())
      .navigationTitle("Dose Map")
      .platformInlineNavigationTitle()
      .platformNavigationBarStyle()
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
            doseMarker(for: dose)
          }
        }
      }
      .mapStyle(.standard)
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      summaryBar
    }
  }

  private func doseMarker(for dose: DoseRecord) -> some View {
    let color = pinColor(for: dose)
    let isHighlighted = highlightedDoseID == dose.id

    return ZStack(alignment: .bottomLeading) {
      if isHighlighted {
        doseBubble(for: dose, color: color)
          .offset(x: 28, y: -18)
          .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomLeading)))
          .zIndex(1)
      }

      ZStack {
        Circle()
          .fill(color)
          .frame(width: isHighlighted ? 30 : 24, height: isHighlighted ? 30 : 24)
          .shadow(color: color.opacity(0.5), radius: 4)
        Image(systemName: "drop.fill")
          .font(.system(size: isHighlighted ? 13 : 11, weight: .bold))
          .foregroundStyle(.white)
      }
      .contentShape(Circle())
      .onTapGesture {
        withAnimation(.snappy) {
          highlightedDoseID = dose.id
        }
      }
      .onHover { hovering in
        withAnimation(.snappy) {
          highlightedDoseID = hovering ? dose.id : (highlightedDoseID == dose.id ? nil : highlightedDoseID)
        }
      }
      .accessibilityAddTraits(.isButton)
      .accessibilityLabel("\(dose.amount.formatted(.number.precision(.fractionLength(1))))\(dose.unit) at \(dose.time.formatted(date: .abbreviated, time: .shortened))")
    }
  }

  private func doseBubble(for dose: DoseRecord, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Circle()
          .fill(color)
          .frame(width: 8, height: 8)
        Text("\(dose.amount.formatted(.number.precision(.fractionLength(1))))\(dose.unit)")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(AppTheme.textPrimary)
        Spacer(minLength: 10)
        Button {
          selectedDose = dose
        } label: {
          Image(systemName: "info.circle.fill")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppTheme.accentBlue)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open dose location details")
      }

      Text(dose.time.formatted(date: .abbreviated, time: .shortened))
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(AppTheme.textSecondary)

      if let location = dose.displayLocation(approximate: settings.locationApproximate) {
        Label(location, systemImage: "location.fill")
          .font(.system(size: 12))
          .foregroundStyle(AppTheme.textMuted)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }

      if let earlyBy = dose.formattedEarlyBy {
        Label("Early by \(earlyBy)", systemImage: "exclamationmark.triangle.fill")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(AppTheme.statusAmber)
      }
    }
    .padding(12)
    .frame(width: 230, alignment: .leading)
    .background(AppTheme.backgroundCard.opacity(0.96))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 0.5))
    .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 8)
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
