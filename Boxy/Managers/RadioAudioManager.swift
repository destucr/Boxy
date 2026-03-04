import SwiftUI
import Foundation
import AVFoundation
import AVKit
import Combine

@MainActor
public class RadioAudioManager: NSObject, ObservableObject {
    public static let shared = RadioAudioManager()

    // Serial queue to ensure audio operations never overlap
    private let audioQueue = DispatchQueue(label: "com.boxy.audio")

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let mixerNode = AVAudioMixerNode()

    // Effects
    private let eqNode = AVAudioUnitEQ(numberOfBands: 3)
    private let distortionNode = AVAudioUnitDistortion()
    private let delayNode = AVAudioUnitDelay()

    // Noise and Beeps
    private let noisePlayerNode = AVAudioPlayerNode()
    private var noiseBuffer: AVAudioPCMBuffer?
    private let beepPlayerNode = AVAudioPlayerNode()
    private var beepBuffer: AVAudioPCMBuffer?
    private let heterodynePlayerNode = AVAudioPlayerNode()
    private var heterodyneBuffer: AVAudioPCMBuffer?

    private var uiSoundPlayer: AVAudioPlayer?
    private var activeTickPlayers: [AVAudioPlayer] = []
    private let maxTickPlayers = 8 // Limit concurrent tick sounds

    // Cached resources
    private var cachedSoundData: [String: Data] = [:]
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)

    // Simple debounce for track changes
    private var lastTrackChangeTime = Date.distantPast
    private let minTrackChangeInterval: TimeInterval = 0.15

    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var showNowPlayingOverlay = false
    @Published var nowPlayingMessage: String = "NOW PLAYING"
    private var nowPlayingTimer: Timer?
    private var isManualStopping = false
    private var currentSessionID = UUID()

    @Published var isMonitoring = false
    @Published var isAutoEchoEnabled = false
    @Published var currentFilter: RadioFilter = .hamRadio
    @Published var volume: Double = 0.5 {
        didSet {
            mixerNode.outputVolume = Float(volume)
        }
    }

    @Published var availableTracks: [AudioTrack] = [
        AudioTrack(title: "Beethoven - Coriolan Overture", filename: "Classicals.de - Beethoven - Coriolan Overture - Op.62", artist: "Beethoven"),
        AudioTrack(title: "Chopin - Nocturne Op. 9 no. 2", filename: "Classicals.de - Chopin - Nocturne Op. 9 no. 2 in E-flat major", artist: "Chopin"),
        AudioTrack(title: "Mozart - Marriage of Figaro", filename: "Classicals.de - Mozart - Marriage of Figaro", artist: "Mozart"),
        AudioTrack(title: "Mozart - Symphony in F major", filename: "Classicals.de - Mozart - Symphony in F major, K.Anh.223:19a - III", artist: "Mozart"),
        AudioTrack(title: "Paganini - La Campanella", filename: "Classicals.de - Paganini - Violin Concerto No. 2, Op. 7 (La Campanella) - 3. Movement", artist: "Paganini"),
        AudioTrack(title: "Vivaldi - Concerto for 2 Violins", filename: "Classicals.de - Vivaldi - Concerto for 2 Violins in A minor, RV 522 - I. Allegro (A minor)", artist: "Vivaldi"),
        AudioTrack(title: "Vivaldi - Oboe Concerto", filename: "Classicals.de - Vivaldi - Oboe Concerto in C major - 2. Larghetto - RV 447", artist: "Vivaldi"),
    ]
    @Published var selectedTrackIndex: Int = 0

    public var selectedTrack: AudioTrack {
        availableTracks[selectedTrackIndex]
    }

    override init() {
        super.init()
        setupEngine()
        loadNoiseBuffer()
        loadBeepBuffer()
        loadHeterodyneBuffer()
        preloadUISounds()

        // Prepare haptics
        lightHaptic.prepare()
        mediumHaptic.prepare()

        debugListBundleResources()
    }

    private func preloadUISounds() {
        let sounds = ["button-click", "button-release", "volume-tick-1"]
        let bundle: Bundle = {
#if SWIFT_PACKAGE
            return Bundle.module
#else
            return Bundle.main
#endif
        }()

        for name in sounds {
            if let url = bundle.url(forResource: name, withExtension: "mp3") ??
                bundle.url(forResource: name, withExtension: "mp3", subdirectory: "Resources"),
               let data = try? Data(contentsOf: url) {
                cachedSoundData[name] = data
            }
        }
    }

    private func setupEngine() {
        // Configure audio session once for playback
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }

        engine.attach(playerNode)
        engine.attach(eqNode)
        engine.attach(distortionNode)
        engine.attach(delayNode)
        engine.attach(noisePlayerNode)
        engine.attach(beepPlayerNode)
        engine.attach(heterodynePlayerNode)
        engine.attach(mixerNode)

        let format = engine.mainMixerNode.outputFormat(forBus: 0)

        engine.connect(playerNode, to: eqNode, format: format)
        engine.connect(eqNode, to: distortionNode, format: format)
        engine.connect(distortionNode, to: delayNode, format: format)
        engine.connect(delayNode, to: mixerNode, format: format)

        engine.connect(noisePlayerNode, to: mixerNode, format: format)
        engine.connect(beepPlayerNode, to: mixerNode, format: format)
        engine.connect(heterodynePlayerNode, to: mixerNode, format: format)

        engine.connect(mixerNode, to: engine.mainMixerNode, format: format)

        prepareFilter(currentFilter)
    }

    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    func startMonitoring() {
        stopPlayback()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            if engine.isRunning {
                engine.stop()
            }

            let inputNode = engine.inputNode
            let inputFormat = inputNode.inputFormat(forBus: 0)

            engine.disconnectNodeInput(eqNode)
            engine.disconnectNodeInput(distortionNode)
            engine.disconnectNodeInput(delayNode)
            engine.disconnectNodeInput(mixerNode)

            engine.connect(inputNode, to: eqNode, format: inputFormat)
            engine.connect(eqNode, to: distortionNode, format: inputFormat)
            engine.connect(distortionNode, to: delayNode, format: inputFormat)
            engine.connect(delayNode, to: mixerNode, format: inputFormat)
            engine.connect(mixerNode, to: engine.mainMixerNode, format: nil)

            engine.prepare()
            try engine.start()
            isMonitoring = true

            if let buffer = noiseBuffer {
                noisePlayerNode.volume = (currentFilter == .hamRadio) ? 0.08 : 0.03
                noisePlayerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
                noisePlayerNode.play()

                if currentFilter == .hamRadio {
                    startHeterodyne()
                }
            }
        } catch {
            print("Could not start engine for monitoring: \(error)")
        }
    }

    func stopMonitoring() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            self.engine.stop()

            self.engine.disconnectNodeInput(self.eqNode)
            self.engine.disconnectNodeInput(self.distortionNode)
            self.engine.disconnectNodeInput(self.delayNode)
            self.engine.disconnectNodeInput(self.mixerNode)

            let outputFormat = self.engine.mainMixerNode.outputFormat(forBus: 0)

            self.engine.connect(self.playerNode, to: self.eqNode, format: outputFormat)
            self.engine.connect(self.eqNode, to: self.distortionNode, format: outputFormat)
            self.engine.connect(self.distortionNode, to: self.delayNode, format: outputFormat)
            self.engine.connect(self.delayNode, to: self.mixerNode, format: outputFormat)
            self.engine.connect(self.mixerNode, to: self.engine.mainMixerNode, format: outputFormat)

            self.noisePlayerNode.stop()
            self.stopHeterodyne()

            Task { @MainActor in
                self.isMonitoring = false
            }
        }
    }

    private func loadNoiseBuffer() {
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let frameCount = AVAudioFrameCount(format.sampleRate * 5.0)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }

        buffer.frameLength = frameCount
        let channelCount = Int(buffer.format.channelCount)

        for channel in 0..<channelCount {
            if let data = buffer.floatChannelData?[channel] {
                for i in 0..<Int(frameCount) {
                    let whiteNoise = Float.random(in: -1.0...1.0) * 0.4
                    let rumble = sin(Float(i) * 0.01) * 0.1
                    data[i] = whiteNoise + rumble
                }
            }
        }
        self.noiseBuffer = buffer
    }

    private func loadBeepBuffer() {
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let duration: Double = 0.2
        let frameCount = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }

        buffer.frameLength = frameCount
        let channelCount = Int(buffer.format.channelCount)
        let frequency: Float = 1200.0
        let k: Float = 10.0 // Decay constant

        for channel in 0..<channelCount {
            if let data = buffer.floatChannelData?[channel] {
                for i in 0..<Int(frameCount) {
                    let t = Float(i) / Float(format.sampleRate)
                    let envelope = exp(-k * t)
                    data[i] = envelope * sin(2.0 * .pi * frequency * t) * 0.4
                }
            }
        }
        self.beepBuffer = buffer
    }

    private func loadHeterodyneBuffer() {
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let duration: Double = 5.0
        let frameCount = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }

        buffer.frameLength = frameCount
        let channelCount = Int(buffer.format.channelCount)

        for channel in 0..<channelCount {
            if let data = buffer.floatChannelData?[channel] {
                var phase: Float = 0
                for i in 0..<Int(frameCount) {
                    let t = Float(i) / Float(format.sampleRate)
                    let baseFreq: Float = 1000.0
                    let driftFreq = baseFreq + sin(2.0 * .pi * 0.2 * t) * 200.0
                    phase += 2.0 * .pi * driftFreq / Float(format.sampleRate)
                    data[i] = sin(phase) * 0.05
                }
            }
        }
        self.heterodyneBuffer = buffer
    }

    private func playRogerBeep() {
        guard let buffer = beepBuffer else { return }
        beepPlayerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        beepPlayerNode.play()
    }

    private func playSquelchStart() {
        guard let buffer = noiseBuffer else { return }
        noisePlayerNode.volume = 0.4
        noisePlayerNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        noisePlayerNode.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.noisePlayerNode.volume = 0.04
        }
    }

    private func playSquelchEnd() {
        noisePlayerNode.volume = 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.noisePlayerNode.volume = 0.0
            self.noisePlayerNode.stop()
        }
    }

    public func setFilter(_ filter: RadioFilter) {
        currentFilter = filter
        prepareFilter(filter)
        if isMonitoring {
            if filter == .hamRadio {
                startHeterodyne()
            } else {
                stopHeterodyne()
            }
        }
    }

    private func startHeterodyne() {
        guard let buffer = heterodyneBuffer else { return }
        heterodynePlayerNode.volume = 0.1
        heterodynePlayerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        heterodynePlayerNode.play()
    }

    private func stopHeterodyne() {
        heterodynePlayerNode.stop()
    }

    private func prepareFilter(_ filter: RadioFilter) {
        distortionNode.bypass = true
        delayNode.bypass = true
        for i in 0..<3 { eqNode.bands[i].bypass = true }

        switch filter {
        case .amRadio:
            eqNode.bands[0].filterType = .highPass
            eqNode.bands[0].frequency = 300
            eqNode.bands[0].bypass = false
            eqNode.bands[1].filterType = .lowPass
            eqNode.bands[1].frequency = 3000
            eqNode.bands[1].bypass = false
            distortionNode.loadFactoryPreset(.multiBrokenSpeaker)
            distortionNode.preGain = -5
            distortionNode.wetDryMix = 20
            distortionNode.bypass = false
        case .fmVintage:
            eqNode.bands[0].filterType = .parametric
            eqNode.bands[0].frequency = 500
            eqNode.bands[0].gain = 6
            eqNode.bands[0].bypass = false
            distortionNode.loadFactoryPreset(.multiDistortedSquared)
            distortionNode.wetDryMix = 15
            distortionNode.bypass = false
        case .hamRadio:
            eqNode.bands[0].filterType = .highPass
            eqNode.bands[0].frequency = 500
            eqNode.bands[0].bypass = false
            eqNode.bands[1].filterType = .lowPass
            eqNode.bands[1].frequency = 2200
            eqNode.bands[1].bypass = false
            delayNode.delayTime = 0.02
            delayNode.feedback = 40
            delayNode.wetDryMix = 30
            delayNode.bypass = false
        }
    }

    // MARK: - Public playback API (debounced & queued)

    public func playTrack(at index: Int, autoPlay: Bool = true) {
        let now = Date()
        guard now.timeIntervalSince(lastTrackChangeTime) >= minTrackChangeInterval else {
            return
        }
        lastTrackChangeTime = now

        let safeIndex = max(0, min(availableTracks.count - 1, index))
        let trackToPlay = availableTracks[safeIndex]

        audioQueue.async { [weak self] in
            guard let self else { return }

            Task { @MainActor in
                self.selectedTrackIndex = safeIndex
            }

            if autoPlay {
                self.stopPlaybackInternal()
                self.playAudioInternal(atTrack: trackToPlay)
            }
        }
    }

    public func playNextTrack() {
        let nextIndex = (selectedTrackIndex + 1) % availableTracks.count
        playTrack(at: nextIndex, autoPlay: isPlaying)
        if isPlaying {
            showNowPlaying()
        }
    }

    public func playPreviousTrack() {
        let prevIndex = (selectedTrackIndex - 1 + availableTracks.count) % availableTracks.count
        playTrack(at: prevIndex, autoPlay: isPlaying || isPaused)
        if isPlaying || isPaused {
            showNowPlaying()
        }
    }

    public func showNowPlaying(message: String = "NOW PLAYING") {
        Task { @MainActor in
            self.nowPlayingMessage = message
            self.showNowPlayingOverlay = true
            self.nowPlayingTimer?.invalidate()
            self.nowPlayingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.showNowPlayingOverlay = false
            }
        }
    }

    public func playTestAudio() {
        let trackToPlay = selectedTrack
        audioQueue.async { [weak self] in
            self?.playTestAudioInternal(track: trackToPlay)
        }
    }

    private func playTestAudioInternal(track: AudioTrack) {
        if isPaused {
            resumePlaybackInternal()
            return
        }

        guard let url = getAudioURL(for: track) else {
            print("❌ Audio file not found for: \(track.title)")
            return
        }

        playAudioInternal(at: url)
    }

    private func playAudioInternal(atTrack track: AudioTrack) {
        guard let url = getAudioURL(for: track) else {
            print("❌ Audio file not found for: \(track.title)")
            Task { @MainActor in
                self.isPlaying = false
                self.isPaused = false
            }
            return
        }
        playAudioInternal(at: url)
    }

    private func playAudioInternal(at url: URL) {
        do {
            // Pre-flight check: Ensure file is actually accessible
            let _ = try AVAudioFile(forReading: url)
            
            let session = AVAudioSession.sharedInstance()
            if session.category != .playback {
                try session.setCategory(.playback, mode: .default, options: [])
            }
            try session.setActive(true)

            if isMonitoring {
                stopMonitoringInternal()
            }

            let file = try AVAudioFile(forReading: url)
            if !engine.isRunning {
                try engine.start()
            }

            let sessionID = UUID()
            self.currentSessionID = sessionID

            playerNode.stop()
            playerNode.reset()
            playerNode.scheduleFile(file, at: nil) { [weak self] in
                Task { @MainActor in
                    guard let self = self else { return }
                    // Only trigger completion logic if this session is still active
                    guard self.currentSessionID == sessionID else { return }
                    
                    if self.isPlaying && !self.isManualStopping {
                        self.playNextTrack()
                    } else {
                        self.isPlaying = false
                        self.isManualStopping = false
                    }
                }
            }
            playerNode.play()

            Task { @MainActor in
                self.isPlaying = true
                self.isPaused = false
            }

            print("▶️ Playing: \(url.lastPathComponent)")
        } catch {
            print("Error playing audio: \(error)")
            Task { @MainActor in
                self.isPlaying = false
                self.isPaused = false
            }
        }
    }

    private func stopMonitoringInternal() {
        engine.stop()
        engine.disconnectNodeInput(eqNode)
        engine.disconnectNodeInput(distortionNode)
        engine.disconnectNodeInput(delayNode)
        engine.disconnectNodeInput(mixerNode)

        let outputFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(playerNode, to: eqNode, format: outputFormat)
        engine.connect(eqNode, to: distortionNode, format: outputFormat)
        engine.connect(distortionNode, to: delayNode, format: outputFormat)
        engine.connect(delayNode, to: mixerNode, format: outputFormat)
        engine.connect(mixerNode, to: engine.mainMixerNode, format: outputFormat)

        noisePlayerNode.stop()
        stopHeterodyne()

        Task { @MainActor in
            self.isMonitoring = false
        }
    }

    private func getAudioURL(for track: AudioTrack) -> URL? {
        let bundle: Bundle = {
#if SWIFT_PACKAGE
            return Bundle.module
#else
            return Bundle.main
#endif
        }()

        let filename = track.filename
        return bundle.url(forResource: filename, withExtension: "mp3") ??
        bundle.url(forResource: filename, withExtension: "mp3", subdirectory: "Resources") ??
        bundle.url(forResource: filename, withExtension: "mp3", subdirectory: "Sounds")
    }

    private func debugListBundleResources() {
        let bundle: Bundle = {
#if SWIFT_PACKAGE
            return Bundle.module
#else
            return Bundle.main
#endif
        }()

        print("📦 Bundle URL:", bundle.bundleURL)

        if let resourcesURL = bundle.resourceURL,
           let files = try? FileManager.default.contentsOfDirectory(
            at: resourcesURL,
            includingPropertiesForKeys: nil
           ) {
            print("📂 Resources folder contents:")
            for url in files {
                print(" -", url.lastPathComponent)
            }
        } else {
            print("⚠️ Could not list bundle resources")
        }
    }

    public func pausePlayback() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            if self.isPlaying {
                self.isManualStopping = true
                self.playerNode.pause()
                self.noisePlayerNode.pause()
                Task { @MainActor in
                    self.isPlaying = false
                    self.isPaused = true
                }
            }
        }
    }

    public func resumePlayback() {
        audioQueue.async { [weak self] in
            self?.resumePlaybackInternal()
        }
    }

    private func resumePlaybackInternal() {
        if isPaused {
            if playerNode.isPlaying || engine.isRunning {
                playerNode.play()
                noisePlayerNode.play()
            } else {
                // If the player isn't actually ready to resume, just restart the track
                let track = selectedTrack
                playAudioInternal(atTrack: track)
                return
            }
            Task { @MainActor in
                self.isPlaying = true
                self.isPaused = false
            }
        } else if !isPlaying {
            // If not playing and not paused, start from beginning
            let track = selectedTrack
            playAudioInternal(atTrack: track)
        }
    }

    public func stopPlayback() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            self.isManualStopping = true
            self.stopPlaybackInternal()
        }
    }

    private func stopPlaybackInternal() {
        playerNode.stop()
        noisePlayerNode.stop()
        Task { @MainActor in
            self.isPlaying = false
            self.isPaused = false
            self.isManualStopping = false
        }
    }

    public func playSound(_ name: String, rate: Float? = nil) {
        let player: AVAudioPlayer? = {
            do {
                if let data = self.cachedSoundData[name] {
                    return try AVAudioPlayer(data: data)
                } else {
                    let bundle: Bundle = {
#if SWIFT_PACKAGE
                        return Bundle.module
#else
                        return Bundle.main
#endif
                    }()
                    guard let url = bundle.url(forResource: name, withExtension: "mp3") ??
                            bundle.url(forResource: name, withExtension: "mp3", subdirectory: "Resources") else {
                        return nil
                    }
                    return try AVAudioPlayer(contentsOf: url)
                }
            } catch {
                print("❌ Error initializing player: \(error)")
                return nil
            }
        }()

        guard let player = player else { return }
        player.prepareToPlay()

        Task { @MainActor in
            self.activeTickPlayers.removeAll { !$0.isPlaying }

            if name.contains("tick") {
                guard self.activeTickPlayers.count < self.maxTickPlayers else { return }
                player.volume = 0.1
                player.enableRate = true
                player.rate = rate ?? 1.0
                self.activeTickPlayers.append(player)
                player.play()
            } else {
                self.uiSoundPlayer = player
                self.uiSoundPlayer?.play()
            }
        }
    }

    public func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        switch style {
        case .light:
            lightHaptic.impactOccurred()
        case .medium:
            mediumHaptic.impactOccurred()
        default:
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
        }
    }
}
