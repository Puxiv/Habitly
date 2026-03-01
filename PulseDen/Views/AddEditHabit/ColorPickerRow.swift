import SwiftUI

struct ColorPickerRow: View {
    @Binding var selectedHex: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Color.presetAccentColors, id: \.hex) { preset in
                let color = Color(hex: preset.hex)
                let isSelected = selectedHex == preset.hex

                Circle()
                    .fill(color)
                    .frame(height: 36)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .onTapGesture { selectedHex = preset.hex }
                    .animation(.spring(duration: 0.2), value: isSelected)
            }
        }
    }
}

#Preview {
    @Previewable @State var hex = "#007AFF"
    ColorPickerRow(selectedHex: $hex)
        .padding()
}
