import Foundation
import Synchronization
import Testing
@testable import Ciao

/// A deterministic clock: tests advance the deadline instead of waiting for wall time.
private final class TestClock: Clock, Sendable {
    struct Instant: InstantProtocol {
        var offset: Duration
        func advanced(by duration: Duration) -> Self { Self(offset: offset + duration) }
        func duration(to other: Self) -> Duration { other.offset - offset }
        static func < (lhs: Self, rhs: Self) -> Bool { lhs.offset < rhs.offset }
    }
    private struct Waiter { let deadline: Instant; let continuation: CheckedContinuation<Void, Error> }
    private struct State {
        var now = Instant(offset: .zero)
        var waiters: [UUID: Waiter] = [:]
        var cancelled: Set<UUID> = []
    }
    private let state = Mutex(State())
    let registrations: AsyncStream<Void>
    private let registered: AsyncStream<Void>.Continuation
    init() { (registrations, registered) = AsyncStream.makeStream() }
    var now: Instant { state.withLock { $0.now } }
    var minimumResolution: Duration { .nanoseconds(1) }
    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (completion: CheckedContinuation<Void, Error>) in
                let outcome: Int = state.withLock {
                    if $0.cancelled.remove(id) != nil || Task.isCancelled { return 1 }
                    if deadline <= $0.now { return 2 }
                    $0.waiters[id] = Waiter(deadline: deadline, continuation: completion); return 0
                }
                if outcome == 1 { completion.resume(throwing: CancellationError()) }
                else if outcome == 2 { completion.resume() }
                registered.yield(())
            }
        } onCancel: {
            let waiter: Waiter? = self.state.withLock {
                if let waiter = $0.waiters.removeValue(forKey: id) { return waiter }
                $0.cancelled.insert(id); return nil
            }
            waiter?.continuation.resume(throwing: CancellationError())
        }
    }
    func advance(by duration: Duration) {
        let ready = state.withLock {
            $0.now = $0.now.advanced(by: duration)
            let now = $0.now
            let ready = $0.waiters.filter { $0.value.deadline <= now }
            for key in ready.keys { $0.waiters.removeValue(forKey: key) }
            return ready.values.map(\.continuation)
        }
        for continuation in ready { continuation.resume() }
    }
}
@Suite(.timeLimit(.minutes(1))) struct DeadlineTests {
    @Test func timeoutUsesControlledClockAndCancelsWork() async throws {
        let clock = TestClock()
        let (work, continuation) = AsyncStream<Int>.makeStream()
        let task = Task {
            try await withDeadline(.seconds(10), clock: clock) {
                for await value in work { return value }
                throw CancellationError()
            }
        }
        var registrations = clock.registrations.makeAsyncIterator()
        _ = await registrations.next()
        clock.advance(by: .seconds(10))
        await #expect(throws: CiaoError.timedOut) { try await task.value }
        continuation.finish()
    }
    @Test func successCancelsDeadline() async throws {
        let clock = TestClock()
        let result = try await withDeadline(.seconds(10), clock: clock) { 42 }
        #expect(result == 42)
        clock.advance(by: .seconds(10))
    }
    @Test func invalidTimeoutAndPrecancelledResolutionAllocateNoNetworkWork() async throws {
        await #expect(throws: CiaoError.self) { try await withDeadline(.zero) { 1 } }
        let service = Service(name: "missing", type: try .tcp("demo"))
        await #expect(throws: CiaoError.self) { try await CiaoResolver.resolve(service, timeout: .zero) }
        let task = Task { withUnsafeCurrentTask { $0?.cancel() }; return try await CiaoResolver.resolve(service) }
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
