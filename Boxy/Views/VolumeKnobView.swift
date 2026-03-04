import SwiftUI

struct VolumeKnobView: View {
    @ObservedObject var audioManager: RadioAudioManager
    let isScreenOn: Bool
    let showVolume: () -> Void
    @State private var angleOffset: Double = 0
    let volumeSteps: Int = 32

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Image("volume_indicator_line")
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 142, height: 120)
                    .offset(x: -1, y: -18)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0.31),
                                    .init(color: Color(red: 0.67, green: 0.67, blue: 0.67), location: 1.0)
                                ],
                                startPoint: UnitPoint(x: 0.82, y: 1.18),
                                endPoint: UnitPoint(x: 0.25, y: 0.2)
                            )
                        )
                        .frame(width: 112.5, height: 112.5)
                        .shadow(color: .black.opacity(0.2), radius: 2.4, x: 5, y: 7)
                        .shadow(color: .black.opacity(0.76), radius: 2.45, x: 1, y: 2)

                    Image("knob_black_ring")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 116)

                    Image("knob_control")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 116)
                        .rotationEffect(.degrees(audioManager.volume * 240 - 123))
                        .animation(nil, value: audioManager.volume)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let center = CGPoint(x: 58, y: 58)
                                    let currentVector = CGVector(dx: value.location.x - center.x, dy: value.location.y - center.y)
                                    let currentAngle = atan2(currentVector.dy, currentVector.dx)

                                    var currentDeg = Double(currentAngle) * 180.0 / .pi + 90.0
                                    if currentDeg > 180 { currentDeg -= 360 }
                                    if currentDeg < -180 { currentDeg += 360 }

                                    if value.startLocation == value.location {
                                        let initialKnobDeg = audioManager.volume * 240.0 - 123.0
                                        angleOffset = currentDeg - initialKnobDeg
                                    }

                                    var targetDeg = currentDeg - angleOffset
                                    if targetDeg > 180 { targetDeg -= 360 }
                                    if targetDeg < -180 { targetDeg += 360 }

                                    let newVolume = quantize(max(0, min(1, (targetDeg + 123.0) / 240.0)))

                                    if newVolume != audioManager.volume {
                                        if isScreenOn {
                                            showVolume()
                                        }
                                        audioManager.triggerHaptic(.light)
                                        let calculatedRate = Float(0.7 + (newVolume * 1.0))
                                        audioManager.playSound("volume-tick-1", rate: calculatedRate)
                                        audioManager.volume = newVolume
                                    }
                                }
                        )
                }
            }

            Text("VOLUME")
                .font(.custom("LED Dot-Matrix", size: 10))
                .foregroundColor(.black.opacity(0.5))
        }
    }

    private func quantize(_ value: Double) -> Double {
        let step = 1.0 / Double(volumeSteps - 1)
        return (value / step).rounded() * step
    }
}
