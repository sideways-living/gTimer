import SwiftUI

struct ArcGaugeView: View {
  var progress: Double  // 0…1
  var statusColor: Color
  var timeString: String
  var statusLabel: String
  var isActive: Bool

  var body: some View {
    ZStack {
      // Track
      Circle()
        .trim(from: 0.1, to: 0.9)
        .stroke(AppTheme.backgroundElevated, style: StrokeStyle(lineWidth: 18, lineCap: .round))
        .rotationEffect(.degrees(90))

      // Fill
      if isActive {
        Circle()
          .trim(from: 0.1, to: 0.1 + 0.8 * min(progress, 1.0))
          .stroke(
            LinearGradient(colors: [statusColor.opacity(0.7), statusColor],
                           startPoint: .leading, endPoint: .trailing),
            style: StrokeStyle(lineWidth: 18, lineCap: .round)
          )
          .rotationEffect(.degrees(90))
          .animation(.easeInOut(duration: 0.5), value: progress)
      }

      // Glow dot at tip
      if isActive && progress > 0 {
        let angle = Angle.degrees(90 + (0.1 + 0.8 * min(progress, 1.0)) * 360)
        GeometryReader { geo in
          let r = geo.size.width / 2 - 9
          let cx = geo.size.width / 2
          let cy = geo.size.height / 2
          Circle()
            .fill(statusColor)
            .frame(width: 14, height: 14)
            .shadow(color: statusColor.opacity(0.8), radius: 6)
            .position(
              x: cx + r * cos(angle.radians - .pi / 2),
              y: cy + r * sin(angle.radians - .pi / 2)
            )
        }
      }

      // Center content
      VStack(spacing: 4) {
        Image(systemName: "drop.fill")
          .font(.system(size: 18))
          .foregroundStyle(isActive ? statusColor : AppTheme.textMuted)

        Text(timeString)
          .font(.system(size: 38, weight: .bold, design: .monospaced))
          .foregroundStyle(isActive ? statusColor : AppTheme.textMuted)
          .minimumScaleFactor(0.5)
          .lineLimit(1)

        Text(statusLabel)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(isActive ? statusColor.opacity(0.85) : AppTheme.textMuted)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 8)
      }
    }
    .frame(width: 260, height: 260)
  }
}
