import SwiftUI

struct WeekdayPicker: View {
    @Binding var selectedDays: [Int] // Calendar.weekday values: 1=Sun ... 7=Sat
    var accentHex: String = "#007AFF"

    private let symbols = Calendar.current.shortWeekdaySymbols // ["Sun", "Mon", ...]
    private let accent: Color

    init(selectedDays: Binding<[Int]>, accentHex: String = "#007AFF") {
        self._selectedDays = selectedDays
        self.accentHex = accentHex
        self.accent = Color(hex: accentHex)
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { weekday in
                let isSelected = selectedDays.contains(weekday)
                let symbol = symbols[weekday - 1]
                    .prefix(2) // "Su", "Mo", etc.

                Button {
                    if isSelected {
                        selectedDays.removeAll { $0 == weekday }
                    } else {
                        selectedDays.append(weekday)
                    }
                } label: {
                    Text(symbol)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? accent : Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .buttonStyle(.plain)
                .animation(.spring(duration: 0.2), value: isSelected)
            }
        }
    }
}

#Preview {
    @Previewable @State var days = [2, 4, 6]
    WeekdayPicker(selectedDays: $days)
        .padding()
}
