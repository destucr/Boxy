import SwiftUI

struct DisplayView: View {
    @ObservedObject var audioManager: RadioAudioManager
    let isScreenOn: Bool
    let isContentVisible: Bool
    @Binding var showVolumeDisplay: Bool

    var body: some View {
        ZStack {
            Image("display_off")
                .resizable()
                .scaledToFit()
                .frame(width: 350, height: 160)

            Image("display_on")
                .resizable()
                .scaledToFit()
                .frame(width: 350, height: 160)
                .opacity(isScreenOn ? 1 : 0)

            if isContentVisible {
                VStack {
                    HStack {
                        if showVolumeDisplay {
                            Text("VOLUME")
                                .font(.custom("LED Dot-Matrix", size: 12))
                        } else if !audioManager.isPlaying && !audioManager.showNowPlayingOverlay {
                            Text("MUSIC")
                                .font(.custom("LED Dot-Matrix", size: 12))
                        }

                        Spacer()

                        if showVolumeDisplay {
                            Text("\(Int(audioManager.volume * 100))%")
                                .font(.custom("LED Dot-Matrix", size: 12))
                        } else if !audioManager.isPlaying && !audioManager.showNowPlayingOverlay {
                            Text("FM")
                                .font(.custom("LED Dot-Matrix", size: 12))
                        }
                    }
                    .padding(.bottom, 5)

                    // Content Area
                    if showVolumeDisplay {
                        HStack(alignment: .bottom) {
                            Text("MIN")
                                .font(Font.custom("LED Dot-Matrix", size: 10))

                            VolumeIndicatorView(volume: audioManager.volume)
                                .offset(y: 5)

                            Text("MAX")
                                .font(Font.custom("LED Dot-Matrix", size: 10))
                        }
                        .padding(.top, 10)
                        .frame(maxWidth: 200, maxHeight: 45)
                    } else if audioManager.showNowPlayingOverlay {
                        VStack(alignment: .center, spacing: 6) {
                            Text(audioManager.nowPlayingMessage)
                                .font(.custom("LED Dot-Matrix", size: 12))
                                .opacity(0.8)

                            Text(audioManager.selectedTrack.title.uppercased())
                                .font(.custom("LED Dot-Matrix", size: 14))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 10)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(width: 240)
                    } else if audioManager.isPlaying {
                        PlayingVisualizerView()
                            .frame(width: 260, height: 82)
                            .offset(y: -5)
                    } else {
                        // Track List Overlay
                        VStack(alignment: .leading, spacing: 0.5) {
                            ForEach(visibleTracks) { track in
                                let isSelected = audioManager.selectedTrack == track
                                Button(action: {
                                    guard isScreenOn else { return }
                                    var transaction = Transaction()
                                    transaction.disablesAnimations = true
                                    withTransaction(transaction) {
                                        if let idx = audioManager.availableTracks.firstIndex(of: track) {
                                            if audioManager.isPlaying {
                                                audioManager.showNowPlaying()
                                            }
                                            audioManager.playTrack(at: idx)
                                        }
                                    }
                                }) {
                                    HStack(alignment: .center) {
                                        // Fixed indicator area (20pt) with intentional selection shift
                                        ZStack(alignment: .leading) {
                                            Text(isSelected ? ">" : "-")
                                                .font(.custom("LED Dot-Matrix", size: 14))
                                                .foregroundColor(isSelected ? .black : .black.opacity(0.2))
                                        }
                                        .frame(width: 5, alignment: .leading)
                                        .padding(.leading, isSelected ? 5 : 0)

                                        if isSelected {
                                            MarqueeText(
                                                text: track.title.uppercased(),
                                                font: .custom("LED Dot-Matrix", size: 14),
                                                color: .black,
                                                delay: 0.3,
                                                speed: 28
                                            )
                                            .frame(height: 18)
                                        } else {
                                            Text(track.title.uppercased())
                                                .font(.custom("LED Dot-Matrix", size: 14))
                                                .foregroundColor(.black.opacity(0.2))
                                                .lineLimit(1)
                                        }
                                    }
                                    .offset(y: 5)
                                }
                                .buttonStyle(PlainNoAnimationButtonStyle())
                            }
                        }
                        .animation(nil, value: audioManager.selectedTrackIndex)
                        .padding(.horizontal, 40)
                        .frame(width: 300, alignment: .leading)
                    }
                }
                .animation(nil, value: showVolumeDisplay)
                .animation(nil, value: audioManager.isPlaying)
                .animation(nil, value: audioManager.selectedTrackIndex)
                .frame(width: 260, height: 140)
                .clipped()
            }
        }
    }

    private var visibleTracks: [AudioTrack] {
        let count = audioManager.availableTracks.count
        if count == 0 { return [] }
        let current = audioManager.selectedTrackIndex
        let prev = (current - 1 + count) % count
        let next = (current + 1) % count
        return [
            audioManager.availableTracks[prev],
            audioManager.availableTracks[current],
            audioManager.availableTracks[next]
        ]
    }
}
