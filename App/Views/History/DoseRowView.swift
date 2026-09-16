import SwiftUI

struct DoseRowView: View {
  let dose: DoseRecord
  let isPro: Bool
  let locationApproximate: Bool
  var onEdit: () -> Void
  var onDelete: (String) -> Void

  @State private var showDeleteConfirm = false
  @State private var showMapSheet = false
  @State private var showLocationPaywall = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 12) {
        // Color indicator
        RoundedRectangle(cornerRadius: 2)
          .fill(dose.isDeletedForSync ? AppTheme.statusRed : (dose.missed ? AppTheme.statusAmber : AppTheme.accentBlue))
          .frame(width: 4, height: 44)

        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Text("\(dose.amount.formatted(.number.precision(.fractionLength(1))))\(dose.unit)")
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(AppTheme.textPrimary)
            if dose.wasTakenEarly { pill("Early", color: AppTheme.statusRed) }
            if dose.missed { pill("Missed", color: AppTheme.statusAmber) }
            if dose.edited { pill("Edited", color: AppTheme.textMuted) }
            if dose.isDeletedForSync { pill("Deleted", color: AppTheme.statusRed) }
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
          if !dose.tags.isEmpty || !dose.people.isEmpty {
            tokenRow
          }
          if let earlyBy = dose.formattedEarlyBy {
            HStack(spacing: 4) {
              Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
              Text("Taken \(earlyBy) early")
                .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(AppTheme.statusRed)
          }
          if dose.isDeletedForSync {
            deletedSummary
          }
        }

        Spacer()

        rowActions
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
    .sheet(isPresented: $showDeleteConfirm) {
      DeletionReasonSheet(
        title: "Delete dose record",
        message: "The record will be kept in deleted history with the reason you enter.",
        actionTitle: "Delete",
        example: "Duplicate recording of dose"
      ) { reason in
        onDelete(reason)
        showDeleteConfirm = false
      }
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

  private func personPill(_ name: String) -> some View {
    HStack(spacing: 4) {
      Image(systemName: "person.fill")
        .font(.system(size: 8, weight: .semibold))
      Text(name)
        .font(.system(size: 10, weight: .semibold))
    }
    .foregroundStyle(AppTheme.textSecondary)
    .padding(.horizontal, 7)
    .padding(.vertical, 2)
    .background(AppTheme.textSecondary.opacity(0.15))
    .clipShape(Capsule())
  }

  private func displayedTag(_ tag: String) -> String {
    let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }
    return trimmed.hasPrefix("#") ? trimmed : "#\(trimmed)"
  }

  private var tokenRow: some View {
    HStack(spacing: 5) {
      ForEach(dose.tags.prefix(4), id: \.self) { tag in
        pill(displayedTag(tag), color: AppTheme.accentBlue)
      }
      ForEach(dose.people.prefix(max(0, 4 - dose.tags.prefix(4).count)), id: \.self) { person in
        personPill(person)
      }
    }
    .padding(.top, 2)
  }

  @ViewBuilder
  private var rowActions: some View {
    if !dose.isDeletedForSync {
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
        Button {
          showDeleteConfirm = true
        } label: {
          Image(systemName: "trash")
            .foregroundStyle(AppTheme.statusRed.opacity(0.7))
            .font(.system(size: 15))
        }
        .accessibilityLabel("Delete dose")
      }
    }
  }

  private var deletedSummary: some View {
    VStack(alignment: .leading, spacing: 3) {
      if let deletedAt = dose.deletedAt {
        Text("Deleted \(deletedAt.formatted(date: .abbreviated, time: .shortened))")
      }
      if let reason = dose.deletionReason, !reason.isEmpty {
        Text("Reason: \(reason)")
      }
    }
    .font(.system(size: 12, weight: .medium))
    .foregroundStyle(AppTheme.statusRed)
  }
}

struct DeletionReasonSheet: View {
  @Environment(\.dismiss) private var dismiss
  let title: String
  let message: String
  let actionTitle: String
  let example: String
  var onSubmit: (String) -> Void

  @State private var reason = ""

  private var cleanReason: String {
    reason.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 16) {
        Text(message)
          .font(.system(size: 14))
          .foregroundStyle(AppTheme.textSecondary)
          .fixedSize(horizontal: false, vertical: true)

        VStack(alignment: .leading, spacing: 8) {
          Text("Reason")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)
          TextField(text: $reason, axis: .vertical) {
            Text(example)
          }
            .textFieldStyle(.roundedBorder)
            .lineLimit(2...4)
        }

        Spacer(minLength: 0)
      }
      .padding(20)
      .background(AppTheme.backgroundPrimary.ignoresSafeArea())
      .navigationTitle(title)
      .platformInlineNavigationTitle()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(role: .destructive) {
            onSubmit(cleanReason)
            dismiss()
          } label: {
            Text(actionTitle)
          }
          .disabled(cleanReason.isEmpty)
        }
      }
    }
    .presentationBackground(AppTheme.backgroundPrimary)
    .frame(minWidth: 380, minHeight: 240)
  }
}
