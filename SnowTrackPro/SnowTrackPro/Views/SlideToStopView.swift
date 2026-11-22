import SwiftUI

/// ゲレンデでのポケット誤操作を防止する「スライドして計測終了」ロックUI
struct SlideToStopView: View {
    let onFinish: () -> Void

    @State private var dragOffset: CGFloat = 0
    private let trackHeight: CGFloat = 60
    private let thumbSize: CGFloat = 52

    var body: some View {
        GeometryReader { geometry in
            let maxOffset = max(0, geometry.size.width - thumbSize - 8)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.red.opacity(0.22))
                    .overlay(
                        Capsule()
                            .stroke(Color.red.opacity(0.6), lineWidth: 1.5)
                    )

                Text("action.slideToStop")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)

                Circle()
                    .fill(Color.red)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(
                        Image(systemName: "stop.fill")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    )
                    .offset(x: 4 + dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = min(max(0, value.translation.width), maxOffset)
                            }
                            .onEnded { _ in
                                if dragOffset >= maxOffset * 0.82 {
                                    onFinish()
                                }
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    dragOffset = 0
                                }
                            }
                    )
            }
        }
        .frame(height: trackHeight)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
