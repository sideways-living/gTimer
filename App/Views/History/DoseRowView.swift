import SwiftUI

struct DoseRowView: View {
  let dose: DoseRecord
  let isPro: Bool
  let locationApproximate: Bool
  var onEdit: () -> Void
  var onDelete: () -> Void

  @State private var showDeleteConfirm = false
  @State private var showMapSheet = false
  @State private var showLocationPaywall = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 12) {
        // Color indicator
        RoundedRectangle(cornerRadius: 2)
          .fill(dose.missed ? AppTheme.statusAmber : AppTheme.accentBlue)
          .frame(width: 4, height: 44)

        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Text("\(dose.amount.formatted(.number.precision(.fractionLength(1))))\(dose.unit)")
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(AppTheme.textPrimary)
            if dose.missed { pill("Missed", color: AppTheme.statusAmber) }
            if dose.edited { pill("Edited", color: AppTheme.textMuted) }
          }
          HStack(spacing: 4) {
            Text(dose.time.formatted(date: .abbreviated, time: .shortened))
              .font(.system(size: 13))
              .foregroundStyle(AppTheme.textSecondary)
          }
          if !dose.notes.isEmpty {
            Text(dose.notes)
              .font(.system(size: 12))
              .foregroundStyle(AppTheme.textMuted)
              .lineLimit(1)
          }
        }

        Spacer()

        HStack(spacing: 12) {
          if isPro {
            Button {
              onEdit()
            } label: {
              Image(systemName: "pencil")
                .foregroundStyle(AppTheme.accentBlue)
                .font(.system(size: 15))
            }
            .accessibilityLabel("Edit dose")
          }
          Button(role: .destructive) {
            showDeleteConfirm = true
          } label: {
            Image(systemName: "trash")
              .foregroundStyle(AppTheme.statusRed.opacity(0.7))
              .font(.system(size: 15))
          }
          .accessibilityLabel("Delete dose")
        }
      }
      .padding(.horizontal, 14)
      .padding(.top, 10)
      .padding(.bottom, dose.hasLocation ? 6 : 10)

      // Location row — opens map sheet (Pro) or paywall (non-Pro)
      if let locLabel = dose.displayLocation(approximate: locationApproximate) {
        Button {
          if isPro { showMapSheet = true } else { showLocationPaywall = true }
        } label: {
          HStack(spacing: 5) {
            Image(systemName: "location.fill")
              .font(.system(size: 10))
              .foregroundStyle(isPro ? AppTheme.accentBlue : AppTheme.textMuted)
            Text(locLabel)
              .font(.system(size: 12))
              .foregroundStyle(isPro ? AppTheme.textSecondary : AppTheme.textMuted)
              .lineLimit(1)
            Image(systemName: "chevron.right")
              .font(.system(size: 9))
              .foregroundStyle(AppTheme.textMuted.opacity(0.5))
            Spacer()
          }
          .padding(.horizontal, 14)
          .padding(.bottom, 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPro ? "View location on map: \(locLabel)" : "Unlock location map — Pro feature")
      }
    }
    .background(AppTheme.backgroundCard)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 0.5))
    .padding(.bottom, 6)
    .confirmationDialog("Delete this dose record?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
      Button("Delete", role: .destructive) { onDelete() }
      Button("Cancel", role: .cancel) {}
    }
    .sheet(isPresented: $showMapSheet) {
      DoseDetailMapSheet(dose: dose)
    }
    .sheet(isPresented: $showLocationPaywall) {
      PaywallSheet(feature: .doseLocations)
    }
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
}
