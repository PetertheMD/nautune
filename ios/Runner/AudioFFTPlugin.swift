import Flutter
import AVFoundation
import Accelerate

/// Native iOS FFT plugin using AVAudioEngine and Accelerate framework.
/// Captures app's audio output and performs real-time FFT analysis.
public class AudioFFTPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?
    private var audioEngine: AVAudioEngine?
    private var isCapturing = false

    // FFT setup
    private var fftSetup: FFTSetup?
    private let fftSize: Int = 1024
    private var log2n: vDSP_Length = 0

    // Smoothing
    private var peakHistory: Float = 0.1

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = AudioFFTPlugin()

        // Method channel for start/stop commands
        let methodChannel = FlutterMethodChannel(
            name: "com.nautune.audio_fft/methods",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        // Event channel for streaming FFT data
        let eventChannel = FlutterEventChannel(
            name: "com.nautune.audio_fft/events",
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)

        print("🎵 AudioFFTPlugin: Registered")
    }

    override init() {
        super.init()
        log2n = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
    }

    deinit {
        stopCapture()
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    // MARK: - FlutterPlugin

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startCapture":
            startCapture()
            result(true)
        case "stopCapture":
            stopCapture()
            result(true)
        case "isAvailable":
            result(true)  // iOS always supports this
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - FlutterStreamHandler

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        print("🎵 AudioFFTPlugin: Event sink connected")
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        print("🎵 AudioFFTPlugin: Event sink disconnected")
        return nil
    }

    // MARK: - Audio Capture

    private func startCapture() {
        guard !isCapturing else { return }

        do {
            // Configure audio session for playback monitoring
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            audioEngine = AVAudioEngine()
            guard let engine = audioEngine else { return }

            let mainMixer = engine.mainMixerNode
            let format = mainMixer.outputFormat(forBus: 0)

            // Install tap on main mixer to capture all audio output
            mainMixer.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: format) { [weak self] buffer, time in
                self?.processAudioBuffer(buffer)
            }

            try engine.start()
            isCapturing = true
            print("🎵 AudioFFTPlugin: Capture started")

        } catch {
            print("🎵 AudioFFTPlugin: Failed to start - \(error)")
        }
    }

    private func stopCapture() {
        guard isCapturing else { return }

        audioEngine?.mainMixerNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isCapturing = false

        // Send zero values
        sendFFTData(bass: 0, mid: 0, treble: 0, amplitude: 0)
        print("🎵 AudioFFTPlugin: Capture stopped")
    }

    // MARK: - FFT Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0],
              let setup = fftSetup else { return }

        let frameCount = Int(buffer.frameLength)
        guard frameCount >= fftSize else { return }

        // Get samples
        var samples = [Float](repeating: 0, count: fftSize)
        for i in 0..<fftSize {
            samples[i] = channelData[i]
        }

        // Apply Hanning window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(samples, 1, window, 1, &samples, 1, vDSP_Length(fftSize))

        // Prepare for FFT (split complex)
        var realp = [Float](repeating: 0, count: fftSize / 2)
        var imagp = [Float](repeating: 0, count: fftSize / 2)

        realp.withUnsafeMutableBufferPointer { realPtr in
            imagp.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)

                samples.withUnsafeBufferPointer { samplesPtr in
                    samplesPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                    }
                }

                // Perform FFT
                vDSP_fft_zrip(setup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                // Calculate magnitudes
                var magnitudes = [Float](repeating: 0, count: fftSize / 2)
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

                // Convert to decibels and normalize
                var scaledMagnitudes = [Float](repeating: 0, count: fftSize / 2)
                var scale = Float(1.0 / Float(fftSize))
                vDSP_vsmul(magnitudes, 1, &scale, &scaledMagnitudes, 1, vDSP_Length(fftSize / 2))

                // Extract frequency bands
                let spectrumSize = fftSize / 2
                let bassEnd = Int(Float(spectrumSize) * 0.04)      // ~0-180Hz
                let midEnd = Int(Float(spectrumSize) * 0.20)       // ~180-2000Hz

                let bass = self.averageRange(scaledMagnitudes, start: 0, end: bassEnd) * 30.0
                let mid = self.averageRange(scaledMagnitudes, start: bassEnd, end: midEnd) * 40.0
                let treble = self.averageRange(scaledMagnitudes, start: midEnd, end: spectrumSize) * 80.0

                // Calculate amplitude (RMS)
                var rms: Float = 0
                vDSP_rmsqv(samples, 1, &rms, vDSP_Length(self.fftSize))
                let amplitude = min(rms * 2.0, 1.0)

                // Send to Flutter
                self.sendFFTData(
                    bass: min(bass, 1.0),
                    mid: min(mid, 1.0),
                    treble: min(treble, 1.0),
                    amplitude: amplitude
                )
            }
        }
    }

    private func averageRange(_ data: [Float], start: Int, end: Int) -> Float {
        guard end > start && !data.isEmpty else { return 0 }
        let safeStart = max(0, min(start, data.count))
        let safeEnd = max(safeStart, min(end, data.count))
        guard safeEnd > safeStart else { return 0 }

        var sum: Float = 0
        for i in safeStart..<safeEnd {
            sum += sqrt(data[i])  // sqrt for better visual scaling
        }
        return sum / Float(safeEnd - safeStart)
    }

    private func sendFFTData(bass: Float, mid: Float, treble: Float, amplitude: Float) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?([
                "bass": Double(bass),
                "mid": Double(mid),
                "treble": Double(treble),
                "amplitude": Double(amplitude)
            ])
        }
    }
}
