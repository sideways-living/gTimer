import SwiftUI

struct DoseRowView: View {
  let dose: DoseRecord
  let isPro: Bool
  var onEdit: () -> Void
  var onDelete: () -> Void

  @State private var showDeleteConfirm = false

  var body: some View {
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
          if let loc = dose.locationName {
            Text("· \(loc)")
              .font(.system(size: 12))
              .foregroundStyle(AppTheme.textMuted)
              .lineLimit(1)
          }
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
    .padding(.vertical, 10)
    .background(AppTheme.backgroundCard)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 0.5))
    .padding(.bottom, 6)
    .confirmationDialog("Delete this dose record?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
      Button("Delete", role: .destructive) { onDelete() }
      Button("Cancel", role: .cancel) {}
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
