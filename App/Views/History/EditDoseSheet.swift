import SwiftUI

struct EditDoseSheet: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  var dose: DoseRecord

  @State private var amountText: String = ""
  @State private var selectedDate: Date = Date()
  @State private var notes: String = ""
  @State private var showDiscard = false

  private var isDirty: Bool {
    let a = Double(amountText) ?? dose.amount
    return a != dose.amount || selectedDate != dose.time || notes != dose.notes
  }

  var body: some View {
    NavigationStack {
      ZStack {
        AppTheme.backgroundPrimary.ignoresSafeArea()
        VStack(spacing: 20) {
          field(label: "Amount (\(settings.unit))") {
            TextField("Amount", text: $amountText)
              .keyboardType(.decimalPad)
              .font(.system(size: 20, weight: .semibold))
              .foregroundStyle(AppTheme.textPrimary)
          }

          VStack(alignment: .leading, spacing: 8) {
            Text("Date & Time")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(AppTheme.textSecondary)
            DatePicker("Date & Time", selection: $selectedDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
              .labelsHidden()
              .colorScheme(.dark)
              .padding(10)
              .background(AppTheme.backgroundCard)
              .clipShape(RoundedRectangle(cornerRadius: 12))
          }

          field(label: "Notes") {
            TextField("Notes", text: $notes, axis: .vertical)
              .font(.system(size: 16))
              .foregroundStyle(AppTheme.textPrimary)
              .lineLimit(2...4)
          }

          Spacer()

          Button {
            let a = Double(amountText) ?? dose.amount
            dose.amount = a
            dose.time = selectedDate
            dose.notes = notes
            dose.edited = true
            try? context.save()
            dismiss()
          } label: {
            Text("Save Changes")
              .font(.system(size: 17, weight: .semibold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 15)
              .background(AppTheme.accentBlue)
              .clipShape(RoundedRectangle(cornerRadius: 14))
          }
        }
        .padding(20)
      }
      .navigationTitle("Edit Dose")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            if isDirty { showDiscard = true } else { dismiss() }
          }
          .foregroundStyle(AppTheme.textSecondary)
        }
      }
      .confirmationDialog("Discard changes?", isPresented: $showDiscard, titleVisibility: .visible) {
        Button("Discard", role: .destructive) { dismiss() }
        Button("Keep Editing", role: .cancel) {}
      }
    }
    .presentationDetents([.large])
    .preferredColorScheme(.dark)
    .onAppear {
      amountText = dose.amount.formatted(.number.precision(.fractionLength(1)))
      selectedDate = dose.time
      notes = dose.notes
    }
  }

  private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(label)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(AppTheme.textSecondary)
      content()
        .padding(14)
        .background(AppTheme.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
    }
  }
}
