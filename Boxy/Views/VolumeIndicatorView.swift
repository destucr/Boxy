import SwiftUI

struct VolumeIndicatorView: View {
    let volume: Double
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(0..<6) { index in
                let segmentCount = 2 + (index * 3)
                let threshold = Double(index) / 6.0
                VStack(spacing: -13) {
                    ForEach(0..<segmentCount, id: \.self) { _ in
                        Text("-")
                            .font(.custom("LED Dot-Matrix", size: 18))
                    }
                }
                .foregroundColor(volume > threshold ? .black : .black.opacity(0.2))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 30, alignment: .bottom)
    }
}
