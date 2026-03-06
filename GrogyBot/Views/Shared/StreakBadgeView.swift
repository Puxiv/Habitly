import SwiftUI

struct StreakBadgeView: View {
    let count: Int
    let color: Color

    var body: some View {
        if count > 0 {
            HStack(spacing: 2) {
                Text("🔥")
                    .font(.caption)
                Text("\(count)")
                    .font(.caption.bold())
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
        }
    }
}

#Preview {
    StreakBadgeView(count: 7, color: .orange)
}
