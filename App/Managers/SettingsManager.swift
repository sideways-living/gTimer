import SwiftUI
import PhotosUI
import WidgetKit
#if os(iOS)
import UIKit
#endif

enum AppAppearanceMode: String, CaseIterable, Identifiable {
  case auto
  case day
  case night

  var id: String { rawValue }

  var title: String {
    switch self {
    case .auto: "Auto"
    case .day: "Day"
    case .night: "Night"
    }
  }

  var preferredColorScheme: ColorScheme? {
    switch self {
    case .auto: nil
    case .day: .light
    case .night: .dark
    }
  }
}

struct EmergencyCountry: Identifiable, Hashable {
  let code: String
  let name: String
  let numbers: [String]

  var id: String { code }
}

enum EmergencyNumberCatalogue {
  static let countries: [EmergencyCountry] = [
    EmergencyCountry(code: "AD", name: "Andorra", numbers: ["110", "112", "116", "118"]),
    EmergencyCountry(code: "AE", name: "United Arab Emirates", numbers: ["112", "911", "991", "992", "997", "998", "999"]),
    EmergencyCountry(code: "AG", name: "Antigua & Barbuda", numbers: ["911", "999"]),
    EmergencyCountry(code: "AI", name: "Anguilla", numbers: ["911"]),
    EmergencyCountry(code: "AL", name: "Albania", numbers: ["112", "126", "127", "128", "129"]),
    EmergencyCountry(code: "AM", name: "Armenia", numbers: ["911", "100", "101", "102", "103", "104", "177"]),
    EmergencyCountry(code: "AO", name: "Angola", numbers: ["111", "115", "116"]),
    EmergencyCountry(code: "AR", name: "Argentina", numbers: ["109", "911", "100", "101", "106", "107", "128"]),
    EmergencyCountry(code: "AS", name: "American Samoa", numbers: ["911"]),
    EmergencyCountry(code: "AT", name: "Austria", numbers: ["112", "122", "128", "133", "140", "141", "142", "144", "147"]),
    EmergencyCountry(code: "AU", name: "Australia", numbers: ["000", "106", "132500"]),
    EmergencyCountry(code: "AX", name: "Aland Islands", numbers: ["112"]),
    EmergencyCountry(code: "AZ", name: "Azerbaijan", numbers: ["112", "101", "102", "103", "104", "199"]),
    EmergencyCountry(code: "BA", name: "Bosnia & Herzegovina", numbers: ["121", "122", "123", "124", "1282"]),
    EmergencyCountry(code: "BB", name: "Barbados", numbers: ["911", "211", "311", "511"]),
    EmergencyCountry(code: "BD", name: "Bangladesh", numbers: ["999", "16163"]),
    EmergencyCountry(code: "BE", name: "Belgium", numbers: ["100", "101", "102", "103", "105", "106", "107", "108", "110", "112", "117", "119"]),
    EmergencyCountry(code: "BF", name: "Burkina Faso", numbers: ["15", "16", "17", "18", "112", "199", "1010", "1111", "1130"]),
    EmergencyCountry(code: "BG", name: "Bulgaria", numbers: ["112", "166", "150", "160"]),
    EmergencyCountry(code: "BH", name: "Bahrain", numbers: ["112", "199", "990", "992", "994", "999"]),
    EmergencyCountry(code: "BI", name: "Burundi", numbers: ["113", "413"]),
    EmergencyCountry(code: "BJ", name: "Benin", numbers: ["112", "117", "118"]),
    EmergencyCountry(code: "BL", name: "Saint Barthélemy", numbers: ["112", "15", "17", "18"]),
    EmergencyCountry(code: "BM", name: "Bermuda", numbers: ["911"]),
    EmergencyCountry(code: "BN", name: "Brunei Darussalam", numbers: ["991", "993", "995", "998"]),
    EmergencyCountry(code: "BO", name: "Bolivia", numbers: ["110", "111", "115", "119", "156", "160", "176"]),
    EmergencyCountry(code: "BR", name: "Brazil", numbers: ["128", "180", "185", "190", "191", "192", "193", "194", "197", "198"]),
    EmergencyCountry(code: "BS", name: "Bahamas", numbers: ["911", "919"]),
    EmergencyCountry(code: "BT", name: "Bhutan", numbers: ["113", "110", "112", "999"]),
    EmergencyCountry(code: "BV", name: "Bouvet Island", numbers: []),
    EmergencyCountry(code: "BW", name: "Botswana", numbers: ["112", "116", "991", "997", "998", "999"]),
    EmergencyCountry(code: "BY", name: "Belarus", numbers: ["112", "101", "102", "103", "104"]),
    EmergencyCountry(code: "BZ", name: "Belize", numbers: ["911", "990", "936"]),
    EmergencyCountry(code: "CA", name: "Canada", numbers: ["911"]),
    EmergencyCountry(code: "CC", name: "Cocos Islands", numbers: ["000"]),
    EmergencyCountry(code: "CF", name: "Central African Republic", numbers: ["114", "117", "118"]),
    EmergencyCountry(code: "CG", name: "Congo", numbers: ["112"]),
    EmergencyCountry(code: "CH", name: "Switzerland", numbers: ["112", "117", "118", "143", "144", "147", "145", "1414"]),
    EmergencyCountry(code: "CI", name: "Côte d'Ivoire", numbers: ["100", "110", "111", "170", "180", "185", "145"]),
    EmergencyCountry(code: "CK", name: "Cook Islands", numbers: ["999", "996", "22664", "22499"]),
    EmergencyCountry(code: "CL", name: "Chile", numbers: ["130", "131", "132", "133", "134", "135", "136", "137", "138", "1400"]),
    EmergencyCountry(code: "CM", name: "Cameroon", numbers: ["117", "118", "119"]),
    EmergencyCountry(code: "CN", name: "China", numbers: ["110", "119", "120", "122"]),
    EmergencyCountry(code: "CO", name: "Colombia", numbers: ["123", "111", "112", "119", "125", "146", "156"]),
    EmergencyCountry(code: "CR", name: "Costa Rica", numbers: ["911", "112", "1117", "1118"]),
    EmergencyCountry(code: "CV", name: "Cabo Verde", numbers: ["112"]),
    EmergencyCountry(code: "CX", name: "Christmas Island", numbers: ["000"]),
    EmergencyCountry(code: "CY", name: "Cyprus", numbers: ["112", "199"]),
    EmergencyCountry(code: "CZ", name: "Czech Republic", numbers: ["112", "150", "155", "156", "158"]),
    EmergencyCountry(code: "DE", name: "Germany", numbers: ["110", "112"]),
    EmergencyCountry(code: "DJ", name: "Djibouti", numbers: ["17", "18", "19"]),
    EmergencyCountry(code: "DK", name: "Denmark", numbers: ["112", "114"]),
    EmergencyCountry(code: "DM", name: "Dominica", numbers: ["911"]),
    EmergencyCountry(code: "DO", name: "Dominican Republic", numbers: ["911"]),
    EmergencyCountry(code: "DZ", name: "Algeria", numbers: ["1021", "104", "1055", "1548"]),
    EmergencyCountry(code: "EC", name: "Ecuador", numbers: ["911"]),
    EmergencyCountry(code: "EE", name: "Estonia", numbers: ["112"]),
    EmergencyCountry(code: "EG", name: "Egypt", numbers: ["122", "123", "180"]),
    EmergencyCountry(code: "EH", name: "Western Sahara", numbers: ["15", "19", "177"]),
    EmergencyCountry(code: "ES", name: "Spain", numbers: ["061", "062", "080", "085", "091", "092", "112"]),
    EmergencyCountry(code: "ET", name: "Ethiopia", numbers: ["911", "112", "907", "939", "991"]),
    EmergencyCountry(code: "FI", name: "Finland", numbers: ["112"]),
    EmergencyCountry(code: "FJ", name: "Fiji", numbers: ["911", "910", "913", "915", "917", "919"]),
    EmergencyCountry(code: "FO", name: "Faroe Islands", numbers: ["112", "114"]),
    EmergencyCountry(code: "FR", name: "France", numbers: ["112", "115", "116000", "119", "15", "17", "18"]),
    EmergencyCountry(code: "GA", name: "Gabon", numbers: ["112", "177", "1333", "1488"]),
    EmergencyCountry(code: "GB", name: "United Kingdom", numbers: ["999", "112", "18000"]),
    EmergencyCountry(code: "GD", name: "Grenada", numbers: ["911", "399", "434", "677", "724", "774"]),
    EmergencyCountry(code: "GE", name: "Georgia", numbers: ["112", "111", "114", "123", "125", "144"]),
    EmergencyCountry(code: "GF", name: "French Guiana", numbers: ["112", "15", "17", "18", "196"]),
    EmergencyCountry(code: "GG", name: "Guernsey", numbers: ["999"]),
    EmergencyCountry(code: "GH", name: "Ghana", numbers: ["112", "116", "190", "191", "192", "193"]),
    EmergencyCountry(code: "GI", name: "Gibraltar", numbers: ["999"]),
    EmergencyCountry(code: "GL", name: "Greenland", numbers: ["112", "113", "114"]),
    EmergencyCountry(code: "GM", name: "Gambia", numbers: ["112", "116", "117", "118"]),
    EmergencyCountry(code: "GN", name: "Guinea", numbers: ["18", "19", "115", "117"]),
    EmergencyCountry(code: "GP", name: "Guadeloupe", numbers: ["112", "15", "17", "18", "114", "196"]),
    EmergencyCountry(code: "GQ", name: "Equatorial Guinea", numbers: ["112", "113", "114", "115", "116"]),
    EmergencyCountry(code: "GR", name: "Greece", numbers: ["112", "100", "166", "199", "108", "197", "11112"]),
    EmergencyCountry(code: "GT", name: "Guatemala", numbers: ["110", "122", "123", "1554"]),
    EmergencyCountry(code: "GU", name: "Guam", numbers: ["911"]),
    EmergencyCountry(code: "GW", name: "Guinea-Bissau", numbers: ["121", "118", "119"]),
    EmergencyCountry(code: "HK", name: "Hong Kong SAR", numbers: ["999"]),
    EmergencyCountry(code: "HM", name: "Heard Island & McDonald Islands", numbers: []),
    EmergencyCountry(code: "HN", name: "Honduras", numbers: ["911", "198", "100"]),
    EmergencyCountry(code: "HR", name: "Croatia", numbers: ["192", "193", "194", "195", "1987", "116000", "116006", "116111", "112"]),
    EmergencyCountry(code: "HT", name: "Haiti", numbers: ["114", "116", "122"]),
    EmergencyCountry(code: "HU", name: "Hungary", numbers: ["104", "105", "107", "112"]),
    EmergencyCountry(code: "ID", name: "Indonesia", numbers: ["112", "110", "119", "113"]),
    EmergencyCountry(code: "IE", name: "Ireland", numbers: ["999", "112"]),
    EmergencyCountry(code: "IL", name: "Israel", numbers: ["100", "101", "102", "104", "105"]),
    EmergencyCountry(code: "IM", name: "Isle of Man", numbers: ["999"]),
    EmergencyCountry(code: "IN", name: "India", numbers: ["112", "100", "101", "102"]),
    EmergencyCountry(code: "IQ", name: "Iraq", numbers: ["104", "115", "122"]),
    EmergencyCountry(code: "IS", name: "Iceland", numbers: ["112"]),
    EmergencyCountry(code: "IT", name: "Italy", numbers: ["112", "113", "114", "115", "118"]),
    EmergencyCountry(code: "JE", name: "Jersey", numbers: ["999"]),
    EmergencyCountry(code: "JM", name: "Jamaica", numbers: ["110", "112", "119"]),
    EmergencyCountry(code: "JO", name: "Jordan", numbers: ["911", "191", "193", "199"]),
    EmergencyCountry(code: "JP", name: "Japan", numbers: ["110", "119", "118"]),
    EmergencyCountry(code: "KE", name: "Kenya", numbers: ["109", "112", "999", "114", "117", "110"]),
    EmergencyCountry(code: "KG", name: "Kyrgyzstan", numbers: ["112", "101", "102", "103", "161"]),
    EmergencyCountry(code: "KH", name: "Cambodia", numbers: ["117", "118", "119", "666"]),
    EmergencyCountry(code: "KM", name: "Comoros", numbers: ["111", "112", "113", "115", "117", "118"]),
    EmergencyCountry(code: "KR", name: "South Korea", numbers: ["112", "119", "122"]),
    EmergencyCountry(code: "KW", name: "Kuwait", numbers: ["112", "152"]),
    EmergencyCountry(code: "KY", name: "Cayman Islands", numbers: ["911"]),
    EmergencyCountry(code: "KZ", name: "Kazakhstan", numbers: ["103", "112"]),
    EmergencyCountry(code: "LA", name: "Lao People's Democratic Republic (the)", numbers: ["1191", "1169", "1190", "1192", "1195", "1199"]),
    EmergencyCountry(code: "LB", name: "Lebanon", numbers: ["112", "125", "140", "175"]),
    EmergencyCountry(code: "LC", name: "St. Lucia", numbers: ["911", "999"]),
    EmergencyCountry(code: "LI", name: "Liechtenstein", numbers: ["112", "117", "118", "143", "144", "147", "145", "1414"]),
    EmergencyCountry(code: "LK", name: "Sri Lanka", numbers: ["110", "112", "119"]),
    EmergencyCountry(code: "LR", name: "Liberia", numbers: ["911", "144", "4455"]),
    EmergencyCountry(code: "LS", name: "Lesotho", numbers: ["112"]),
    EmergencyCountry(code: "LT", name: "Lithuania", numbers: ["112"]),
    EmergencyCountry(code: "LU", name: "Luxembourg", numbers: ["112", "113"]),
    EmergencyCountry(code: "LV", name: "Latvia", numbers: ["110", "113", "114", "115", "116006", "116123", "116000", "116111", "112"]),
    EmergencyCountry(code: "LY", name: "Libya", numbers: ["1415", "112", "193", "1515"]),
    EmergencyCountry(code: "MA", name: "Morocco", numbers: ["15", "19", "177"]),
    EmergencyCountry(code: "MC", name: "Monaco", numbers: ["112", "17", "18", "196"]),
    EmergencyCountry(code: "MD", name: "Moldova", numbers: ["112"]),
    EmergencyCountry(code: "ME", name: "Montenegro", numbers: ["112", "122", "123", "124", "129"]),
    EmergencyCountry(code: "MF", name: "Saint Martin", numbers: ["112", "15", "17", "18"]),
    EmergencyCountry(code: "MG", name: "Madagascar", numbers: ["17", "117", "118"]),
    EmergencyCountry(code: "MK", name: "North Macedonia", numbers: ["112", "192", "193", "194"]),
    EmergencyCountry(code: "MN", name: "Mongolia", numbers: ["101", "102", "103"]),
    EmergencyCountry(code: "MP", name: "Northern Mariana Islands", numbers: ["911"]),
    EmergencyCountry(code: "MQ", name: "Martinique", numbers: ["112", "15", "17", "18", "114", "191", "196"]),
    EmergencyCountry(code: "MR", name: "Mauritania", numbers: ["101", "117", "118"]),
    EmergencyCountry(code: "MT", name: "Malta", numbers: ["112"]),
    EmergencyCountry(code: "MU", name: "Mauritius", numbers: ["112", "999", "114", "115"]),
    EmergencyCountry(code: "MV", name: "Maldives", numbers: ["102", "104", "105", "115", "118", "119", "191"]),
    EmergencyCountry(code: "MW", name: "Malawi", numbers: ["997", "490", "491", "990", "998", "999", "4312"]),
    EmergencyCountry(code: "MX", name: "Mexico", numbers: ["911"]),
    EmergencyCountry(code: "MY", name: "Malaysia", numbers: ["999", "112"]),
    EmergencyCountry(code: "MZ", name: "Mozambique", numbers: ["117", "119", "198"]),
    EmergencyCountry(code: "NA", name: "Namibia", numbers: ["112", "924", "998", "9682", "10111"]),
    EmergencyCountry(code: "NE", name: "Niger", numbers: ["15", "118", "17", "8383", "18"]),
    EmergencyCountry(code: "NF", name: "Norfolk Island", numbers: ["000"]),
    EmergencyCountry(code: "NG", name: "Nigeria", numbers: ["112"]),
    EmergencyCountry(code: "NI", name: "Nicaragua", numbers: ["102", "115", "118"]),
    EmergencyCountry(code: "NL", name: "Netherlands", numbers: ["112"]),
    EmergencyCountry(code: "NO", name: "Norway", numbers: ["110", "112", "113"]),
    EmergencyCountry(code: "NP", name: "Nepal", numbers: ["100", "101", "102", "103", "104"]),
    EmergencyCountry(code: "NZ", name: "New Zealand", numbers: ["111"]),
    EmergencyCountry(code: "OM", name: "Oman", numbers: ["9999", "112"]),
    EmergencyCountry(code: "PA", name: "Panama", numbers: ["911", "103", "104"]),
    EmergencyCountry(code: "PE", name: "Peru", numbers: ["105", "106", "110", "115", "116"]),
    EmergencyCountry(code: "PG", name: "Papua New Guinea", numbers: ["110", "111", "112"]),
    EmergencyCountry(code: "PH", name: "Philippines", numbers: ["911"]),
    EmergencyCountry(code: "PK", name: "Pakistan", numbers: ["15", "16", "115", "130", "1122"]),
    EmergencyCountry(code: "PL", name: "Poland", numbers: ["984", "985", "986", "987", "989", "991", "992", "993", "994", "995", "996", "997", "998", "999", "112"]),
    EmergencyCountry(code: "PR", name: "Puerto Rico", numbers: ["911"]),
    EmergencyCountry(code: "PS", name: "Palestine", numbers: ["100", "101", "177"]),
    EmergencyCountry(code: "PT", name: "Portugal", numbers: ["112", "117"]),
    EmergencyCountry(code: "PY", name: "Paraguay", numbers: ["911"]),
    EmergencyCountry(code: "QA", name: "Qatar", numbers: ["999"]),
    EmergencyCountry(code: "RE", name: "Reunion", numbers: ["112", "15", "17", "18", "196"]),
    EmergencyCountry(code: "RO", name: "Romania", numbers: ["112", "113"]),
    EmergencyCountry(code: "RS", name: "Serbia", numbers: ["112", "192", "193", "194"]),
    EmergencyCountry(code: "RU", name: "Russia", numbers: ["112", "101", "102", "103", "104"]),
    EmergencyCountry(code: "RW", name: "Rwanda", numbers: ["112", "110", "113", "912"]),
    EmergencyCountry(code: "SA", name: "Saudi Arabia", numbers: ["911", "112", "123", "992", "993", "996", "997", "998", "999"]),
    EmergencyCountry(code: "SC", name: "Seychelles", numbers: ["112", "111", "133", "141", "151", "160", "999"]),
    EmergencyCountry(code: "SD", name: "Sudan", numbers: ["333", "777", "999"]),
    EmergencyCountry(code: "SE", name: "Sweden", numbers: ["112", "11313", "11414", "1177"]),
    EmergencyCountry(code: "SG", name: "Singapore", numbers: ["993", "995", "999"]),
    EmergencyCountry(code: "SI", name: "Slovenia", numbers: ["113", "116000", "116111", "116123", "112"]),
    EmergencyCountry(code: "SJ", name: "Svalbard", numbers: ["112"]),
    EmergencyCountry(code: "SK", name: "Slovakia", numbers: ["112", "150", "155", "158"]),
    EmergencyCountry(code: "SN", name: "Senegal", numbers: ["17", "18", "123", "1515"]),
    EmergencyCountry(code: "SO", name: "Somalia", numbers: ["555", "777", "888", "999"]),
    EmergencyCountry(code: "ST", name: "São Tomé e Príncipe", numbers: ["112", "113"]),
    EmergencyCountry(code: "SV", name: "El Salvador", numbers: ["911", "913", "132"]),
    EmergencyCountry(code: "SX", name: "Sint Maarten", numbers: ["911", "912", "913", "919"]),
    EmergencyCountry(code: "SZ", name: "Eswatini", numbers: ["999", "933", "977"]),
    EmergencyCountry(code: "TC", name: "Turks & Caicos Islands", numbers: ["911"]),
    EmergencyCountry(code: "TD", name: "Chad", numbers: ["114", "115"]),
    EmergencyCountry(code: "TG", name: "Togo", numbers: ["117", "118", "9200"]),
    EmergencyCountry(code: "TH", name: "Thailand", numbers: ["191", "1669", "199"]),
    EmergencyCountry(code: "TJ", name: "Tajikistan", numbers: ["112", "101", "102", "103", "104"]),
    EmergencyCountry(code: "TL", name: "Timor-Leste", numbers: ["112"]),
    EmergencyCountry(code: "TM", name: "Turkmenistan", numbers: ["001", "002", "003", "004", "009"]),
    EmergencyCountry(code: "TN", name: "Tunisia", numbers: ["190", "193", "194", "197", "198"]),
    EmergencyCountry(code: "TR", name: "Türkiye", numbers: ["112", "132", "156", "158", "177"]),
    EmergencyCountry(code: "TT", name: "Trinidad & Tobago", numbers: ["911", "811", "990", "999"]),
    EmergencyCountry(code: "TW", name: "Taiwan", numbers: ["112", "110", "119"]),
    EmergencyCountry(code: "TZ", name: "Tanzania", numbers: ["110", "111", "112", "113", "114", "115"]),
    EmergencyCountry(code: "UA", name: "Ukraine", numbers: ["112"]),
    EmergencyCountry(code: "UG", name: "Uganda", numbers: ["999", "112"]),
    EmergencyCountry(code: "UM", name: "United States Minor Outlying Islands", numbers: ["911"]),
    EmergencyCountry(code: "US", name: "United States", numbers: ["911"]),
    EmergencyCountry(code: "UY", name: "Uruguay", numbers: ["911", "104", "105", "106", "108", "112", "128"]),
    EmergencyCountry(code: "UZ", name: "Uzbekistan", numbers: ["112", "101", "102", "103"]),
    EmergencyCountry(code: "VC", name: "St. Vincent and the Grenadines", numbers: ["999", "911"]),
    EmergencyCountry(code: "VE", name: "Venezuela", numbers: ["911"]),
    EmergencyCountry(code: "VI", name: "United States Virgin Islands", numbers: ["911"]),
    EmergencyCountry(code: "VN", name: "VietNam", numbers: ["113", "114", "115"]),
    EmergencyCountry(code: "YT", name: "Mayotte", numbers: ["112", "15", "17", "18", "114", "191", "196"]),
    EmergencyCountry(code: "ZA", name: "South Africa", numbers: ["10111", "10177", "112", "116", "107", "17737", "1020"]),
    EmergencyCountry(code: "ZM", name: "Zambia", numbers: ["999", "991", "993"]),
    EmergencyCountry(code: "ZW", name: "Zimbabwe", numbers: []),
  ].sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

  static func country(for code: String?) -> EmergencyCountry? {
    guard let code, !code.isEmpty else { return nil }
    return countries.first { $0.code.caseInsensitiveCompare(code) == .orderedSame }
  }

  static func emergencyNumbers(for code: String?) -> [String] {
    country(for: code)?.numbers ?? []
  }

  static func preferredEmergencyNumbers(for code: String?) -> [String] {
    let normalized = (code ?? "").uppercased()
    switch normalized {
    case "AU": return ["000"]
    case "NZ": return ["111"]
    case "GB": return ["999", "112"]
    case "IE": return ["112", "999"]
    case "US", "CA": return ["911"]
    case "ZA": return ["112", "10177"]
    default:
      let numbers = emergencyNumbers(for: normalized)
      if numbers.contains("112") { return ["112"] }
      if numbers.contains("911") { return ["911"] }
      if numbers.contains("999") { return ["999"] }
      return numbers.first.map { [$0] } ?? []
    }
  }

  static func emergencyLabel(for code: String?) -> String {
    let numbers = preferredEmergencyNumbers(for: code)
    guard !numbers.isEmpty else { return "Call local emergency services" }
    return "Call " + numbers.joined(separator: " or ")
  }
}

@Observable
final class SettingsManager {
  static let shared = SettingsManager()

  var standardDose: Double {
    didSet { UserDefaults.standard.set(standardDose, forKey: "standardDose") }
  }
  var unit: String {
    didSet { UserDefaults.standard.set(unit, forKey: "unit") }
  }
  var safeIntervalMinutes: Int {
    didSet {
      UserDefaults.standard.set(safeIntervalMinutes, forKey: "safeIntervalMinutes")
      updateSharedInterval()
      WidgetCenter.shared.reloadAllTimelines()
    }
  }
  var substance: String {
    didSet { UserDefaults.standard.set(substance, forKey: "substance") }
  }
  var quickAmounts: [Double] {
    didSet {
      if let data = try? JSONEncoder().encode(quickAmounts) {
        UserDefaults.standard.set(data, forKey: "quickAmounts")
      }
    }
  }
  var notificationsEnabled: Bool {
    didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
  }
  var countdownMode: Bool {
    didSet {
      UserDefaults.standard.set(countdownMode, forKey: "countdownMode")
      updateSharedInterval()
      WidgetCenter.shared.reloadAllTimelines()
    }
  }
  var timeFormat: String {
    didSet { UserDefaults.standard.set(timeFormat, forKey: "timeFormat") }
  }
  var syncEnabled: Bool {
    didSet { UserDefaults.standard.set(syncEnabled, forKey: "syncEnabled") }
  }
  var deviceName: String {
    didSet { UserDefaults.standard.set(deviceName, forKey: "deviceName") }
  }
  var vanityName: String {
    didSet { UserDefaults.standard.set(vanityName, forKey: "vanityName") }
  }
  var proBetaAccepted: Bool {
    didSet {
      UserDefaults.standard.set(proBetaAccepted, forKey: "proBetaAccepted")
      WidgetCenter.shared.reloadAllTimelines()
    }
  }
  var profilePictureData: Data? {
    didSet { UserDefaults.standard.set(profilePictureData, forKey: "profilePictureData") }
  }
  var attachLocationToDoses: Bool {
    didSet { UserDefaults.standard.set(attachLocationToDoses, forKey: "attachLocationToDoses") }
  }
  var locationApproximate: Bool {
    didSet { UserDefaults.standard.set(locationApproximate, forKey: "locationApproximate") }
  }
  var homeCity: String {
    didSet { UserDefaults.standard.set(homeCity, forKey: "homeCity") }
  }
  var homeCountryCode: String {
    didSet { UserDefaults.standard.set(homeCountryCode, forKey: "homeCountryCode") }
  }
  var homeAddress: String {
    didSet { UserDefaults.standard.set(homeAddress, forKey: "homeAddress") }
  }
  var homeLatitude: Double? {
    didSet { UserDefaults.standard.set(homeLatitude, forKey: "homeLatitude") }
  }
  var homeLongitude: Double? {
    didSet { UserDefaults.standard.set(homeLongitude, forKey: "homeLongitude") }
  }
  var appearanceMode: AppAppearanceMode {
    didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode") }
  }
  var customAccentHex: String {
    didSet { UserDefaults.standard.set(customAccentHex, forKey: "customAccentHex") }
  }
  var customPrimaryButtonHex: String {
    didSet { UserDefaults.standard.set(customPrimaryButtonHex, forKey: "customPrimaryButtonHex") }
  }
  var customQuickButtonHex: String {
    didSet { UserDefaults.standard.set(customQuickButtonHex, forKey: "customQuickButtonHex") }
  }
  var customBackgroundHex: String {
    didSet { UserDefaults.standard.set(customBackgroundHex, forKey: "customBackgroundHex") }
  }

  init() {
    let ud = UserDefaults.standard
    standardDose      = ud.object(forKey: "standardDose") as? Double ?? 1.5
    unit              = ud.string(forKey: "unit") ?? "ml"
    safeIntervalMinutes = ud.object(forKey: "safeIntervalMinutes") as? Int ?? 90
    substance         = ud.string(forKey: "substance") ?? "GHB"
    notificationsEnabled = ud.bool(forKey: "notificationsEnabled")
    countdownMode     = ud.object(forKey: "countdownMode") as? Bool ?? true
    timeFormat        = ud.string(forKey: "timeFormat") ?? "hours"
    syncEnabled       = ud.bool(forKey: "syncEnabled")
    deviceName        = ud.string(forKey: "deviceName") ?? Self.defaultDeviceName
    vanityName        = ud.string(forKey: "vanityName") ?? ""
    proBetaAccepted   = ud.bool(forKey: "proBetaAccepted")
    profilePictureData = ud.data(forKey: "profilePictureData")
    attachLocationToDoses = ud.bool(forKey: "attachLocationToDoses")
    locationApproximate   = ud.object(forKey: "locationApproximate") as? Bool ?? true
    homeCity = ud.string(forKey: "homeCity") ?? ""
    let savedHomeCountryCode = ud.string(forKey: "homeCountryCode")
    let defaultCountryCode = Locale.current.region?.identifier ?? "AU"
    homeCountryCode = EmergencyNumberCatalogue.country(for: savedHomeCountryCode)?.code
      ?? EmergencyNumberCatalogue.country(for: defaultCountryCode)?.code
      ?? "AU"
    homeAddress = ud.string(forKey: "homeAddress") ?? ""
    homeLatitude = ud.object(forKey: "homeLatitude") as? Double
    homeLongitude = ud.object(forKey: "homeLongitude") as? Double
    appearanceMode = AppAppearanceMode(rawValue: ud.string(forKey: "appearanceMode") ?? "") ?? .auto
    customAccentHex = ud.string(forKey: "customAccentHex") ?? AppTheme.defaultAccentHex
    customPrimaryButtonHex = ud.string(forKey: "customPrimaryButtonHex") ?? AppTheme.defaultPrimaryButtonHex
    customQuickButtonHex = ud.string(forKey: "customQuickButtonHex") ?? AppTheme.defaultQuickButtonHex
    customBackgroundHex = ud.string(forKey: "customBackgroundHex") ?? AppTheme.defaultBackgroundHex

    if let data = ud.data(forKey: "quickAmounts"),
       let decoded = try? JSONDecoder().decode([Double].self, from: data) {
      quickAmounts = decoded
    } else {
      quickAmounts = [0.5, 1.0, 1.5, 2.0]
    }
  }

  // Patches only the interval/countdownMode fields in shared defaults,
  // preserving whatever dose data DoseStore last wrote.
  private func updateSharedInterval() {
    guard let raw = AppGroup.sharedDefaults?.data(forKey: AppGroup.lastDoseKey),
          var data = try? JSONDecoder().decode(SharedDoseData.self, from: raw) else { return }
    data.safeIntervalMinutes = safeIntervalMinutes
    data.countdownMode = countdownMode
    if let encoded = try? JSONEncoder().encode(data) {
      AppGroup.sharedDefaults?.set(encoded, forKey: AppGroup.lastDoseKey)
    }
  }

  private static var defaultDeviceName: String {
    #if os(iOS)
    UIDevice.current.name
    #else
    Host.current().localizedName ?? "My Mac"
    #endif
  }
}
