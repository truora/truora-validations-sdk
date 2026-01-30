import Foundation
import XCTest
@testable import TruoraValidationsSDK

/// Mock time provider for deterministic testing - tests manually control time
@MainActor
final class MockTimeProvider: TimeProvider {
    private(set) var scheduledTimerCalls: [(interval: TimeInterval, repeats: Bool, block: (Timer) -> Void)] = []
    private(set) var sleepCalls: [UInt64] = []
    private var sleepContinuations: [CheckedContinuation<Void, Error>] = []
    var currentTime: Date = .init()
    var sleepCalledExpectation: XCTestExpectation?

    var now: Date {
        currentTime
    }

    nonisolated func scheduledTimer(
        withTimeInterval interval: TimeInterval,
        repeats: Bool,
        block: @escaping @Sendable (Timer) -> Void
    ) -> Timer {
        // Store for later - tests will fire manually
        MainActor.assumeIsolated {
            scheduledTimerCalls.append((interval, repeats, block))
        }
        return Timer() // Dummy timer
    }

    nonisolated func sleep(nanoseconds: UInt64) async throws {
        await MainActor.run {
            sleepCalls.append(nanoseconds)
            sleepCalledExpectation?.fulfill()
        }
        // Suspend until continuation is resumed
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                sleepContinuations.append(continuation)
            }
        }
    }

    /// Resume the oldest sleep call
    func resumeSleep(at index: Int = 0) {
        guard index < sleepContinuations.count else { return }
        let continuation = sleepContinuations.remove(at: index)
        continuation.resume()
    }

    /// Resume all sleep calls
    func resumeAllSleeps() {
        sleepContinuations.forEach { $0.resume() }
        sleepContinuations.removeAll()
    }

    /// Fire the timer at specified index once
    func fireTimer(at index: Int = 0) {
        guard index < scheduledTimerCalls.count else { return }
        scheduledTimerCalls[index].block(Timer())
    }

    /// Fire timer multiple times (for repeating timers like countdown)
    func fireTimer(at index: Int = 0, times: Int) {
        for _ in 0 ..< times {
            fireTimer(at: index)
        }
    }

    /// Reset all captured calls
    func reset() {
        scheduledTimerCalls.removeAll()
        sleepCalls.removeAll()
        // Resume any pending sleeps to avoid hanging tests
        resumeAllSleeps()
    }
}
