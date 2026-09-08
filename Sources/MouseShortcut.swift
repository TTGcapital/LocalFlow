import AppKit

final class MouseShortcut {
    let button: Int64
    let action: @MainActor (Bool) -> Void
    var tap: CFMachPort?
    var source: CFRunLoopSource?
    init?(button: Int, action: @escaping @MainActor (Bool) -> Void) {
        self.button = Int64(button); self.action = action
        let mask = (CGEventMask(1) << CGEventType.otherMouseDown.rawValue) | (CGEventMask(1) << CGEventType.otherMouseUp.rawValue)
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, pointer in
            guard let pointer else { return Unmanaged.passUnretained(event) }
            let hook = Unmanaged<MouseShortcut>.fromOpaque(pointer).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = hook.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard event.getIntegerValueField(.mouseEventButtonNumber) == hook.button else { return Unmanaged.passUnretained(event) }
            let down = type == .otherMouseDown
            Task { @MainActor in hook.action(down) }
            // Consume both edges so dictation does not also navigate back/forward.
            return nil
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { return nil }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
    }
    deinit { stop() }
}
