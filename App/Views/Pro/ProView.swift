import SwiftUI

struct ProView: View {
  @Environment(SettingsManager.self) private var settings
  @State private var firstName = ""
  @State private var lastName = ""
  @State private var email = ""
  @State private var termsAccepted = false

  private var canActivate: Bool {
    !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
    !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
    isValidEmail(email) && termsAccepted
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        if settings.proBetaAccepted {
          activeView
        } else {
          signupView
        }
      }
      .contentMargins(.bottom, 24, for: .scrollContent)
      .background(AppTheme.backgroundPrimary.ignoresSafeArea())
      .navigationTitle("Pro")
      .toolbarBackground(AppTheme.backgroundSecondary, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
    }
    .background(AppTheme.backgroundPrimary.ignoresSafeArea())
  }

  // MARK: - Active state

  private var activeView: some View {
    VStack(spacing: 24) {
      VStack(spacing: 14) {
        ZStack {
          Circle()
            .fill(LinearGradient(colors: [AppTheme.proAmber, AppTheme.proOrange],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 84, height: 84)
            .shadow(color: AppTheme.proAmber.opacity(0.4), radius: 20)
          Image(systemName: "star.fill").font(.system(size: 38)).foregroundStyle(.white)
        }
        Text("G Timer Pro")
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(
            LinearGradient(colors: [AppTheme.proAmber, AppTheme.proOrange],
                           startPoint: .leading, endPoint: .trailing)
          )
        Text("ACTIVE")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(AppTheme.statusGreen)
          .kerning(1)
          .padding(.horizontal, 16).padding(.vertical, 6)
          .background(AppTheme.statusGreen.opacity(0.12))
          .clipShape(Capsule())
          .overlay(Capsule().stroke(AppTheme.statusGreen.opacity(0.3), lineWidth: 0.5))

        if !settings.vanityName.isEmpty {
          Text("Welcome, \(settings.vanityName)")
            .font(.system(size: 15)).foregroundStyle(AppTheme.textSecondary)
        }
      }
      .padding(.top, 36)

      featureListSection(unlocked: true)
        .padding(.horizontal, 20)

      Button(role: .destructive) {
        settings.proBetaAccepted = false
      } label: {
        Text("Deactivate Beta Access")
          .font(.system(size: 14)).foregroundStyle(AppTheme.textMuted)
      }
      .padding(.top, 4)
    }
    .frame(maxWidth: .infinity)
    .padding(.bottom, 20)
  }

  // MARK: - Signup form

  private var signupView: some View {
    VStack(spacing: 24) {
      // Hero
      VStack(spacing: 12) {
        ZStack {
          Circle().fill(AppTheme.proAmber.opacity(0.13)).frame(width: 84, height: 84)
          Image(systemName: "star.fill").font(.system(size: 38)).foregroundStyle(AppTheme.proAmber)
        }
        Text("G Timer Pro")
          .font(.system(size: 28, weight: .bold)).foregroundStyle(AppTheme.textPrimary)
        Text("Beta Access")
          .font(.system(size: 16, weight: .medium)).foregroundStyle(AppTheme.proAmber)
        Text("Unlock all features instantly — free during beta.")
          .font(.system(size: 14)).foregroundStyle(AppTheme.textMuted)
          .multilineTextAlignment(.center).padding(.horizontal, 32)
      }
      .padding(.top, 36)

      featureListSection(unlocked: false)
        .padding(.horizontal, 20)

      // Form
      VStack(spacing: 14) {
        sectionLabel("GET BETA ACCESS")

        HStack(spacing: 12) {
          inputField("First Name", text: $firstName, contentType: .givenName)
          inputField("Last Name", text: $lastName, contentType: .familyName)
        }

        inputField("Email address", text: $email, keyboard: .emailAddress, contentType: .emailAddress)

        // Acknowledgement checkbox
        Button { withAnimation(.snappy) { termsAccepted.toggle() } } label: {
          HStack(alignment: .top, spacing: 12) {
            Image(systemName: termsAccepted ? "checkmark.square.fill" : "square")
              .font(.system(size: 22))
              .foregroundStyle(termsAccepted ? AppTheme.accentBlue : AppTheme.textMuted)
            Text("I understand this is a harm-reduction tool and not medical advice. I accept responsibility for my own safety and use.")
              .font(.system(size: 13))
              .foregroundStyle(AppTheme.textSecondary)
              .multilineTextAlignment(.leading)
              .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
          }
          .padding(14)
          .frame(maxWidth: .infinity)
          .background(AppTheme.backgroundCard)
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(termsAccepted ? AppTheme.accentBlue.opacity(0.5) : AppTheme.border, lineWidth: 0.75)
          )
        }
        .buttonStyle(.plain)

        // Submit
        Button { if canActivate { activate() } } label: {
          Text("Get Beta Access")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
              canActivate
                ? LinearGradient(colors: [AppTheme.proAmber, AppTheme.proOrange],
                                 startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [AppTheme.backgroundElevated, AppTheme.backgroundElevated],
                                 startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: canActivate ? AppTheme.proAmber.opacity(0.3) : .clear, radius: 10)
        }
        .disabled(!canActivate)
        .animation(.snappy, value: canActivate)
      }
      .padding(.horizontal, 20)
    }
    .frame(maxWidth: .infinity)
    .padding(.bottom, 20)
  }

  // MARK: - Shared feature list

  private func featureListSection(unlocked: Bool) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionLabel(unlocked ? "UNLOCKED FEATURES" : "WHAT YOU GET")
      VStack(spacing: 6) {
        featureRow("Full unlimited history",         "clock.arrow.circlepath", unlocked: unlocked)
        featureRow("Edit & correct dose records",    "pencil",                  unlocked: unlocked)
        featureRow("Export your data as CSV",        "square.and.arrow.up",     unlocked: unlocked)
        featureRow("Log missed/forgotten doses",     "xmark.circle",            unlocked: unlocked)
        featureRow("Profile & display name",         "person.crop.circle",      unlocked: unlocked)
        featureRow("Safe-to-redose notifications",   "bell.badge.fill",         unlocked: unlocked)
      }
    }
  }

  private func featureRow(_ text: String, _ icon: String, unlocked: Bool) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .foregroundStyle(unlocked ? AppTheme.proAmber : AppTheme.accentBlue)
        .frame(width: 22).font(.system(size: 15))
      Text(text).font(.system(size: 15)).foregroundStyle(AppTheme.textSecondary)
      Spacer()
      if unlocked {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(AppTheme.statusGreen).font(.system(size: 15))
      }
    }
    .padding(.horizontal, 14).padding(.vertical, 11)
    .background(AppTheme.backgroundCard)
    .clipShape(RoundedRectangle(cornerRadius: 11))
    .overlay(RoundedRectangle(cornerRadius: 11).stroke(AppTheme.border, lineWidth: 0.5))
  }

  private func inputField(
    _ placeholder: String,
    text: Binding<String>,
    keyboard: UIKeyboardType = .default,
    contentType: UITextContentType? = nil
  ) -> some View {
    TextField(placeholder, text: text)
      .keyboardType(keyboard)
      .textContentType(contentType)
      .autocorrectionDisabled()
      .font(.system(size: 16))
      .foregroundStyle(AppTheme.textPrimary)
      .padding(14)
      .background(AppTheme.backgroundCard)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 0.5))
  }

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(AppTheme.textMuted)
      .kerning(0.5)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func activate() {
    settings.proBetaAccepted = true
    if settings.vanityName.isEmpty { settings.vanityName = firstName }
  }

  private func isValidEmail(_ email: String) -> Bool {
    let t = email.trimmingCharacters(in: .whitespaces)
    return t.count > 5 && t.contains("@") && t.contains(".")
  }
}
