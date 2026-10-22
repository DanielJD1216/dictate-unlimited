import AVFoundation
import Foundation
import CoreAudio
import AudioToolbox
import DictateCore

final class AudioCapture: @unchecked Sendable {
    private var engine: AVAudioEngine?
    private let lock = NSLock()
    private var samples: [Float] = []
    private var level: Float = 0
    private var count = 0
    private var generation: UInt64 = 0
    private var accepting = false
    private var conversionError: String?
    private var running = false
    @MainActor var onInterruption: (() -> Void)?
    private var configurationObserver: NSObjectProtocol?
    deinit { if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) } }
    func start(deviceID: UInt32? = nil, monitoring: Bool = false) throws {
        guard !running else { throw AppError("Microphone is already active.") }
        let engine = AVAudioEngine()
        self.engine = engine
        let input = engine.inputNode
        if var deviceID {
            guard let unit=input.audioUnit else { throw AppError("Microphone input unit is unavailable.") }
            let status=AudioUnitSetProperty(unit,kAudioOutputUnitProperty_CurrentDevice,kAudioUnitScope_Global,0,&deviceID,UInt32(MemoryLayout<UInt32>.size))
            guard status==noErr else { throw AppError("Cannot use the selected microphone (\(status)). Refresh inputs and try again.") }
        }
        let source = input.outputFormat(forBus: 0)
        guard source.sampleRate > 0, source.channelCount > 0,
              let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: source, to: target) else { throw AppError("No usable microphone input. Check System Settings → Sound.") }
        lock.lock(); samples = []; count = 0; level = 0; conversionError = nil; generation &+= 1; let activeGeneration=generation; accepting=true; lock.unlock()
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        configurationObserver = NotificationCenter.default.addObserver(forName:.AVAudioEngineConfigurationChange,object:engine,queue:.main) { [weak self, weak engine] _ in
            Task { @MainActor [weak self, weak engine] in
                guard let self, let engine, self.engine === engine, self.running, !engine.isRunning else { return }
                self.onInterruption?()
            }
        }
        input.installTap(onBus: 0, bufferSize: 4096, format: source) { [weak self] buffer, _ in
            guard let self else { return }
            let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * 16000 / source.sampleRate) + 64)
            guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
            var supplied = false; var error: NSError?
            converter.convert(to: output, error: &error) { _, status in
                if supplied { status.pointee = .noDataNow; return nil }
                supplied = true; status.pointee = .haveData; return buffer
            }
            self.lock.lock(); defer { self.lock.unlock() }
            guard self.accepting, self.generation == activeGeneration else { return }
            if let error { self.conversionError = error.localizedDescription; return }
            if let ptr = output.floatChannelData?[0] {
                let n = Int(output.frameLength)
                let remaining = AudioLimits.sampleRate * (monitoring ? 5 : AudioLimits.maximumSeconds) - self.count
                let values = Array(UnsafeBufferPointer(start: ptr, count: min(n, max(remaining, 0))))
                if !monitoring { self.samples.append(contentsOf: values) }
                self.count += values.count
                self.level = values.isEmpty ? 0 : sqrt(values.reduce(0) { $0 + $1 * $1 } / Float(values.count))
            }
        }
        do { try engine.start(); running = true }
        catch { input.removeTap(onBus: 0); lock.lock(); accepting=false; lock.unlock(); self.engine=nil; throw error }
    }
    func snapshot() -> (count: Int, level: Float) { lock.lock(); defer { lock.unlock() }; return (count, level) }
    func stop() throws -> [Float] {
        if running, let engine { running=false; engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver); self.configurationObserver=nil }
        engine=nil
        lock.lock(); accepting=false; defer { samples = []; count = 0; level = 0; lock.unlock() }
        if let conversionError { throw AppError(conversionError) }
        return samples
    }
    func cancel() { _ = try? stop() }
}
