import SwiftUI

struct CustomDoseSheet: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(\.dismiss) private var dismiss

  // Closure receives (amount, notes)
  var onLog: (Double, String) -> Void

  @State private var amountText = ""
  @State private var notes = ""

  private var parsedAmount: Double? {
    guard let d = Double(amountText), d > 0 else { return nil }
    return d
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Amount (\(settings.unit))")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.textSecondary)
          TextField("e.g. 1.2", text: $amountText)
            .platformKeyboardType(.decimalPad)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(14)
            .background(AppTheme.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("Notes (optional)")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.textSecondary)
          TextField("Add a note…", text: $notes, axis: .vertical)
            .font(.system(size: 16))
            .foregroundStyle(AppTheme.textPrimary)
            .lineLimit(3...5)
            .padding(14)
            .background(AppTheme.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
        }

        Spacer()

        Button {
          if let a = parsedAmount {
            onLog(a, notes)
            dismiss()
          }
        } label: {
          Text("Log Dose")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(parsedAmount != nil ? AppTheme.accentBlue : AppTheme.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(parsedAmount == nil)
      }
      .padding(20)
      .background(AppTheme.backgroundPrimary.ignoresSafeArea())
      .navigationTitle("Custom Amount")
      .platformInlineNavigationTitle()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .foregroundStyle(AppTheme.textSecondary)
        }
      }
    }
    .presentationDetents([.medium])
    .presentationBackground(AppTheme.backgroundPrimary)
    .preferredColorScheme(.dark)
  }
}
