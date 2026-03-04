import SwiftUI

struct PlaybackControlsView: View {
    @ObservedObject var audioManager: RadioAudioManager
    @Binding var isPlayToggled: Bool
    let isScreenOn: Bool
    let showNotification: (String) -> Void
    @Binding var showCredits: Bool
    
    var body: some View {
        HStack(spacing: 5) {
            controlButton(icon: "ic_replay", isActive: false, altIcon: nil) {
                audioManager.triggerHaptic(.light)
                audioManager.playSound("button-click")
                
                guard isScreenOn else {
                    showNotification("Turn on the power to play")
                    return
                }
                
                if isPlayToggled {
                    audioManager.showNowPlaying(message: "PLAY AGAIN")
                    audioManager.stopPlayback()
                    audioManager.playTestAudio()
                }
            }
            .drawingGroup()

            controlButton(icon: "ic_previous", isActive: false, altIcon: nil) {
                audioManager.triggerHaptic(.light)
                audioManager.playSound("button-click")
                guard isScreenOn else {
                    showNotification("Turn on the power to play")
                    return
                }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    audioManager.playPreviousTrack()
                }
            }
            .drawingGroup()

            controlButton(
                icon: isPlayToggled ? "ic_pause" : "ic_play",
                background: "button_enable",
                isActive: isPlayToggled,
                altIcon: isPlayToggled ? "ic_play" : "ic_pause"
            ) {
                audioManager.triggerHaptic(.light)
                audioManager.playSound(isPlayToggled ? "button-click" : "button-release")
                guard isScreenOn else {
                    showNotification("Turn on the power to play")
                    return
                }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    if isPlayToggled {
                        audioManager.pausePlayback()
                        isPlayToggled = false
                    } else {
                        if audioManager.isPaused {
                            audioManager.resumePlayback()
                        } else {
                            audioManager.showNowPlaying()
                            audioManager.playTestAudio()
                        }
                        isPlayToggled = true
                    }
                }
            }
            .drawingGroup()

            controlButton(icon: "ic_next", isActive: false, altIcon: nil) {
                audioManager.triggerHaptic(.light)
                audioManager.playSound("button-click")
                guard isScreenOn else {
                    showNotification("Turn on the power to play")
                    return
                }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    audioManager.playNextTrack()
                }
            }
            .drawingGroup()

            controlButton(icon: "ic_stop", isActive: false, altIcon: nil) {
                audioManager.triggerHaptic(.light)
                audioManager.playSound("button-click")
                guard isScreenOn else {
                    showNotification("Turn on the power to play")
                    return
                }
                audioManager.stopPlayback()
                isPlayToggled = false
            }
            .drawingGroup()
        }
        .transaction { transaction in
            transaction.disablesAnimations = true
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(hex: "191818"))
        )
        .overlay(alignment: .bottomTrailing) {
            Button(action: {
                audioManager.triggerHaptic(.light)
                showCredits = true
            }) {
                Text("CREDITS")
                    .font(.custom("LED Dot-Matrix", size: 9))
                    .foregroundColor(.black.opacity(0.6))
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            .shadow(color: .white.opacity(0.5), radius: 0.5, x: 0, y: 1)
                    )
            }
            .offset(y: 35)
        }
    }

    private func controlButton(
        icon: String,
        background: String = "button_enable",
        isActive: Bool = false,
        altIcon: String? = nil,
        size: CGFloat = 65,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Color.clear.frame(width: size, height: size * 0.6)
        }
        .buttonStyle(NoAnimationButtonStyle(
            baseBackground: background,
            baseIcon: icon,
            altIcon: altIcon,
            isActive: isActive,
            size: size
        ))
    }
}
