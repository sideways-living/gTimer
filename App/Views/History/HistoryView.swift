import SwiftUI
import SwiftData
import CoreText
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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
  @State private var showHistoryExport = false
  @State private var exportOutcome: HistoryExportOutcome = .export
  @State private var handledExportRequestID = 0

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
      if dose.wasTakenEarly {
        count += 1
        continue
      }
      guard i + 1 < allDoses.count else { continue }
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
      .platformNavigationBarStyle()
      .toolbar {
        ToolbarItemGroup(placement: .primaryAction) {
          if !allDoses.isEmpty {
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
      .sheet(isPresented: $showHistoryExport) {
        HistoryExportSheet(
          doses: allDoses,
          locationApproximate: settings.locationApproximate,
          initialOutcome: exportOutcome
        )
      }
      .sheet(item: $editingDose) { EditDoseSheet(dose: $0) }
      .platformDoseMapPresentation(isPresented: $showMapView)
      .sheet(isPresented: $showPaywall) { PaywallSheet(feature: paywallFeature) }
    }
    .background(AppTheme.backgroundPrimary.ignoresSafeArea())
    .onAppear {
      DoseStore.backfillMissingEarlyDoseTiming(context: context, settings: settings)
      handlePendingExportRequest()
    }
    .onChange(of: nav.historyExportRequestID) { _, _ in
      handlePendingExportRequest()
    }
  }

  // MARK: - List

  private var doseList: some View {
    ScrollView {
      LazyVStack(spacing: 6) {
        if !settings.proBetaAccepted {
          proNudge
        }

        // Map button: visible to all users; Pro+locations → full map,
        // Pro+no-locations → empty map, free → paywall.
        mapButton
        if settings.proBetaAccepted && locatedCount > 0 {
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
    let isPro = settings.proBetaAccepted
    let active = isPro  // blue style when Pro (whether or not locations exist yet)
    return Button {
      if isPro {
        showMapView = true
      } else {
        paywallFeature = .doseMap
        showPaywall = true
      }
    } label: {
      HStack(spacing: 8) {
        Image(systemName: isPro ? "map.fill" : "lock.fill")
          .font(.system(size: 13))
          .foregroundStyle(active ? AppTheme.accentBlue : AppTheme.textMuted)
        if isPro && locatedCount > 0 {
          Text("View dose map · \(locatedCount) location\(locatedCount == 1 ? "" : "s")")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.accentBlue)
        } else if isPro {
          Text("View dose map")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.textSecondary)
        } else {
          Text("Dose map — Pro feature")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.textMuted)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.system(size: 11))
          .foregroundStyle(active ? AppTheme.accentBlue.opacity(0.5) : AppTheme.textMuted.opacity(0.5))
      }
      .padding(12)
      .background(active ? AppTheme.accentBlue.opacity(0.08) : AppTheme.backgroundCard)
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10).stroke(
        active ? AppTheme.accentBlue.opacity(0.2) : AppTheme.border,
        lineWidth: 0.5))
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
        Text("Tap \"I took…\" on the gTimer tab to log your first dose.")
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
      guard settings.proBetaAccepted else {
        paywallFeature = .exportHistory
        showPaywall = true
        return
      }
      exportOutcome = .export
      showHistoryExport = true
    } label: {
      Image(systemName: "square.and.arrow.up")
        .foregroundStyle(settings.proBetaAccepted ? AppTheme.accentBlue : AppTheme.textMuted)
    }
    .accessibilityLabel(settings.proBetaAccepted ? "Export history" : "Export history — Pro feature")
  }

  private func handlePendingExportRequest() {
    guard nav.historyExportRequestID != handledExportRequestID else { return }
    handledExportRequestID = nav.historyExportRequestID
    guard settings.proBetaAccepted else {
      paywallFeature = .exportHistory
      showPaywall = true
      return
    }
    exportOutcome = nav.historyExportOutcome
    showHistoryExport = true
  }
}

private enum HistoryExportField: String, CaseIterable, Identifiable {
  case date = "Date"
  case time = "Time"
  case amount = "Amount"
  case unit = "Unit"
  case missed = "Missed"
  case edited = "Edited"
  case earlyBy = "Early by"
  case notes = "Notes"
  case device = "Device"
  case locationName = "Location"
  case coordinates = "Coordinates"
  case accuracy = "Accuracy"
  case locationSource = "Location source"

  var id: String { rawValue }
}

private struct HistoryExportSheet: View {
  @Environment(\.dismiss) private var dismiss

  let doses: [DoseRecord]
  let locationApproximate: Bool
  let initialOutcome: HistoryExportOutcome

  @State private var selectedFields = Set(HistoryExportField.allCases)
  @State private var includeMap = false
  @State private var startDate: Date
  @State private var endDate: Date
  @State private var shareItem: HistoryExportShareItem?

  init(doses: [DoseRecord], locationApproximate: Bool, initialOutcome: HistoryExportOutcome) {
    self.doses = doses
    self.locationApproximate = locationApproximate
    self.initialOutcome = initialOutcome
    let sorted = doses.sorted { $0.time < $1.time }
    _startDate = State(initialValue: sorted.first?.time ?? Date())
    _endDate = State(initialValue: sorted.last?.time ?? Date())
  }

  private var filteredDoses: [DoseRecord] {
    doses
      .filter { $0.time >= startDate && $0.time <= endDate }
      .sorted { $0.time > $1.time }
  }

  private var hasLocationFieldsSelected: Bool {
    selectedFields.contains(.locationName)
      || selectedFields.contains(.coordinates)
      || selectedFields.contains(.accuracy)
      || selectedFields.contains(.locationSource)
      || includeMap
  }

  private var actionTitle: String {
    initialOutcome == .print ? "Print" : "Export PDF"
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Date range") {
          DatePicker("From", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
          DatePicker("To", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
          Text("\(filteredDoses.count) dose record\(filteredDoses.count == 1 ? "" : "s") selected")
            .foregroundStyle(AppTheme.textMuted)
        }

        Section("Fields") {
          ForEach(HistoryExportField.allCases) { field in
            Toggle(field.rawValue, isOn: fieldBinding(field))
          }
        }

        Section("Map") {
          Toggle("Include map/location section", isOn: $includeMap)
          Text("The PDF includes location names and coordinates for mapped doses in the selected range.")
            .font(.footnote)
            .foregroundStyle(AppTheme.textMuted)
        }

        if hasLocationFieldsSelected && filteredDoses.contains(where: \.hasLocation) {
          Section {
            Text("This export includes saved location data. Only export or print it somewhere you trust.")
              .font(.footnote)
              .foregroundStyle(AppTheme.statusAmber)
          }
        }
      }
      .scrollContentBackground(.hidden)
      .background(AppTheme.backgroundPrimary)
      .navigationTitle(initialOutcome == .print ? "Print History" : "Export History")
      .platformInlineNavigationTitle()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(actionTitle) {
            performAction()
          }
          .disabled(filteredDoses.isEmpty || selectedFields.isEmpty || startDate > endDate)
        }
      }
      .sheet(item: $shareItem) { item in
        ShareSheet(items: [item.url])
      }
    }
    .frame(minWidth: 460, minHeight: 560)
    .presentationBackground(AppTheme.backgroundPrimary)
  }

  private func fieldBinding(_ field: HistoryExportField) -> Binding<Bool> {
    Binding {
      selectedFields.contains(field)
    } set: { isSelected in
      if isSelected {
        selectedFields.insert(field)
      } else {
        selectedFields.remove(field)
      }
    }
  }

  private func performAction() {
    let document = HistoryExportDocument(
      doses: filteredDoses,
      fields: HistoryExportField.allCases.filter { selectedFields.contains($0) },
      includeMap: includeMap,
      locationApproximate: locationApproximate,
      startDate: startDate,
      endDate: endDate
    )

    switch initialOutcome {
    case .export:
      do {
        shareItem = try HistoryExportShareItem(url: document.writePDF())
      } catch {
        return
      }
    case .print:
      document.print()
      dismiss()
    }
  }
}

private struct HistoryExportShareItem: Identifiable {
  let id = UUID()
  let url: URL
}

private struct HistoryExportDocument {
  let doses: [DoseRecord]
  let fields: [HistoryExportField]
  let includeMap: Bool
  let locationApproximate: Bool
  let startDate: Date
  let endDate: Date

  private var bodyText: String {
    var lines: [String] = []
    lines.append("gTimer History")
    lines.append("Date range: \(dateTime(startDate)) to \(dateTime(endDate))")
    lines.append("Records: \(doses.count)")
    lines.append("")

    for dose in doses {
      lines.append(rowText(for: dose))
    }

    if includeMap {
      let mapped = doses.filter(\.hasLocation)
      lines.append("")
      lines.append("Map/location section")
      if mapped.isEmpty {
        lines.append("No mapped doses in this date range.")
      } else {
        for dose in mapped {
          let location = dose.displayLocation(approximate: locationApproximate) ?? "Unnamed location"
          let coords = coordinates(for: dose)
          lines.append("\(dateTime(dose.time)) - \(location) - \(coords)")
        }
      }
    }

    return lines.joined(separator: "\n")
  }

  func writePDF() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("gTimer History \(Self.fileStamp()).pdf")
    let data = makePDFData()
    try data.write(to: url, options: .atomic)
    return url
  }

  func print() {
    let text = bodyText
    #if os(macOS)
    let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
    textView.string = text
    textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
    textView.textContainerInset = NSSize(width: 36, height: 36)
    NSPrintOperation(view: textView).run()
    #elseif os(iOS)
    let controller = UIPrintInteractionController.shared
    controller.printingItem = makePDFData()
    controller.present(animated: true)
    #endif
  }

  private func makePDFData() -> Data {
    let output = NSMutableData()
    guard let consumer = CGDataConsumer(data: output as CFMutableData) else { return Data() }
    var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return Data() }

    let font = CTFontCreateWithName("Menlo" as CFString, 10, nil)
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: PlatformExportColor.black,
      .paragraphStyle: paragraph
    ]
    let attributed = NSAttributedString(string: bodyText, attributes: attributes)
    let framesetter = CTFramesetterCreateWithAttributedString(attributed)
    var currentRange = CFRange(location: 0, length: 0)
    let pageRect = mediaBox.insetBy(dx: 42, dy: 42)

    repeat {
      context.beginPDFPage(nil)
      context.textMatrix = .identity
      context.translateBy(x: 0, y: mediaBox.height)
      context.scaleBy(x: 1.0, y: -1.0)

      let path = CGMutablePath()
      path.addRect(pageRect)
      let frame = CTFramesetterCreateFrame(framesetter, currentRange, path, nil)
      CTFrameDraw(frame, context)
      let visibleRange = CTFrameGetVisibleStringRange(frame)
      currentRange.location += visibleRange.length
      context.endPDFPage()
    } while currentRange.location < attributed.length

    context.closePDF()
    return output as Data
  }

  private func rowText(for dose: DoseRecord) -> String {
    fields.map { value(for: $0, dose: dose) }.joined(separator: " | ")
  }

  private func value(for field: HistoryExportField, dose: DoseRecord) -> String {
    switch field {
    case .date:
      return "Date: \(date(dose.time))"
    case .time:
      return "Time: \(time(dose.time))"
    case .amount:
      return "Amount: \(dose.amount.formatted(.number.precision(.fractionLength(0...3))))"
    case .unit:
      return "Unit: \(dose.unit)"
    case .missed:
      return "Missed: \(dose.missed ? "Yes" : "No")"
    case .edited:
      return "Edited: \(dose.edited ? "Yes" : "No")"
    case .earlyBy:
      return "Early by: \(dose.formattedEarlyBy ?? "")"
    case .notes:
      return "Notes: \(dose.notes)"
    case .device:
      return "Device: \(dose.deviceName)"
    case .locationName:
      return "Location: \(dose.displayLocation(approximate: locationApproximate) ?? "")"
    case .coordinates:
      return "Coordinates: \(dose.hasLocation ? coordinates(for: dose) : "")"
    case .accuracy:
      return "Accuracy: \(dose.locationAccuracyMeters.map { "\(Int($0.rounded()))m" } ?? "")"
    case .locationSource:
      return "Location source: \(dose.resolvedLocationSource)"
    }
  }

  private func date(_ value: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: value)
  }

  private func time(_ value: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter.string(from: value)
  }

  private func dateTime(_ value: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: value)
  }

  private func coordinates(for dose: DoseRecord) -> String {
    guard let lat = dose.latitude, let lon = dose.longitude else { return "" }
    return String(format: "%.6f, %.6f", lat, lon)
  }

  private static func fileStamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
    return formatter.string(from: Date())
  }
}

#if os(macOS)
private typealias PlatformExportColor = NSColor
#else
private typealias PlatformExportColor = UIColor
#endif

private extension View {
  @ViewBuilder
  func platformDoseMapPresentation(isPresented: Binding<Bool>) -> some View {
    #if os(macOS)
    self.sheet(isPresented: isPresented) {
      DoseMapView()
        .frame(minWidth: 920, idealWidth: 1040, minHeight: 680, idealHeight: 760)
    }
    #else
    self.fullScreenCover(isPresented: isPresented) {
      DoseMapView()
    }
    #endif
  }
}
