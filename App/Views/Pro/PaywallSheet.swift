import SwiftUI

struct PaywallSheet: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(\.dismiss) private var dismiss

  let feature: ProFeature
  var onActivated: (() -> Void)? = nil

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Spacer()
        Button {
          PaywallThrottle.shared.markDismissed(feature)
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
      .padding(.horizontal, 20)
      .padding(.top, 16)

      ScrollView {
        VStack(spacing: 20) {
          // Feature icon + headline
          VStack(spacing: 12) {
            ZStack {
              Circle()
                .fill(feature.accentColor.opacity(0.14))
                .frame(width: 72, height: 72)
              Image(systemName: feature.icon)
                .font(.system(size: 32))
                .foregroundStyle(feature.accentColor)
            }
            .padding(.top, 28)

            Text("Unlock gTimer Pro")
              .font(.system(size: 22, weight: .bold))
              .foregroundStyle(AppTheme.textPrimary)

            Text(feature.featureDescription)
              .font(.system(size: 15))
              .foregroundStyle(AppTheme.textSecondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 24)
          }

          // Full Pro feature list
          VStack(alignment: .leading, spacing: 0) {
            Text("ALL PRO FEATURES")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(AppTheme.textMuted)
              .kerning(0.4)
              .padding(.horizontal, 14)
              .padding(.top, 14)
              .padding(.bottom, 8)

            ForEach(Array(ProFeature.allCases.enumerated()), id: \.element.rawValue) { idx, f in
              if idx > 0 {
                Divider().background(AppTheme.border).padding(.horizontal, 14)
              }
              HStack(spacing: 10) {
                Image(systemName: f.icon)
                  .foregroundStyle(f == feature ? f.accentColor : AppTheme.textMuted)
                  .frame(width: 20)
                  .font(.system(size: 14))
                Text(f.title)
                  .font(.system(size: 14, weight: f == feature ? .semibold : .regular))
                  .foregroundStyle(f == feature ? AppTheme.textPrimary : AppTheme.textSecondary)
                Spacer()
                if f == feature {
                  Text("this feature")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(f.accentColor)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(f.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                } else {
                  Image(systemName: "checkmark")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textMuted.opacity(0.5))
                }
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 10)
            }
          }
          .background(AppTheme.backgroundCard)
          .clipShape(RoundedRectangle(cornerRadius: 14))
          .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border, lineWidth: 0.5))
          .padding(.horizontal, 20)

          // Privacy note for location features
          if feature == .doseLocations || feature == .doseMap || feature == .locationInsights {
            HStack(spacing: 8) {
              Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(AppTheme.statusGreen)
              Text("Location history is stored locally on this device only.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textMuted)
            }
            .padding(.horizontal, 20)
          }

          // StoreKit placeholder note
          Text("Beta access is free. A subscription will be required in a future release.")
            .font(.system(size: 11))
            .foregroundStyle(AppTheme.textMuted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

          Spacer(minLength: 8)
        }
      }

      // CTA buttons
      VStack(spacing: 10) {
        Button {
          settings.proBetaAccepted = true
          onActivated?()
          dismiss()
        } label: {
          Text("Activate Pro — free beta")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
              LinearGradient(colors: [AppTheme.proAmber, AppTheme.proOrange],
                             startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20)

        // TODO: Replace the beta button above with StoreKit 2 purchase flow.
        // Product IDs: "com.gtimer.pro.monthly", "com.gtimer.pro.yearly", "com.gtimer.pro.lifetime"
        // Implement Product.products(for:), Purchase flow, Transaction.currentEntitlement,
        // and a restore purchases button. Link to terms/privacy policy URLs.

        Button("Not now") {
          PaywallThrottle.shared.markDismissed(feature)
          dismiss()
        }
        .font(.system(size: 15))
        .foregroundStyle(AppTheme.textMuted)
        .padding(.bottom, 12)
      }
      .padding(.top, 8)
      .background(AppTheme.backgroundPrimary)
    }
    .background(AppTheme.backgroundPrimary.ignoresSafeArea())
    .presentationDetents([.large])
    .presentationBackground(AppTheme.backgroundPrimary)
    .preferredColorScheme(.dark)
  }
}
