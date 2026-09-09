import Foundation

/// Input-only state machine. A quick double tap latches; holding records until release.
struct ShortcutGesture {
    enum Phase: Equatable { case idle, pressed, awaitingSecondTap, latched, stopping }
    enum Action: Equatable { case start, stop, latch, scheduleRelease, cancelRelease }
    private(set) var phase: Phase = .idle
    private var downAt: TimeInterval = 0
    private var releasedAt: TimeInterval = 0
    let doubleTapWindow: TimeInterval = 0.32
    let holdThreshold: TimeInterval = 0.28
    mutating func down(at time: TimeInterval) -> [Action] {
        switch phase {
        case .idle: phase = .pressed; downAt = time; return [.start]
        case .awaitingSecondTap:
            if time - releasedAt <= doubleTapWindow { phase = .latched; return [.cancelRelease, .latch] }
            phase = .stopping; return [.cancelRelease, .stop]
        case .latched: phase = .stopping; return [.stop]
        case .pressed, .stopping: return [] // Ignore key repeat and stop-key release.
        }
    }
    mutating func up(at time: TimeInterval) -> [Action] {
        guard phase == .pressed else { return [] }
        if time - downAt >= holdThreshold { phase = .stopping; return [.stop] }
        phase = .awaitingSecondTap; releasedAt = time; return [.scheduleRelease]
    }
    mutating func releaseExpired() -> [Action] {
        guard phase == .awaitingSecondTap else { return [] }
        phase = .stopping; return [.stop]
    }
    mutating func reset() { phase = .idle }
    mutating func latch() { phase = .latched }
}
