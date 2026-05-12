import SwiftUI

struct ArcGaugeView: View {
  var progress: Double   // 0…1
  var statusColor: Color
  var timeString: String
  var statusLabel: String
  var isActive: Bool

  var body: some View {
    ZStack {
      // Track arc
      Circle()
        .trim(from: 0.1, to: 0.9)
        .stroke(AppTheme.backgroundElevated, style: StrokeStyle(lineWidth: 18, lineCap: .round))
        .rotationEffect(.degrees(90))

      // Fill arc
      if isActive && progress > 0 {
        Circle()
          .trim(from: 0.1, to: 0.1 + 0.8 * min(progress, 1.0))
          .stroke(
            LinearGradient(
              colors: [statusColor.opacity(0.65), statusColor],
              startPoint: .leading,
              endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 18, lineCap: .round)
          )
          .rotationEffect(.degrees(90))
          .animation(.easeInOut(duration: 0.6), value: progress)
      }

      // Glowing dot at the arc tip
      if isActive && progress > 0 {
        let tipAngle = Angle.degrees(90 + (0.1 + 0.8 * min(progress, 1.0)) * 360)
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
