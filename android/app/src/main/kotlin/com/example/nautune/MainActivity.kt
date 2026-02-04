package com.example.nautune

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.media.audiofx.Visualizer
import android.os.Bundle
import kotlin.math.*

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.nautune.audio_fft/methods"
    private val EVENT_CHANNEL = "com.nautune.audio_fft/events"
    
    private var visualizer: Visualizer? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVisualizer" -> {
                    val sessionId = call.argument<Int>("sessionId") ?: 0
                    startVisualizer(sessionId)
                    result.success(null)
                }
                "stopVisualizer" -> {
                    stopVisualizer()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                stopVisualizer()
            }
        })
    }

    private fun startVisualizer(sessionId: Int) {
        stopVisualizer()
        
        try {
            visualizer = Visualizer(sessionId).apply {
                captureSize = Visualizer.getCaptureSizeRange()[1] // Max size (typically 1024)
                setDataCaptureListener(object : Visualizer.OnDataCaptureListener {
                    override fun onWaveFormDataCapture(visualizer: Visualizer?, waveform: ByteArray?, samplingRate: Int) {}

                    override fun onFftDataCapture(visualizer: Visualizer?, fft: ByteArray?, samplingRate: Int) {
                        if (fft != null && eventSink != null) {
                            // samplingRate is in mHz (milli-Hertz)
                            val rateHz = if (samplingRate > 0) samplingRate / 1000 else 44100
                            processFft(fft, rateHz)
                        }
                    }
                }, Visualizer.getMaxCaptureRate(), false, true) // MAX capture rate for buttery smoothness
                enabled = true
            }
        } catch (e: Exception) {
            println("Visualizer failed to start: ${e.message}")
        }
    }

    private fun stopVisualizer() {
        visualizer?.enabled = false
        visualizer?.release()
        visualizer = null
    }

    // State for AGC and Temporal Smoothing
    private var refPeakDbEma = -40.0
    private var spectrumEma = DoubleArray(512)
    private var bassEma = 0.0
    private var midEma = 0.0
    private var trebleEma = 0.0

    private fun processFft(fft: ByteArray, samplingRate: Int) {
        val n = fft.size
        val numBins = n / 2
        val totalBins = numBins + 1
        val captureSize = n 
        val binWidth = samplingRate.toDouble() / captureSize.toDouble()

        // Ensure EMA array matches bin count
        if (spectrumEma.size != totalBins) {
            spectrumEma = DoubleArray(totalBins)
        }

        fun hzToBin(hz: Double): Int {
            val bin = (hz / binWidth).toInt()
            return bin.coerceIn(0, totalBins - 1)
        }

        // Frequency ranges matching Linux/PulseAudio implementation
        val b0 = hzToBin(20.0)
        val b1 = hzToBin(250.0)
        val m1 = hzToBin(4000.0)

        val mags = DoubleArray(totalBins)
        var maxMag = 0.0
        
        // 0. Correct Unpacking: 
        // Index 0 is DC (Re[0]), Index 1 is Nyquist (Re[N/2])
        // Indices 2k, 2k+1 are Re[k], Im[k]
        mags[0] = abs(fft[0].toDouble())
        mags[numBins] = abs(fft[1].toDouble())
        
        for (i in 1 until numBins) {
            val re = fft[2 * i].toDouble()
            val im = fft[2 * i + 1].toDouble()
            val mag = hypot(re, im)
            mags[i] = mag
        }

        // Find max magnitude for AGC (ignoring DC which can be high)
        for (i in 1 until totalBins) {
            if (mags[i] > maxMag) maxMag = mags[i]
        }

        // 1. Noise Gate: ignore very low-level noise
        val noiseThreshold = 4.0 
        if (maxMag < noiseThreshold) {
            val data = mapOf(
                "bass" to 0.0,
                "mid" to 0.0,
                "treble" to 0.0,
                "amplitude" to 0.0,
                "spectrum" to DoubleArray(1).toList()
            )
            runOnUiThread { eventSink?.success(data) }
            return
        }

        // 2. AGC Logic (Logarithmic/DB based)
        fun powerToDb(p: Double): Double {
            return 10.0 * log10(p + 1e-9)
        }

        val currentPeakDb = powerToDb(maxMag * maxMag)
        // Smooth the reference peak for AGC (Fast attack, slow decay)
        val agcAlpha = if (currentPeakDb > refPeakDbEma) 0.15 else 0.04
        refPeakDbEma = refPeakDbEma + agcAlpha * (currentPeakDb - refPeakDbEma)
        
        val headroomDb = 15.0 
        val rangeDb = 65.0    
        val topDb = refPeakDbEma + headroomDb
        val bottomDb = topDb - rangeDb

        fun normalizeDb(p: Double): Double {
            val db = powerToDb(p)
            return ((db - bottomDb) / rangeDb).coerceIn(0.0, 1.0)
        }

        fun getBandPower(start: Int, end: Int): Double {
            if (end <= start) return 0.0
            var sum = 0.0
            val s = start.coerceIn(0, totalBins - 1)
            val e = end.coerceIn(s + 1, totalBins)
            for (i in s until e) {
                sum += mags[i] * mags[i]
            }
            return sum / (e - s)
        }

        // 3. Calculate Bands with Temporal Smoothing (Fast attack, moderate decay)
        val bassIn = normalizeDb(getBandPower(b0, b1)).pow(1.2)
        val midIn = normalizeDb(getBandPower(b1, m1)).pow(1.2)
        val trebIn = normalizeDb(getBandPower(m1, totalBins)).pow(1.2)

        fun smooth(prev: Double, target: Double, attack: Double, decay: Double): Double {
            val alpha = if (target > prev) attack else decay
            return prev + alpha * (target - prev)
        }

        bassEma = smooth(bassEma, bassIn, 0.8, 0.4)
        midEma = smooth(midEma, midIn, 0.8, 0.4)
        trebleEma = smooth(trebleEma, trebIn, 0.8, 0.4)

        // 4. Spectrum Smoothing (Frequency-domain and Temporal)
        val spectrum = DoubleArray(totalBins)
        for (i in 0 until totalBins) {
            val raw = normalizeDb(mags[i] * mags[i]).pow(1.2)
            // Temporal smoothing for each bin - snappy attack, slower decay
            spectrumEma[i] = smooth(spectrumEma[i], raw, 0.85, 0.45)
            spectrum[i] = spectrumEma[i]
        }

        val amplitude = (maxMag / 128.0).coerceIn(0.0, 1.0)

        val data = mapOf(
            "bass" to bassEma,
            "mid" to midEma,
            "treble" to trebleEma,
            "amplitude" to amplitude,
            "spectrum" to spectrum.toList(),
            "sampleRate" to samplingRate
        )
        
        runOnUiThread {
            eventSink?.success(data)
        }
    }
}
