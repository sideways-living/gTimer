import SwiftUI

struct ArcGaugeView: View {
  var progress: Double   // elapsed progress, 0...1
  var countdownMode: Bool
  var statusColor: Color
  var timeString: String
  var statusLabel: String
  var isActive: Bool

  private var clampedProgress: Double {
    min(max(progress, 0), 1)
  }

  private var visibleProgress: Double {
    countdownMode ? max(1 - clampedProgress, 0) : clampedProgress
  }

  var body: some View {
    ZStack {
      // Track arc
      Circle()
        .trim(from: 0.1, to: 0.9)
        .stroke(AppTheme.backgroundElevated, style: StrokeStyle(lineWidth: 18, lineCap: .round))
        .rotationEffect(.degrees(90))

      if isActive && countdownMode {
        Circle()
          .trim(from: 0.1, to: 0.9)
          .stroke(
            LinearGradient(
              colors: [statusColor.opacity(0.65), statusColor],
              startPoint: .leading,
              endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 18, lineCap: .round)
          )
          .rotationEffect(.degrees(90))

        if clampedProgress > 0 {
          Circle()
            .trim(from: 0.9 - 0.8 * clampedProgress, to: 0.9)
            .stroke(AppTheme.backgroundElevated, style: StrokeStyle(lineWidth: 20, lineCap: .round))
            .rotationEffect(.degrees(90))
            .animation(.easeInOut(duration: 0.6), value: clampedProgress)
        }
      } else if isActive && visibleProgress > 0 {
        Circle()
          .trim(from: 0.1, to: 0.1 + 0.8 * visibleProgress)
          .stroke(
            LinearGradient(
              colors: [statusColor.opacity(0.65), statusColor],
              startPoint: .leading,
              endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 18, lineCap: .round)
          )
          .rotationEffect(.degrees(90))
          .animation(.easeInOut(duration: 0.6), value: visibleProgress)
      }

      // Glowing dot at the arc tip
      if isActive && visibleProgress > 0 {
        let tipTrim = countdownMode ? 0.9 - 0.8 * clampedProgress : 0.1 + 0.8 * visibleProgress
        let tipAngle = Angle.degrees(90 + tipTrim * 360)
        GeometryReader { geo in
          let r  = geo.size.width / 2 - 9
          let cx = geo.size.width / 2
          let cy = geo.size.height / 2
          Circle()
            .fill(statusColor)
            .frame(width: 14, height: 14)
            .shadow(color: statusColor.opacity(0.9), radius: 6)
            .position(
              x: cx + r * cos(tipAngle.radians - .pi / 2),
              y: cy + r * sin(tipAngle.radians - .pi / 2)
            )
        }
      }

      // Centre content — droplet icon above the digits
      VStack(spacing: 6) {
        Image(systemName: "drop.fill")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(isActive ? statusColor : AppTheme.textMuted)

        Text(timeString)
          .font(.system(size: 40, weight: .bold, design: .monospaced))
          .foregroundStyle(isActive ? statusColor : AppTheme.textMuted)
          .minimumScaleFactor(0.5)
          .lineLimit(1)
          .monospacedDigit()
      }
    }
    .frame(width: 270, height: 270)
  }
}
