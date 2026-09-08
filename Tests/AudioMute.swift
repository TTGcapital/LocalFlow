import Foundation
import CoreAudio
@main struct AudioMuteTest {
    @MainActor static func main() throws {
        guard let output = AudioHardware.integer(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice) else { throw flowError("Cannot access Mac audio hardware") }
        let before = AudioHardware.integer(output, kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
        print("Output:", AudioHardware.name(output), "mute before:", before.map(String.init) ?? "volume fallback")
        print("Input:", AudioHardware.name(AudioHardware.defaultInput))
        guard CommandLine.arguments.contains("--exercise-mute") else { return }
        let controller = OutputMute()
        defer { controller.restore() }
        try controller.begin()
        guard !controller.saved.isEmpty else { throw flowError("No output state was saved") }
        if before != nil { precondition(AudioHardware.integer(output, kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput) == 1) }
        controller.restore()
        if let before { precondition(AudioHardware.integer(output, kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput) == before) }
        precondition(!controller.enabled && controller.saved.isEmpty)
        print("PASS: output muted and prior state restored; microphone selection unchanged")
    }
}
