import Foundation
import CoreAudio

struct AudioDeviceChoice: Identifiable { let id: AudioDeviceID; let name: String }
enum AudioHardware {
    static func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, channel: UInt32 = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress { AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: channel) }
    static func integer(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, channel: UInt32 = 0) -> UInt32? {
        var property = address(selector, scope: scope, channel: channel), value: UInt32 = 0, size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(object, &property, 0, nil, &size, &value) == noErr else { return nil }; return value
    }
    static func setInteger(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, value: UInt32, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, channel: UInt32 = 0) -> Bool {
        var property = address(selector, scope: scope, channel: channel), value = value
        return AudioObjectSetPropertyData(object, &property, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr
    }
    static func scalar(_ object: AudioObjectID, channel: UInt32) -> Float32? {
        var property = address(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput, channel: channel), value: Float32 = 0, size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(object, &property, 0, nil, &size, &value) == noErr else { return nil }; return value
    }
    static func setScalar(_ object: AudioObjectID, channel: UInt32, value: Float32) -> Bool {
        var property = address(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput, channel: channel), value = value
        return AudioObjectSetPropertyData(object, &property, 0, nil, UInt32(MemoryLayout<Float32>.size), &value) == noErr
    }
    static func objects(_ selector: AudioObjectPropertySelector, object: AudioObjectID = AudioObjectID(kAudioObjectSystemObject), scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> [AudioObjectID] {
        var property = address(selector, scope: scope), size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &property, 0, nil, &size) == noErr else { return [] }
        var values = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard !values.isEmpty, AudioObjectGetPropertyData(object, &property, 0, nil, &size, &values) == noErr else { return [] }; return values
    }
    static func name(_ object: AudioObjectID) -> String {
        var property = address(kAudioObjectPropertyName), value: Unmanaged<CFString>?, size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &property, 0, nil, &size, &value) == noErr, let value else { return "Microphone" }; return value.takeRetainedValue() as String
    }
    static var inputs: [AudioDeviceChoice] {
        objects(kAudioHardwarePropertyDevices).filter { !objects(kAudioDevicePropertyStreams, object: $0, scope: kAudioDevicePropertyScopeInput).isEmpty }.map { AudioDeviceChoice(id: $0, name: name($0)) }
    }
    static var defaultInput: AudioDeviceID { integer(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultInputDevice) ?? 0 }
    static func setInput(_ device: AudioDeviceID) -> Bool { setInteger(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultInputDevice, value: device) }
}

/// Saves exact output state and only restores values that are still set by us.
@MainActor final class OutputMute: OutputMuting {
    enum Saved { case mute(UInt32); case volume([(UInt32, Float32)]) }
    var saved: [AudioDeviceID: Saved] = [:]
    var lastDevice: AudioDeviceID?
    var isEngaged = false
    func mute() throws { isEngaged = true; do { try refreshForCurrentDevice() } catch { restore(); throw error } }
    func refreshForCurrentDevice() throws {
        guard isEngaged, let device = AudioHardware.integer(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice), device != 0 else { return }
        guard device != lastDevice else { return }
        lastDevice = device
        if saved[device] != nil { return }
        if let mute = AudioHardware.integer(device, kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput), AudioHardware.setInteger(device, kAudioDevicePropertyMute, value: 1, scope: kAudioDevicePropertyScopeOutput) {
            saved[device] = .mute(mute); return
        }
        var channels: [(UInt32, Float32)] = []
        for channel in UInt32(0)...UInt32(16) {
            if let value = AudioHardware.scalar(device, channel: channel), AudioHardware.setScalar(device, channel: channel, value: 0) {
                channels.append((channel, value)); if channel == 0 { break }
            }
        }
        guard !channels.isEmpty else { throw flowError("This audio output cannot be muted by macOS. Use the output device’s mute control or choose another output.") }
        saved[device] = .volume(channels)
    }
    func restore() {
        isEngaged = false
        for (device, state) in saved {
            switch state {
            case .mute(let original):
                if AudioHardware.integer(device, kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput) == 1 { _ = AudioHardware.setInteger(device, kAudioDevicePropertyMute, value: original, scope: kAudioDevicePropertyScopeOutput) }
            case .volume(let channels):
                for (channel, original) in channels where AudioHardware.scalar(device, channel: channel) == 0 { _ = AudioHardware.setScalar(device, channel: channel, value: original) }
            }
        }
        saved = [:]; lastDevice = nil
    }
}
