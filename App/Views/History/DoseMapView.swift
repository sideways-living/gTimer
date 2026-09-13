import SwiftUI
import MapKit
import SwiftData

struct DoseMapView: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \DoseRecord.time, order: .reverse) private var allDoses: [DoseRecord]

  var showsDismissButton = true
  var bottomBarClearance: CGFloat = 0

  @State private var position: MapCameraPosition = .automatic
  @State private var selectedDose: DoseRecord? = nil
  @State private var hoveredDoseID: UUID? = nil
  @State private var pinnedDoseID: UUID? = nil
  @State private var markerFrames: [UUID: CGRect] = [:]

  private var activeDoses: [DoseRecord] { allDoses.filter { !$0.isDeletedForSync } }
  private var locatedDoses: [DoseRecord] { activeDoses.filter { $0.hasLocation } }
  private var activeCalloutDoseID: UUID? { pinnedDoseID ?? hoveredDoseID }

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
      .toolbar {
        if showsDismissButton {
          ToolbarItem(placement: .cancellationAction) {
            Button("Close") { dismiss() }
          }
        }
      }
    }
    .preferredColorScheme(.dark)
    .sheet(item: $selectedDose) { dose in
      DoseDetailMapSheet(dose: dose)
    }
  }

  // MARK: - Map with summary

  private var mapContent: some View {
    VStack(spacing: 0) {
      ZStack {
        Map(position: $position) {
          ForEach(locatedDoses) { dose in
            Annotation("", coordinate: dose.coordinate, anchor: .bottom) {
              doseMarker(for: dose)
            }
          }
        }
        .mapStyle(.standard)
        .onPreferenceChange(DoseMarkerFramePreferenceKey.self) { frames in
          if !markerFrames.roughlyMatches(frames) {
            markerFrames = frames
          }
        }

        doseCalloutOverlay
      }
      .coordinateSpace(name: DoseMapCoordinateSpace.name)
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      summaryBar
        .padding(.bottom, bottomBarClearance)
    }
  }

  private func doseMarker(for dose: DoseRecord) -> some View {
    let color = pinColor(for: dose)
    let isHighlighted = activeCalloutDoseID == dose.id

    return ZStack {
      ZStack {
        Circle()
          .fill(color)
          .frame(width: 24, height: 24)
          .shadow(color: color.opacity(0.5), radius: 4)
        Image(systemName: "drop.fill")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(.white)
      }
      .scaleEffect(isHighlighted ? 1.15 : 1)
      .contentShape(Circle())
      .onTapGesture {
        pinnedDoseID = pinnedDoseID == dose.id ? nil : dose.id
      }
      .onHover { hovering in
        if hovering {
          hoveredDoseID = dose.id
        } else if hoveredDoseID == dose.id {
          hoveredDoseID = nil
        }
      }
      .accessibilityAddTraits(.isButton)
      .accessibilityLabel("\(dose.amount.formatted(.number.precision(.fractionLength(1))))\(dose.unit) at \(dose.time.formatted(date: .abbreviated, time: .shortened))")
    }
    .frame(width: 34, height: 34)
    .background(
      GeometryReader { proxy in
        Color.clear.preference(
          key: DoseMarkerFramePreferenceKey.self,
          value: [dose.id: proxy.frame(in: .named(DoseMapCoordinateSpace.name))]
        )
      }
    )
  }

  @ViewBuilder
  private var doseCalloutOverlay: some View {
    GeometryReader { proxy in
      if let id = activeCalloutDoseID,
         let dose = locatedDoses.first(where: { $0.id == id }),
         let frame = markerFrames[id] {
        let marker = CGPoint(x: frame.midX, y: frame.midY)
        let placement = calloutPlacement(for: marker, in: proxy.size)
        doseBubbleContainer(
          for: dose,
          color: pinColor(for: dose),
          placement: placement
        )
        .position(calloutPosition(for: marker, placement: placement, in: proxy.size))
        .transition(.opacity)
        .onHover { hovering in
          if hovering {
            hoveredDoseID = id
          } else if hoveredDoseID == id {
            hoveredDoseID = nil
          }
        }
      }
    }
  }

  private func doseBubbleContainer(
    for dose: DoseRecord,
    color: Color,
    placement: DoseCalloutPlacement
  ) -> some View {
    let fill = AppTheme.backgroundCard.opacity(0.96)

    return Group {
      switch placement {
      case .right:
        HStack(spacing: 0) {
          DoseCalloutPointer(direction: .left)
            .fill(fill)
            .frame(width: 12, height: 22)
          doseBubble(for: dose, color: color)
        }
      case .left:
        HStack(spacing: 0) {
          doseBubble(for: dose, color: color)
          DoseCalloutPointer(direction: .right)
            .fill(fill)
            .frame(width: 12, height: 22)
        }
      case .below:
        VStack(spacing: 0) {
          DoseCalloutPointer(direction: .up)
            .fill(fill)
            .frame(width: 22, height: 12)
          doseBubble(for: dose, color: color)
        }
      case .above:
        VStack(spacing: 0) {
          doseBubble(for: dose, color: color)
          DoseCalloutPointer(direction: .down)
            .fill(fill)
            .frame(width: 22, height: 12)
        }
      }
    }
    .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 8)
  }

  private func calloutPlacement(for marker: CGPoint, in size: CGSize) -> DoseCalloutPlacement {
    let horizontalEdge: CGFloat = 292
    let verticalEdge: CGFloat = 182

    if marker.x < horizontalEdge { return .right }
    if marker.x > size.width - horizontalEdge { return .left }
    if marker.y < verticalEdge { return .below }
    return .above
  }

  private func calloutPosition(
    for marker: CGPoint,
    placement: DoseCalloutPlacement,
    in size: CGSize
  ) -> CGPoint {
    let bubbleWidth: CGFloat = 254
    let bubbleHeight: CGFloat = 156
    let gap: CGFloat = 14
    let inset: CGFloat = 14

    switch placement {
    case .right:
      return CGPoint(
        x: min(marker.x + gap + bubbleWidth / 2, size.width - bubbleWidth / 2 - inset),
        y: marker.y.clamped(to: (bubbleHeight / 2 + inset)...(size.height - bubbleHeight / 2 - inset))
      )
    case .left:
      return CGPoint(
        x: max(marker.x - gap - bubbleWidth / 2, bubbleWidth / 2 + inset),
        y: marker.y.clamped(to: (bubbleHeight / 2 + inset)...(size.height - bubbleHeight / 2 - inset))
      )
    case .below:
      return CGPoint(
        x: marker.x.clamped(to: (bubbleWidth / 2 + inset)...(size.width - bubbleWidth / 2 - inset)),
        y: min(marker.y + gap + bubbleHeight / 2, size.height - bubbleHeight / 2 - inset)
      )
    case .above:
      return CGPoint(
        x: marker.x.clamped(to: (bubbleWidth / 2 + inset)...(size.width - bubbleWidth / 2 - inset)),
        y: max(marker.y - gap - bubbleHeight / 2, bubbleHeight / 2 + inset)
      )
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

private enum DoseMapCoordinateSpace {
  static let name = "DoseMapCoordinateSpace"
}

private enum DoseCalloutPlacement {
  case above
  case below
  case left
  case right
}

private enum DoseCalloutPointerDirection {
  case up
  case down
  case left
  case right
}

private struct DoseCalloutPointer: Shape {
  let direction: DoseCalloutPointerDirection

  func path(in rect: CGRect) -> Path {
    var path = Path()
    switch direction {
    case .up:
      path.move(to: CGPoint(x: rect.midX, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    case .down:
      path.move(to: CGPoint(x: rect.minX, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
    case .left:
      path.move(to: CGPoint(x: rect.minX, y: rect.midY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    case .right:
      path.move(to: CGPoint(x: rect.minX, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    }
    path.closeSubpath()
    return path
  }
}

private struct DoseMarkerFramePreferenceKey: PreferenceKey {
  static var defaultValue: [UUID: CGRect] = [:]

  static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}

private extension Dictionary where Key == UUID, Value == CGRect {
  func roughlyMatches(_ other: [UUID: CGRect]) -> Bool {
    guard count == other.count else { return false }
    for (key, value) in self {
      guard let otherValue = other[key], value.roughlyMatches(otherValue) else {
        return false
      }
    }
    return true
  }
}

private extension CGRect {
  func roughlyMatches(_ other: CGRect) -> Bool {
    abs(midX - other.midX) < 0.5 &&
      abs(midY - other.midY) < 0.5 &&
      abs(width - other.width) < 0.5 &&
      abs(height - other.height) < 0.5
  }
}

private extension CGFloat {
  func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
    Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
  }
}
