import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum AppTheme {
  static let defaultAccentHex = "#3B82F6"
  static let defaultPrimaryButtonHex = "#3B82F6"
  static let defaultQuickButtonHex = "#242E3C"
  static let defaultBackgroundHex = "#101620"

  // Backgrounds
  static var backgroundPrimary: Color {
    let custom = proCustomColor(forKey: "customBackgroundHex")
    return custom ?? paletteColor(dark: "#101620", light: "#F4F7FB")
  }
  static var backgroundSecondary: Color {
    adjustedBackground(fallbackDark: "#181F2A", fallbackLight: "#E9EEF6", opacity: 0.92)
  }
  static var backgroundCard: Color {
    adjustedBackground(fallbackDark: "#1E2633", fallbackLight: "#FFFFFF", opacity: 0.86)
  }
  static var backgroundElevated: Color {
    adjustedBackground(fallbackDark: "#242E3C", fallbackLight: "#E4EAF3", opacity: 0.78)
  }

  // Accents
  static var accentBlue: Color {
    proCustomColor(forKey: "customAccentHex") ?? color(hex: defaultAccentHex)
  }
  static var accentBlueD: Color {
    darker(accentBlue, amount: 0.14)
  }
  static var primaryButton: Color {
    proCustomColor(forKey: "customPrimaryButtonHex") ?? color(hex: defaultPrimaryButtonHex)
  }
  static var primaryButtonD: Color {
    darker(primaryButton, amount: 0.14)
  }
  static var quickButton: Color {
    proCustomColor(forKey: "customQuickButtonHex") ?? backgroundElevated
  }

  // Status
  static let statusRed = Color(red: 0.937, green: 0.267, blue: 0.267)  // #EF4444
  static let statusAmber = Color(red: 0.953, green: 0.612, blue: 0.071)  // #F39C12
  static let statusGreen = Color(red: 0.133, green: 0.773, blue: 0.369)  // #22C55E

  // Pro
  static let proAmber = Color(red: 0.961, green: 0.620, blue: 0.043)  // #F59E0B
  static let proOrange = Color(red: 0.953, green: 0.451, blue: 0.086)  // #F37216

  // Text
  static var textPrimary: Color {
    paletteColor(dark: "#FFFFFF", light: "#111827")
  }
  static var textSecondary: Color {
    paletteColor(dark: "#A6A6A6", light: "#4B5563")
  }
  static var textMuted: Color {
    paletteColor(dark: "#737373", light: "#6B7280")
  }

  // Border
  static var border: Color {
    paletteColor(dark: "#333333", light: "#CED6E2")
  }

  static func color(hex: String) -> Color {
    let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
    guard value.count == 6, let int = UInt64(value, radix: 16) else {
      return Color(red: 0.231, green: 0.510, blue: 0.965)
    }
    return Color(
      red: Double((int >> 16) & 0xFF) / 255.0,
      green: Double((int >> 8) & 0xFF) / 255.0,
      blue: Double(int & 0xFF) / 255.0
    )
  }

  static func hexString(from color: Color) -> String {
    #if os(iOS)
    let platformColor = UIColor(color)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    platformColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    #elseif os(macOS)
    let platformColor = NSColor(color).usingColorSpace(.sRGB) ?? .systemBlue
    let red = platformColor.redComponent
    let green = platformColor.greenComponent
    let blue = platformColor.blueComponent
    #else
    let red: CGFloat = 0.231
    let green: CGFloat = 0.510
    let blue: CGFloat = 0.965
    #endif
    return String(
      format: "#%02X%02X%02X",
      max(0, min(255, Int(round(red * 255)))),
      max(0, min(255, Int(round(green * 255)))),
      max(0, min(255, Int(round(blue * 255))))
    )
  }

  private static func proCustomColor(forKey key: String) -> Color? {
    let defaults = UserDefaults.standard
    guard defaults.bool(forKey: "proBetaAccepted"),
          let hex = defaults.string(forKey: key),
          !hex.isEmpty
    else { return nil }
    return color(hex: hex)
  }

  private static func adjustedBackground(fallbackDark: String, fallbackLight: String, opacity: Double) -> Color {
    if let custom = proCustomColor(forKey: "customBackgroundHex") {
      return custom.opacity(opacity)
    }
    return paletteColor(dark: fallbackDark, light: fallbackLight)
  }

  private static func paletteColor(dark: String, light: String) -> Color {
    switch UserDefaults.standard.string(forKey: "appearanceMode") {
    case AppAppearanceMode.day.rawValue:
      return color(hex: light)
    case AppAppearanceMode.night.rawValue:
      return color(hex: dark)
    default:
      return adaptiveColor(light: color(hex: light), dark: color(hex: dark))
    }
  }

  private static func adaptiveColor(light: Color, dark: Color) -> Color {
    #if os(iOS)
    return Color(UIColor { traits in
      traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
    })
    #elseif os(macOS)
    return Color(NSColor(name: nil) { appearance in
      let best = appearance.bestMatch(from: [.darkAqua, .aqua])
      return best == .darkAqua ? NSColor(dark) : NSColor(light)
    })
    #else
    return dark
    #endif
  }

  private static func darker(_ color: Color, amount: CGFloat) -> Color {
    #if os(iOS)
    let platformColor = UIColor(color)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    platformColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return Color(
      red: max(red - amount, 0),
      green: max(green - amount, 0),
      blue: max(blue - amount, 0),
      opacity: alpha
    )
    #elseif os(macOS)
    let platformColor = NSColor(color).usingColorSpace(.sRGB) ?? .systemBlue
    return Color(
      red: max(platformColor.redComponent - amount, 0),
      green: max(platformColor.greenComponent - amount, 0),
      blue: max(platformColor.blueComponent - amount, 0),
      opacity: platformColor.alphaComponent
    )
    #else
    return color
    #endif
  }
}
