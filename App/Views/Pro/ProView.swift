import SwiftUI

struct ProView: View {
  @Environment(SettingsManager.self) private var settings
  @State private var firstName = ""
  @State private var lastName = ""
  @State private var email = ""
  @State private var termsAccepted = false
  @State private var showSuccess = false

  var canActivate: Bool {
    !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
    !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
    isValidEmail(email) &&
    termsAccepted
  }

  var body: some View {
    NavigationStack {
      ZStack {
        AppTheme.backgroundPrimary.ignoresSafeArea()
        ScrollView {
          if settings.proBetaAccepted {
            activeView
          } else {
            signupView
          }
        }
      }
      .navigationTitle("Pro")
      .toolbarColorScheme(.dark, for: .navigationBar)
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - Active View

  private var activeView: some View {
    VStack(spacing: 24) {
      // Badge
      VStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(
              LinearGradient(colors: [AppTheme.proAmber, AppTheme.proOrange],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .frame(width: 80, height: 80)
          Image(systemName: "star.fill")
            .font(.system(size: 36))
            .foregroundStyle(.white)
        }
        Text("G Timer Pro")
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(
            LinearGradient(colors: [AppTheme.proAmber, AppTheme.proOrange],
                           startPoint: .leading, endPoint: .trailing)
          )
        Text("ACTIVE")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(AppTheme.statusGreen)
          .padding(.horizontal, 14)
          .padding(.vertical, 5)
          .background(AppTheme.statusGreen.opacity(0.12))
          .clipShape(Capsule())
      }
      .padding(.top, 32)

      // Unlocked features
      VStack(alignment: .leading, spacing: 10) {
        Text("UNLOCKED FEATURES")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(AppTheme.textMuted)
          .padding(.leading, 4)

        VStack(spacing: 8) {
          unlockedFeature("Full dose history (no limit)", "clock.arrow.circlepath")
          unlockedFeature("Edit dose records", "pencil")
          unlockedFeature("CSV export", "square.and.arrow.up")
          unlockedFeature("Missed dose logging", "xmark.circle")
          unlockedFeature("Profile & display name", "person.crop.circle")
          unlockedFeature("Safe-to-redose notifications", "bell.badge.fill")
        }
      }
      .padding(.horizontal, 20)

      // Reset option
      Button(role: .destructive) {
        settings.proBetaAccepted = false
      } label: {
        Text("Deactivate Beta Access")
          .font(.system(size: 14))
          .foregroundStyle(AppTheme.textMuted)
      }
      .padding(.top, 10)
      .padding(.bottom, 40)
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Signup View

  private var signupView: some View {
    VStack(spacing: 24) {
      // Header
      VStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(AppTheme.proAmber.opacity(0.15))
            .frame(width: 80, height: 80)
          Image(systemName: "star.fill")
            .font(.system(size: 36))
            .foregroundStyle(AppTheme.proAmber)
        }
        Text("G Timer Pro")
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(AppTheme.textPrimary)
        Text("Beta Access")
          .font(.system(size: 16))
          .foregroundStyle(AppTheme.proAmber)
      }
      .padding(.top, 32)

      // Features
      VStack(alignment: .leading, spacing: 8) {
        Text("WHAT YOU GET")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(AppTheme.textMuted)
          .padding(.leading, 4)
        VStack(spacing: 8) {
          featureRow("Full unlimited history", "clock.arrow.circlepath", AppTheme.accentBlue)
          featureRow("Edit & correct dose records", "pencil", AppTheme.accentBlue)
          featureRow("Export your data as CSV", "square.and.arrow.up", AppTheme.accentBlue)
          featureRow("Log missed/forgotten doses", "xmark.circle", AppTheme.accentBlue)
          featureRow("Profile & display name", "person.crop.circle", AppTheme.accentBlue)
          featureRow("Redose notifications", "bell.badge.fill", AppTheme.accentBlue)
        }
      }
      .padding(.horizontal, 20)

      // Form
      VStack(spacing: 16) {
        Text("GET BETA ACCESS")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(AppTheme.textMuted)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.leading, 4)

        inputField("First Name", text: $firstName)
        inputField("Last Name", text: $lastName)
        inputField("Email", text: $email, keyboard: .emailAddress)

        HStack(alignment: .top, spacing: 12) {
          Button {
            termsAccepted.toggle()
          } label: {
            Image(systemName: termsAccepted ? "checkmark.square.fill" : "square")
              .font(.system(size: 22))
              .foregroundStyle(termsAccepted ? AppTheme.accentBlue : AppTheme.textMuted)
          }
          .accessibilityLabel("Accept terms")
          Text("I understand this is a harm-reduction tool and not medical advice. I accept responsibility for my own safety and use.")
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(14)
        .background(AppTheme.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))

        Button {
          if canActivate { activate() }
        } label: {
          Text("Get Beta Access")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(canActivate ? AppTheme.proAmber : AppTheme.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canActivate)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 40)
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Helpers

  private func inputField(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
    TextField(label, text: text)
      .keyboardType(keyboard)
      .textContentType(keyboard == .emailAddress ? .emailAddress : .name)
      .autocorrectionDisabled()
      .font(.system(size: 16))
      .foregroundStyle(AppTheme.textPrimary)
      .padding(14)
      .background(AppTheme.backgroundCard)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
  }

  private func featureRow(_ text: String, _ icon: String, _ color: Color) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .foregroundStyle(color)
        .frame(width: 24)
      Text(text)
        .font(.system(size: 15))
        .foregroundStyle(AppTheme.textSecondary)
      Spacer()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(AppTheme.backgroundCard)
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private func unlockedFeature(_ text: String, _ icon: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .foregroundStyle(AppTheme.proAmber)
        .frame(width: 24)
      Text(text)
        .font(.system(size: 15))
        .foregroundStyle(AppTheme.textSecondary)
      Spacer()
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(AppTheme.statusGreen)
        .font(.system(size: 16))
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(AppTheme.backgroundCard)
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private func activate() {
    settings.proBetaAccepted = true
    if !settings.vanityName.isEmpty == false {
      settings.vanityName = firstName
    }
  }

  private func isValidEmail(_ email: String) -> Bool {
    email.contains("@") && email.contains(".") && email.count > 5
  }
}
