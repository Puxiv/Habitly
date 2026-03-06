import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Int
    var maxRating: Int = 5
    var size: CGFloat = 20
    var color: Color = .yellow

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? color : Color(.tertiaryLabel))
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.2)) {
                            rating = star
                        }
                    }
            }
        }
    }
}
