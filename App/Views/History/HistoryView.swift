import SwiftUI
import SwiftData

struct HistoryView: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(\.modelContext) private var context
  @Query(sort: \DoseRecord.time, order: .reverse) private var allDoses: [DoseRecord]

  @State private var showDeleteAll = false
  @State private var editingDose: DoseRecord?

  private var visibleDoses: [DoseRecord] {
    if settings.proBetaAccepted { return allDoses }
    let cutoff = Date().addingTimeInterval(-24 * 3600)
    return allDoses.filter { $0.time >= cutoff }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        AppTheme.backgroundPrimary.ignoresSafeArea()
        Group {
          if allDoses.isEmpty {
            emptyState
          } else {
            doseList
          }
        }
      }
      .navigationTitle("History")
      .toolbarColorScheme(.dark, for: .navigationBar)
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          if settings.proBetaAccepted && !allDoses.isEmpty {
            exportButton
          }
          if !allDoses.isEmpty {
            Button {
              showDeleteAll = true
            } label: {
              Image(systemName: "trash")
                .foregroundStyle(AppTheme.statusRed)
            }
            .accessibilityLabel("Clear All")
          }
        }
      }
      .confirmationDialog("Delete all dose records? This cannot be undone.", isPresented: $showDeleteAll, titleVisibility: .visible) {
        Button("Delete All", role: .destructive) {
          DoseStore.deleteAll(context: context)
        }
        Button("Cancel", role: .cancel) {}
      }
      .sheet(item: $editingDose) { dose in
        EditDoseSheet(dose: dose)
      }
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - List

  private var doseList: some View {
    ScrollView {
      VStack(spacing: 0) {
        if !settings.proBetaAccepted {
          proNudge
        }

        if visibleDoses.isEmpty {
          hiddenByFreeModeBanner
        } else {
          LazyVStack(spacing: 6) {
            ForEach(visibleDoses) { dose in
              DoseRowView(dose: dose, isPro: settings.proBetaAccepted) {
                if settings.proBetaAccepted { editingDose = dose }
              } onDelete: {
                DoseStore.delete(dose, context: context)
              }
            }
          }
          .padding(.horizontal, 16)
          .padding(.top, 12)
        }
      }
      .padding(.bottom, 100)
    }
  }

  // MARK: - Empty / banners

  private var emptyState: some View {
    VStack(spacing: 14) {
      Image(systemName: "clock.arrow.circlepath")
        .font(.system(size: 48))
        .foregroundStyle(AppTheme.textMuted)
      Text("No doses logged yet")
        .font(.system(size: 19, weight: .semibold))
        .foregroundStyle(AppTheme.textSecondary)
      Text("Tap \"I took…\" on the Timer tab to log your first dose.")
        .font(.system(size: 14))
        .foregroundStyle(AppTheme.textMuted)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var hiddenByFreeModeBanner: some View {
    VStack(spacing: 10) {
      Text("Older records are hidden in free mode.")
        .font(.system(size: 14))
        .foregroundStyle(AppTheme.textMuted)
        .multilineTextAlignment(.center)
    }
    .padding(.top, 32)
  }

  private var proNudge: some View {
    HStack(spacing: 8) {
      Image(systemName: "lock.fill")
        .foregroundStyle(AppTheme.proAmber)
        .font(.system(size: 13))
      Text("Showing last 24 hours. Activate Pro for full history, editing & export.")
        .font(.system(size: 13))
        .foregroundStyle(AppTheme.proAmber)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AppTheme.proAmber.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.proAmber.opacity(0.2), lineWidth: 0.5))
    .padding(.horizontal, 16)
    .padding(.top, 12)
  }

  // MARK: - Export

  private var exportButton: some View {
    ShareLink(
      item: csvContent(),
      subject: Text("G Timer History"),
      message: Text("Dose history export")
    ) {
      Image(systemName: "square.and.arrow.up")
        .foregroundStyle(AppTheme.accentBlue)
    }
    .accessibilityLabel("Export CSV")
  }

  private func csvContent() -> String {
    var lines = ["Date,Time,Amount,Unit,Missed,Edited,Notes,Device,Location"]
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
        d.locationName ?? ""
      ].joined(separator: ",")
      lines.append(row)
    }
    return lines.joined(separator: "\n")
  }
}
