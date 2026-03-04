import SwiftUI

public struct ContentView: View {
    @StateObject private var audioManager = RadioAudioManager.shared
    @State private var isPlayToggled = false
    @State private var showVolumeDisplay = false
    @State private var volumeTimer: Timer?

    // Power Animation States (LCD Backlight Fade)
    @State private var isScreenOn = true
    @State private var isContentVisible = true
    @State private var notificationMessage: String? = nil
    @State private var notificationTimer: Timer? = nil
    @State private var showCredits = false

    public init() {}

    public var body: some View {
        ZStack {
            Color(red: 0xF7/255, green: 0xF7/255, blue: 0xF6/255)
                .ignoresSafeArea()

            // Chassis Background
            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                Gradient.Stop(color: Color(red: 0.91, green: 0.91, blue: 0.91), location: 0.00),
                                Gradient.Stop(color: Color(red: 0.84, green: 0.84, blue: 0.84), location: 0.60),
                                Gradient.Stop(color: Color(red: 0.62, green: 0.62, blue: 0.62), location: 1.00),
                            ],
                            startPoint: UnitPoint(x: 0, y: 0),
                            endPoint: UnitPoint(x: 0.96, y: 1.06)
                        )
                        .shadow(.inner(color: .white.opacity(0.5), radius: 4.7, x: 0, y: -4))
                        .shadow(.inner(color: .black.opacity(0.25), radius: 1.9, x: 0, y: -1))
                    )
                    .frame(maxWidth: .infinity, maxHeight: 550)
                    .shadow(color: .black.opacity(0.41), radius: 1.7, x: 0, y: 1.8)
                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Speaker Image
                Image("speaker")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 320)
                    .padding(.top, 25)

                // Modular Display View
                DisplayView(
                    audioManager: audioManager,
                    isScreenOn: isScreenOn,
                    isContentVisible: isContentVisible,
                    showVolumeDisplay: $showVolumeDisplay
                )
                .offset(y: -20)

                Spacer()

                // Lower Controls Section
                HStack {
                    // Modular Volume Knob
                    VolumeKnobView(
                        audioManager: audioManager,
                        isScreenOn: isScreenOn,
                        showVolume: showVolume
                    )
                    .padding(.leading, 30)

                    Spacer()

                    // Power Button Component
                    PowerButton(
                        isScreenOn: $isScreenOn,
                        isContentVisible: $isContentVisible,
                        isPlayToggled: $isPlayToggled,
                        audioManager: audioManager,
                        showNotification: showNotification
                    )
                    .padding(.trailing, 40)
                    .offset(y: -15)
                }

                // Modular Playback Controls
                PlaybackControlsView(
                    audioManager: audioManager,
                    isPlayToggled: $isPlayToggled,
                    isScreenOn: isScreenOn,
                    showNotification: showNotification,
                    showCredits: $showCredits
                )
                .padding(.bottom, 60)
            }
        }
        .sheet(isPresented: $showCredits) {
            CreditsView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .overlay(alignment: .top) {
            notificationOverlay
        }
    }

    // MARK: - Private Components & Helpers

    private var notificationOverlay: some View {
        Group {
            if let msg = notificationMessage {
                Text(msg)
                    .font(.custom("LED Dot-Matrix", size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.85))
                            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
            }
        }
    }

    private func showVolume() {
        showVolumeDisplay = true
        volumeTimer?.invalidate()
        volumeTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showVolumeDisplay = false
            }
        }
    }

    private func showNotification(_ message: String) {
        notificationTimer?.invalidate()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            notificationMessage = message
        }
        notificationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            withAnimation(.easeIn(duration: 0.3)) {
                notificationMessage = nil
            }
        }
    }
}

// Internal Power Button Sub-component
struct PowerButton: View {
    @Binding var isScreenOn: Bool
    @Binding var isContentVisible: Bool
    @Binding var isPlayToggled: Bool
    @ObservedObject var audioManager: RadioAudioManager
    let showNotification: (String) -> Void
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 48, height: 48)
                    .shadow(color: .white.opacity(0.4), radius: 1, x: 0, y: 1)

                Button(action: handlePowerToggle) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color(hex: "c5e6d1"), location: 0.0),
                                        .init(color: Color(hex: "a8d2ba"), location: 0.5),
                                        .init(color: Color(hex: "92bfa5"), location: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: -1)
                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)

                        Image(systemName: "power")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black.opacity(0.6))
                            .shadow(color: .white.opacity(0.3), radius: 0.5, x: 0, y: 1)
                    }
                }
                .buttonStyle(RubberButtonStyle())
            }

            Text("POWER")
                .font(.custom("LED Dot-Matrix", size: 10))
                .foregroundColor(.black.opacity(0.5))
                .padding(.top, 4)
        }
    }
    
    private func handlePowerToggle() {
        audioManager.triggerHaptic(.medium)

        if isScreenOn {
            showNotification("Powering off")
            audioManager.stopPlayback()
            isPlayToggled = false
            
            withAnimation(.easeOut(duration: 0.2)) {
                isScreenOn = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.2)) {
                    isContentVisible = false
                }
            }
        } else {
            showNotification("Ready for the classics")

            withAnimation(.easeIn(duration: 0.15)) {
                isScreenOn = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeIn(duration: 0.2)) {
                    isContentVisible = true
                }
            }
        }
    }
}
