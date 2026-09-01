import SwiftUI

private struct HealthSupportResource: Identifiable {
  let id = UUID()
  let name: String
  let detail: String
  let phone: String?
  let url: URL?
}

private struct HealthRegionInfo {
  let countryName: String
  let countryCodes: Set<String>
  let supportResources: [HealthSupportResource]
  let sourceResources: [HealthSupportResource]

  static func current(for locationCountryCode: String?) -> HealthRegionInfo {
    let code = locationCountryCode ?? Locale.current.region?.identifier
    return all.first { $0.countryCodes.contains((code ?? "").uppercased()) } ?? international
  }

  static let all: [HealthRegionInfo] = [
    HealthRegionInfo(
      countryName: "Australia",
      countryCodes: ["AU"],
      supportResources: [
        HealthSupportResource(name: "National Alcohol and Other Drug Hotline", detail: "Free, confidential support 24/7", phone: "1800 250 015", url: URL(string: "https://www.health.gov.au/contacts/national-alcohol-and-other-drug-hotline")),
        HealthSupportResource(name: "Poisons Information Centre", detail: "24-hour poisoning and overdose advice", phone: "13 11 26", url: URL(string: "https://www.poisonsinfo.nsw.gov.au/")),
        HealthSupportResource(name: "Healthdirect", detail: "Health advice from a nurse or doctor", phone: "1800 022 222", url: URL(string: "https://www.healthdirect.gov.au/ghb"))
      ],
      sourceResources: [
        HealthSupportResource(name: "Triple Zero", detail: "Emergency number guidance", phone: nil, url: URL(string: "https://www.infrastructure.gov.au/media-communications/phone/triple-zero")),
        HealthSupportResource(name: "Healthdirect GHB", detail: "Australian GHB health information", phone: nil, url: URL(string: "https://www.healthdirect.gov.au/ghb")),
        HealthSupportResource(name: "Alcohol and Drug Foundation", detail: "GHB harm-reduction information", phone: nil, url: URL(string: "https://adf.org.au/insights/hidden-harms-ghb/"))
      ]
    ),
    HealthRegionInfo(
      countryName: "New Zealand",
      countryCodes: ["NZ"],
      supportResources: [
        HealthSupportResource(name: "Alcohol Drug Helpline", detail: "24/7 trained counsellor support", phone: "0800 787 797", url: URL(string: "https://alcoholdrughelp.org.nz/")),
        HealthSupportResource(name: "National Poisons Centre", detail: "Free 24/7 poisons advice", phone: "0800 764 766", url: URL(string: "https://poisons.co.nz/")),
        HealthSupportResource(name: "Healthline", detail: "Non-emergency health advice", phone: "0800 611 116", url: URL(string: "https://www.stjohn.org.nz/what-we-do/st-john-ambulance-services/about-emergency-ambulance-services/what-happens-when-you-call-111/"))
      ],
      sourceResources: [
        HealthSupportResource(name: "New Zealand Police 111", detail: "Emergency number guidance", phone: nil, url: URL(string: "https://www.police.govt.nz/call-111")),
        HealthSupportResource(name: "NZ Drug Foundation", detail: "GHB/GBL harm-reduction information", phone: nil, url: URL(string: "https://drugfoundation.org.nz/drugs-a-z/ghbgbl")),
        HealthSupportResource(name: "National Poisons Centre", detail: "Poisons helpline information", phone: nil, url: URL(string: "https://poisons.co.nz/"))
      ]
    ),
    HealthRegionInfo(
      countryName: "United Kingdom",
      countryCodes: ["GB"],
      supportResources: [
        HealthSupportResource(name: "FRANK", detail: "Confidential drugs advice 24/7", phone: "0300 123 6600", url: URL(string: "https://talktofrank.com/contact-frank")),
        HealthSupportResource(name: "NHS 111", detail: "Urgent medical help when it is not life-threatening", phone: "111", url: URL(string: "https://www.nhs.uk/nhs-services/urgent-and-emergency-care-services/when-to-use-111/")),
        HealthSupportResource(name: "NPIS public advice", detail: "Poisons guidance via NHS 111/NHS 24", phone: "111", url: URL(string: "https://www.npis.org/"))
      ],
      sourceResources: [
        HealthSupportResource(name: "NHS 999", detail: "Emergency number guidance", phone: nil, url: URL(string: "https://www.nhs.uk/nhs-services/urgent-and-emergency-care-services/when-to-call-999/")),
        HealthSupportResource(name: "FRANK GHB & GBL", detail: "UK drug information", phone: nil, url: URL(string: "https://talktofrank.com/drug/ghb")),
        HealthSupportResource(name: "FRANK contact", detail: "UK drugs helpline information", phone: nil, url: URL(string: "https://talktofrank.com/contact-frank"))
      ]
    ),
    HealthRegionInfo(
      countryName: "Ireland",
      countryCodes: ["IE"],
      supportResources: [
        HealthSupportResource(name: "HSE Drugs & Alcohol Helpline", detail: "Confidential national support", phone: "1800 459 459", url: URL(string: "https://www.drugs.ie/phone")),
        HealthSupportResource(name: "Poisons Information Line", detail: "Public poisons advice", phone: "01 809 2166", url: URL(string: "https://poisons.ie/")),
        HealthSupportResource(name: "HSE emergency care", detail: "Emergency medical guidance", phone: "112", url: URL(string: "https://www2.hse.ie/emergencies/when-to-call-112-or-999/"))
      ],
      sourceResources: [
        HealthSupportResource(name: "HSE 112/999", detail: "Emergency number guidance", phone: nil, url: URL(string: "https://www2.hse.ie/emergencies/when-to-call-112-or-999/")),
        HealthSupportResource(name: "Drugs.ie GHB", detail: "Irish GHB risk-reduction information", phone: nil, url: URL(string: "https://www.drugs.ie/ghb_information_and_risk_reduction/")),
        HealthSupportResource(name: "National Poisons Information Centre", detail: "Irish poisons helpline information", phone: nil, url: URL(string: "https://poisons.ie/"))
      ]
    ),
    HealthRegionInfo(
      countryName: "United States",
      countryCodes: ["US"],
      supportResources: [
        HealthSupportResource(name: "SAMHSA National Helpline", detail: "Free, confidential treatment referral 24/7", phone: "1-800-662-4357", url: URL(string: "https://www.samhsa.gov/find-help/helplines/national-helpline")),
        HealthSupportResource(name: "Poison Help", detail: "Free expert poison advice 24/7", phone: "1-800-222-1222", url: URL(string: "https://poisonhelp.hrsa.gov/poison-centers/find-poison-center")),
        HealthSupportResource(name: "988 Lifeline", detail: "Mental health or suicide crisis support", phone: "988", url: URL(string: "https://988lifeline.org/"))
      ],
      sourceResources: [
        HealthSupportResource(name: "911.gov", detail: "US emergency number guidance", phone: nil, url: URL(string: "https://www.911.gov/")),
        HealthSupportResource(name: "SAMHSA", detail: "US substance-use helpline", phone: nil, url: URL(string: "https://www.samhsa.gov/find-help/helplines/national-helpline")),
        HealthSupportResource(name: "Poison Help", detail: "US poison centre information", phone: nil, url: URL(string: "https://poisonhelp.hrsa.gov/poison-centers/find-poison-center"))
      ]
    ),
    HealthRegionInfo(
      countryName: "Canada",
      countryCodes: ["CA"],
      supportResources: [
        HealthSupportResource(name: "National Overdose Response Service", detail: "Confidential overdose-prevention support", phone: "1-888-688-6677", url: URL(string: "https://www.canada.ca/en/health-canada/services/substance-use/get-help-with-substance-use.html")),
        HealthSupportResource(name: "Poison centres", detail: "Toll-free local poison centre access", phone: "1-844-764-7669", url: URL(string: "https://www.canada.ca/en/health-canada/news/2023/03/canada-launches-new-toll-free-1-844-poison-x-number-for-poison-centres.html")),
        HealthSupportResource(name: "Wellness Together Canada", detail: "Mental health and substance-use support", phone: "1-866-585-0445", url: URL(string: "https://www.canada.ca/en/health-canada/services/substance-use/get-help-with-substance-use.html"))
      ],
      sourceResources: [
        HealthSupportResource(name: "Health Canada GHB", detail: "Canadian GHB information", phone: nil, url: URL(string: "https://www.canada.ca/en/health-canada/services/substance-use/controlled-illegal-drugs/ghb.html")),
        HealthSupportResource(name: "Health Canada support", detail: "Substance-use help resources", phone: nil, url: URL(string: "https://www.canada.ca/en/health-canada/services/substance-use/get-help-with-substance-use.html")),
        HealthSupportResource(name: "Poison centres", detail: "Canadian poison centre access", phone: nil, url: URL(string: "https://www.canada.ca/en/health-canada/news/2023/03/canada-launches-new-toll-free-1-844-poison-x-number-for-poison-centres.html"))
      ]
    ),
    HealthRegionInfo(
      countryName: "South Africa",
      countryCodes: ["ZA"],
      supportResources: [
        HealthSupportResource(name: "Substance Abuse Helpline", detail: "Department of Social Development/SADAG 24-hour support", phone: "0800 12 13 14", url: URL(string: "https://www.gov.za/Alcoholandsubstanceabuse")),
        HealthSupportResource(name: "Ambulance", detail: "Medical emergency from landline or mobile", phone: "10177", url: URL(string: "https://www.westerncape.gov.za/know-who-you-can-call-emergency")),
        HealthSupportResource(name: "Poisons Information Helpline", detail: "24-hour poison information", phone: "0861 555 777", url: URL(string: "https://health.uct.ac.za/department-paediatrics/clinical-services-medical-services/poisons-information-centre"))
      ],
      sourceResources: [
        HealthSupportResource(name: "Western Cape Government", detail: "South African emergency numbers", phone: nil, url: URL(string: "https://www.westerncape.gov.za/know-who-you-can-call-emergency")),
        HealthSupportResource(name: "South African Government", detail: "Substance abuse support", phone: nil, url: URL(string: "https://www.gov.za/Alcoholandsubstanceabuse")),
        HealthSupportResource(name: "UCT Poisons Information Centre", detail: "Poison helpline information", phone: nil, url: URL(string: "https://health.uct.ac.za/department-paediatrics/clinical-services-medical-services/poisons-information-centre"))
      ]
    )
  ]

  static let international = HealthRegionInfo(
    countryName: "your region",
    countryCodes: [],
    supportResources: [
      HealthSupportResource(name: "Local emergency services", detail: "Use the emergency number for your current country", phone: "112", url: nil),
      HealthSupportResource(name: "Local poison centre", detail: "Search your national health service or poison centre", phone: nil, url: nil),
      HealthSupportResource(name: "Local drug and alcohol service", detail: "Use your national public health or addiction service", phone: nil, url: nil)
    ],
    sourceResources: [
      HealthSupportResource(name: "Alcohol and Drug Foundation", detail: "GHB harm-reduction information", phone: nil, url: URL(string: "https://adf.org.au/insights/hidden-harms-ghb/")),
      HealthSupportResource(name: "Health Canada GHB", detail: "GHB health information", phone: nil, url: URL(string: "https://www.canada.ca/en/health-canada/services/substance-use/controlled-illegal-drugs/ghb.html")),
      HealthSupportResource(name: "FRANK GHB & GBL", detail: "Drug information", phone: nil, url: URL(string: "https://talktofrank.com/drug/ghb"))
    ]
  )
}

struct HealthView: View {
  @Environment(\.openURL) private var openURL
  @Environment(SettingsManager.self) private var settings
  @State private var locationManager = LocationManager.shared

  private var selectedCountryCode: String? {
    if !settings.homeCountryCode.isEmpty { return settings.homeCountryCode }
    return locationManager.countryCode ?? Locale.current.region?.identifier
  }

  private var regionInfo: HealthRegionInfo {
    HealthRegionInfo.current(for: selectedCountryCode)
  }

  private var emergencyNumbers: [String] {
    EmergencyNumberCatalogue.preferredEmergencyNumbers(for: selectedCountryCode)
  }

  private var emergencyLabel: String {
    EmergencyNumberCatalogue.emergencyLabel(for: selectedCountryCode)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          disclaimer

          section(title: "Harm Reduction Basics", icon: "shield.fill", color: AppTheme.statusGreen) {
            bullets([
              "Always measure your dose accurately with a syringe or pipette — never guess.",
              "The difference between an expected effect and an overdose can be small, especially with unknown strength.",
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
              infoRow("Never", rest: "redose if you can't remember your last dose clearly.")
              infoRow("Never", rest: "combine with alcohol or other CNS depressants.")
              infoRow("If in doubt,", rest: "don't take more.")
            }
          }

          section(title: "Call Emergency Services If…", icon: "phone.fill", color: AppTheme.statusRed) {
            VStack(alignment: .leading, spacing: 8) {
              urgentTrigger("Person cannot be woken or is unconscious")
              urgentTrigger("Breathing is slow, shallow, or irregular")
              urgentTrigger("Lips or fingertips are turning blue (cyanosis)")
              urgentTrigger("GHB/GBL was mixed with alcohol, benzodiazepines, or opioids")
              urgentTrigger("Vomiting while not fully conscious")
              urgentTrigger("Seizure or muscle twitching")
              urgentTrigger("You are unsure — always call if in doubt")

              Button {
                if let phone = emergencyNumbers.first {
                  openPhone(phone)
                }
              } label: {
                Text(emergencyLabel)
                  .font(.system(size: 16, weight: .bold))
                  .foregroundStyle(.white)
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 13)
                  .background(AppTheme.statusRed)
                  .clipShape(RoundedRectangle(cornerRadius: 10))
              }
              .accessibilityLabel("Call emergency services")
              .padding(.top, 6)
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

          section(title: "Emergency Response Steps", icon: "cross.fill", color: AppTheme.statusRed) {
            VStack(alignment: .leading, spacing: 10) {
              emergencyStep("1", "Call emergency services immediately: \(emergencyLabel).")
              emergencyStep("2", "Place the person in the recovery position (on their side).")
              emergencyStep("3", "Stay with them and monitor breathing continuously.")
              emergencyStep("4", "Tell paramedics exactly what was taken and when.")
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

          section(title: "Support Resources — \(regionInfo.countryName)", icon: "phone.fill", color: AppTheme.accentBlue) {
            VStack(alignment: .leading, spacing: 8) {
              ForEach(regionInfo.supportResources) { resource in
                resourceRow(resource)
              }
            }
          }

          section(title: "Sources", icon: "link", color: AppTheme.textMuted) {
            VStack(alignment: .leading, spacing: 8) {
              ForEach(regionInfo.sourceResources) { resource in
                resourceRow(resource)
              }
            }
          }

          disclaimer
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
      }
      .tabBarScrollClearance()
      .background(AppTheme.backgroundPrimary.ignoresSafeArea())
      .navigationTitle("Health & Safety")
      .platformNavigationBarStyle()
    }
    .background(AppTheme.backgroundPrimary.ignoresSafeArea())
  }

  // MARK: - Components

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
        Image(systemName: icon).foregroundStyle(color).font(.system(size: 15))
        Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(AppTheme.textPrimary)
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
          Text("•").foregroundStyle(AppTheme.textMuted).font(.system(size: 14))
          Text(item).font(.system(size: 14)).foregroundStyle(AppTheme.textSecondary)
        }
      }
    }
  }

  private func infoRow(_ bold: String, rest: String) -> some View {
    HStack(alignment: .top, spacing: 4) {
      Text(bold).font(.system(size: 14, weight: .semibold)).foregroundStyle(AppTheme.textPrimary)
      Text(rest).font(.system(size: 14)).foregroundStyle(AppTheme.textSecondary)
    }
  }

  private func urgentTrigger(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "exclamationmark.circle.fill")
        .foregroundStyle(AppTheme.statusRed).font(.system(size: 13)).padding(.top, 1)
      Text(text).font(.system(size: 14, weight: .medium)).foregroundStyle(AppTheme.textPrimary)
    }
  }

  private func emergencyStep(_ num: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Text(num)
        .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
        .frame(width: 22, height: 22).background(AppTheme.statusRed).clipShape(Circle())
      Text(text).font(.system(size: 14)).foregroundStyle(AppTheme.textSecondary)
    }
  }

  private func resourceRow(_ resource: HealthSupportResource) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(resource.name).font(.system(size: 14)).foregroundStyle(AppTheme.textSecondary)
        Text(resource.detail).font(.system(size: 11)).foregroundStyle(AppTheme.textMuted)
      }
      Spacer()
      if let phone = resource.phone {
        Button {
          openPhone(phone)
        } label: {
          Text(phone).font(.system(size: 14, weight: .semibold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.accentBlue)
      }
      if let url = resource.url {
        Button {
          openURL(url)
        } label: {
          Image(systemName: "safari")
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.accentBlue)
        .accessibilityLabel("Open \(resource.name)")
      }
    }
  }

  private func openPhone(_ phone: String) {
    let allowed = Set("+0123456789")
    let cleaned = String(phone.filter { allowed.contains($0) })
    guard !cleaned.isEmpty, let url = URL(string: "tel://\(cleaned)") else { return }
    openURL(url)
  }
}
