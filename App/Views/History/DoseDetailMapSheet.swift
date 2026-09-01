import SwiftUI
import MapKit
import SwiftData
#if os(macOS)
import AppKit
#endif

struct DoseDetailMapSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @Environment(SettingsManager.self) private var settings

  var dose: DoseRecord
  var onLocationRemoved: (() -> Void)? = nil

  @State private var position: MapCameraPosition = .automatic
  @State private var showRemoveConfirm = false
  @State private var copied = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        HStack {
          Text("Dose Location")
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

        // Map
        Map(position: $position) {
          Annotation("", coordinate: dose.coordinate, anchor: .bottom) {
            VStack(spacing: 2) {
              ZStack {
                Circle()
                  .fill(AppTheme.accentBlue)
                  .frame(width: 28, height: 28)
                  .shadow(color: AppTheme.accentBlue.opacity(0.5), radius: 6)
                Image(systemName: "drop.fill")
                  .font(.system(size: 13, weight: .bold))
                  .foregroundStyle(.white)
              }
              Triangle()
                .fill(AppTheme.accentBlue)
                .frame(width: 8, height: 5)
            }
          }
        }
        .mapStyle(.standard)
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .onAppear {
          position = .camera(MapCamera(
            centerCoordinate: dose.coordinate,
            distance: 1500
          ))
        }

        // Info card
        VStack(alignment: .leading, spacing: 14) {
          HStack(spacing: 12) {
            ZStack {
              Circle().fill(AppTheme.accentBlue.opacity(0.15)).frame(width: 44, height: 44)
              Image(systemName: "drop.fill")
                .foregroundStyle(AppTheme.accentBlue)
                .font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 3) {
              Text("\(dose.amount.formatted(.number.precision(.fractionLength(1))))\(dose.unit)")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
              Text(dose.time.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
              if let name = dose.locationName, !name.isEmpty {
                HStack(spacing: 4) {
                  Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.accentBlue)
                  Text(name)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                }
              } else if let coordStr = dose.displayLocation(approximate: false) {
                Text(coordStr)
                  .font(.system(size: 12, design: .monospaced))
                  .foregroundStyle(AppTheme.textMuted)
              }
              if let acc = dose.locationAccuracyMeters, acc > 0 {
                Text("Accuracy: ±\(Int(acc))m")
                  .font(.system(size: 11))
                  .foregroundStyle(AppTheme.textMuted)
              }
            }
            Spacer()
          }
          .padding(16)
          .background(AppTheme.backgroundCard)
          .clipShape(RoundedRectangle(cornerRadius: 14))
          .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border, lineWidth: 0.5))

          // Actions
          HStack(spacing: 10) {
            actionButton("map", "Open in Maps") {
              let item = MKMapItem(placemark: MKPlacemark(coordinate: dose.coordinate))
              item.name = dose.locationName ?? "Dose location"
              item.openInMaps()
            }

            actionButton(copied ? "checkmark" : "doc.on.doc", copied ? "Copied" : "Copy Coords") {
              let text = String(format: "%.5f, %.5f",
                                dose.latitude ?? 0, dose.longitude ?? 0)
              copyToPasteboard(text)
              withAnimation(.snappy) { copied = true }
              Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.snappy) { copied = false }
              }
            }

            if settings.proBetaAccepted {
              actionButton("location.slash", "Remove") {
                showRemoveConfirm = true
              }
              .foregroundStyle(AppTheme.statusRed)
            }
          }
        }
        .padding(16)

        Spacer()
      }
      .background(AppTheme.backgroundPrimary.ignoresSafeArea())
      .navigationTitle("Dose Location")
      .platformInlineNavigationTitle()
      .platformNavigationBarStyle()
      .confirmationDialog("Remove location from this dose?",
                          isPresented: $showRemoveConfirm, titleVisibility: .visible) {
        Button("Remove Location", role: .destructive) {
          dose.latitude = nil
          dose.longitude = nil
          dose.locationName = nil
          dose.locationAccuracyMeters = nil
          dose.locationCapturedAt = nil
          dose.locationSource = "none"
          dose.edited = true
          try? context.save()
          DoseStore.refreshSharedAfterEdit(context: context, settings: settings)
          onLocationRemoved?()
          dismiss()
        }
        Button("Cancel", role: .cancel) {}
      }
    }
    .presentationDetents([.large])
    .preferredColorScheme(.dark)
  }

  private func actionButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: 16))
          .foregroundStyle(AppTheme.accentBlue)
        Text(label)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(AppTheme.textSecondary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(AppTheme.backgroundCard)
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 0.5))
    }
    .accessibilityLabel(label)
  }

  private func copyToPasteboard(_ text: String) {
    #if os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #else
    UIPasteboard.general.string = text
    #endif
  }
}

// Small triangle for the map pin point
private struct Triangle: Shape {
  func path(in rect: CGRect) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
    p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
    p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    p.closeSubpath()
    return p
  }
}
