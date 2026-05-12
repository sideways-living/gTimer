import SwiftUI

struct HealthView: View {
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          disclaimer

          section(title: "Harm Reduction Basics", icon: "shield.fill", color: AppTheme.statusGreen) {
            bullets([
              "Always measure your dose accurately with a syringe or pipette — never guess.",
              "Start with a low dose (0.5–1 ml GHB) and wait for the full effect before redosing.",
              "Never mix GHB or GBL with alcohol, benzodiazepines, opioids, or other depressants.",
              "Do not use alone. Have a trusted person with you who knows what you've taken.",
              "Keep a record of every dose and time using this app.",
              "GBL is a prodrug — it converts to GHB in the body and is more potent by volume. Use lower doses.",
              "Tolerance develops quickly. After a break, treat yourself as a new user.",
              "Do not drive or operate machinery after dosing."
            ])
          }

          section(title: "Safe Intervals", icon: "timer", color: AppTheme.accentBlue) {
            VStack(alignment: .leading, spacing: 10) {
              Text("Redosing too soon dramatically increases the risk of overdose. The recommended minimum interval between doses is **90 minutes** — however individual factors (body weight, tolerance, purity) mean longer is safer.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
              infoRow("Never", "redose if you can't remember your last dose clearly.")
              infoRow("Never", "combine with alcohol or other CNS depressants.")
              infoRow("If in doubt,", "don't take more.")
            }
          }

          section(title: "Overdose Signs", icon: "exclamationmark.triangle.fill", color: AppTheme.statusAmber) {
            bullets([
              "Sudden extreme drowsiness or inability to stay awake",
              "Vomiting, particularly while unconscious",
              "Slow, shallow, or irregular breathing",
              "Unresponsive to voice or painful stimuli",
              "Muscle twitching or seizure-like movements",
              "Blue-tinged lips or fingertips (cyanosis)"
            ])
          }

          section(title: "Emergency Response", icon: "cross.fill", color: AppTheme.statusRed) {
            VStack(alignment: .leading, spacing: 10) {
              emergencyStep("1", "Call emergency services immediately (999/112/911).")
              emergencyStep("2", "Place the person in the recovery position (on their side).")
              emergencyStep("3", "Stay with them. Monitor breathing until help arrives.")
              emergencyStep("4", "Tell paramedics what was taken and when — this is not optional.")
              emergencyStep("5", "Do NOT leave them to 'sleep it off' unsupervised.")

              Text("There is no antidote to GHB/GBL overdose. Supportive medical care is the only treatment.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.statusRed)
                .padding(12)
                .background(AppTheme.statusRed.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.top, 4)
            }
          }

          section(title: "Dependency & Withdrawal", icon: "heart.slash.fill", color: AppTheme.proOrange) {
            VStack(alignment: .leading, spacing: 8) {
              Text("GHB/GBL can cause physical dependence with regular use. Withdrawal can be **life-threatening** and must be medically supervised.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
              bullets([
                "Symptoms include severe anxiety, tremors, insomnia, and seizures.",
                "Do not attempt to quit abruptly without medical support.",
                "Contact an addiction medicine specialist or call a drug helpline."
              ])
            }
          }

          section(title: "Support Resources", icon: "phone.fill", color: AppTheme.accentBlue) {
            VStack(alignment: .leading, spacing: 8) {
              resourceRow("UK Frank Helpline", "0300 123 6600")
              resourceRow("Narcotics Anonymous UK", "0300 999 1212")
              resourceRow("DAN 24/7 (Wales)", "0808 808 2234")
              resourceRow("SAMHSA (US)", "1-800-662-4357")
              resourceRow("Emergency (UK)", "999")
              resourceRow("Emergency (EU)", "112")
              resourceRow("Emergency (US)", "911")
            }
          }

          disclaimer
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
      }
      .background(AppTheme.backgroundPrimary)
      .navigationTitle("Health & Safety")
      .toolbarColorScheme(.dark, for: .navigationBar)
    }
    .preferredColorScheme(.dark)
  }

  private var disclaimer: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "exclamationmark.shield.fill")
        .foregroundStyle(AppTheme.statusAmber)
        .font(.system(size: 16))
        .padding(.top, 1)
      Text("This app provides harm-reduction information only. It is not medical advice. Always consult a healthcare professional. The developers accept no liability for decisions made based on this information.")
        .font(.system(size: 12))
        .foregroundStyle(AppTheme.textMuted)
    }
    .padding(12)
    .background(AppTheme.statusAmber.opacity(0.07))
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private func section<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: icon)
          .foregroundStyle(color)
          .font(.system(size: 15))
        Text(title)
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(AppTheme.textPrimary)
      }
      content()
    }
    .padding(16)
    .background(AppTheme.backgroundCard)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border, lineWidth: 0.5))
  }

  private func bullets(_ items: [String]) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      ForEach(items, id: \.self) { item in
        HStack(alignment: .top, spacing: 8) {
          Text("•")
            .foregroundStyle(AppTheme.textMuted)
            .font(.system(size: 14))
          Text(item)
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.textSecondary)
        }
      }
    }
  }

  private func infoRow(_ bold: String, _ rest: String) -> some View {
    Text("\(bold) ") + Text(rest).foregroundColor(AppTheme.textSecondary)
  }

  private func emergencyStep(_ num: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Text(num)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 22, height: 22)
        .background(AppTheme.statusRed)
        .clipShape(Circle())
      Text(text)
        .font(.system(size: 14))
        .foregroundStyle(AppTheme.textSecondary)
    }
  }

  private func resourceRow(_ name: String, _ number: String) -> some View {
    HStack {
      Text(name)
        .font(.system(size: 14))
        .foregroundStyle(AppTheme.textSecondary)
      Spacer()
      Text(number)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(AppTheme.accentBlue)
    }
  }
}
