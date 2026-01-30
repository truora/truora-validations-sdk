import Foundation

/// Protocol for abstracting time-based operations to enable deterministic testing
protocol TimeProvider: Sendable {
    var now: Date { get }

    func scheduledTimer(
        withTimeInterval interval: TimeInterval,
        repeats: Bool,
        block: @escaping @Sendable (Timer) -> Void
    ) -> Timer

    func sleep(nanoseconds: UInt64) async throws
}

/// Default implementation using real system timers
final class RealTimeProvider: TimeProvider, Sendable {
    var now: Date {
        Date()
    }

    func scheduledTimer(
        withTimeInterval interval: TimeInterval,
        repeats: Bool,
        block: @escaping @Sendable (Timer) -> Void
    ) -> Timer {
        // Create timer and explicitly add to main run loop to ensure it fires
        // even when called from async contexts which may not have an active run loop
        let timer = Timer(timeInterval: interval, repeats: repeats) { timer in
            block(timer)
        }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    func sleep(nanoseconds: UInt64) async throws {
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
