import Foundation
import Synchronization
import Testing
@testable import Ciao

final class FakeDiscovery: DiscoveryBackend {
    let events: AsyncThrowingStream<BackendDiscoveryEvent, Error>
    let continuation: AsyncThrowingStream<BackendDiscoveryEvent, Error>.Continuation
    let stops = Mutex(0)
    init() { (events, continuation) = AsyncThrowingStream.makeStream() }
    func stop() { stops.withLock { $0 += 1 }; continuation.finish() }
}
actor ResolverGate {
    let starts: AsyncStream<Service>
    private let continuation: AsyncStream<Service>.Continuation
    private var pending: [Service: CheckedContinuation<ResolvedService, Error>] = [:]
    init() { (starts, continuation) = AsyncStream.makeStream() }
    func resolve(_ service: Service) async throws -> ResolvedService {
        try await withCheckedThrowingContinuation { completion in
            pending[service] = completion; continuation.yield(service)
        }
    }
    func finish(_ service: Service, result: Result<ResolvedService, Error>) { pending.removeValue(forKey: service)?.resume(with: result) }
}

@Suite(.timeLimit(.minutes(1))) struct LifecycleTests {
    @Test func membershipAndStopClearState() async throws {
        let backend = FakeDiscovery()
        let session = DiscoverySession(backend: backend, automaticallyResolve: false) { _ in throw CiaoError.stopped }
        await session.activate()
        var iterator = session.events.makeAsyncIterator()
        let one = Service(name: "one", type: try .tcp("demo"))
        backend.continuation.yield(.started)
        #expect(try await iterator.next() == .started)
        backend.continuation.yield(.snapshot([one]))
        #expect(try await iterator.next() == .found(one))
        #expect(await session.services == [one])
        backend.continuation.yield(.snapshot([]))
        #expect(try await iterator.next() == .removed(one))
        await session.stop(); await session.stop()
        #expect(try await iterator.next() == .stopped)
        #expect(try await iterator.next() == nil)
        #expect(await session.services.isEmpty)
        #expect(backend.stops.withLock { $0 } == 1)
    }
    @Test func bufferedMembershipNeverDropsChanges() async throws {
        let backend = FakeDiscovery()
        let session = DiscoverySession(backend: backend, automaticallyResolve: false) { _ in throw CiaoError.stopped }
        await session.activate()
        let services = try (0..<300).map { Service(name: "\($0)", type: try .tcp("demo")) }
        for service in services { backend.continuation.yield(.snapshot([service])); backend.continuation.yield(.snapshot([])) }
        backend.continuation.finish()
        var found = 0; var removed = 0
        for try await event in session.events {
            if case .found = event { found += 1 }; if case .removed = event { removed += 1 }
        }
        #expect(found == 300); #expect(removed == 300)
    }
    @Test func removalSuppressesLateResolution() async throws {
        let backend = FakeDiscovery(); let gate = ResolverGate()
        let session = DiscoverySession(backend: backend, automaticallyResolve: true) { try await gate.resolve($0) }
        await session.activate()
        var events = session.events.makeAsyncIterator(); var starts = gate.starts.makeAsyncIterator()
        let one = Service(name: "one", type: try .tcp("demo"))
        backend.continuation.yield(.snapshot([one]))
        #expect(try await events.next() == .found(one)); #expect(await starts.next() == one)
        backend.continuation.yield(.snapshot([]))
        #expect(try await events.next() == .removed(one))
        await gate.finish(one, result: .success(ResolvedService(service: one, hostName: "host", port: 1, addresses: ["127.0.0.1"], txtRecord: .empty)))
        await session.stop()
        #expect(try await events.next() == .stopped); #expect(try await events.next() == nil)
    }
    @Test func automaticResolutionErrorsStayAssociatedWithService() async throws {
        let backend = FakeDiscovery()
        let session = DiscoverySession(backend: backend, automaticallyResolve: true) { _ in throw CiaoError.timedOut }
        await session.activate()
        var events = session.events.makeAsyncIterator()
        let one = Service(name: "one", type: try .tcp("demo"))
        backend.continuation.yield(.snapshot([one]))
        #expect(try await events.next() == .found(one))
        #expect(try await events.next() == .resolutionFailed(one, .timedOut))
        await session.stop()
    }
    @Test func discoveryFailureEndsStreamAndStopsBackend() async throws {
        let backend = FakeDiscovery()
        let session = DiscoverySession(backend: backend, automaticallyResolve: false) { _ in throw CiaoError.stopped }
        await session.activate()
        backend.continuation.finish(throwing: CiaoError.dnsService(-1))
        await #expect(throws: CiaoError.dnsService(-1)) { for try await _ in session.events {} }
        await session.stop()
        #expect(backend.stops.withLock { $0 } == 1)
    }
    @Test func taskCancellationStopsDiscovery() async throws {
        let backend = FakeDiscovery()
        let session = DiscoverySession(backend: backend, automaticallyResolve: false) { _ in throw CiaoError.stopped }
        await session.activate()
        let task = Task { for try await _ in session.events {} }
        task.cancel(); _ = try? await task.value
        await session.stop()
        #expect(backend.stops.withLock { $0 } == 1)
    }
    @Test func externalPortZeroRejectedBeforeBackendCreation() async throws {
        let server = CiaoServer(factory: { _ in Issue.record("Backend must not be created"); throw CiaoError.stopped })
        await #expect(throws: CiaoError.self) { try await server.start(PublicationConfiguration(type: .tcp("demo"), mode: .externalPort)) }
    }
    @Test func publicationFailureAfterStartupClearsState() async throws {
        let backend = FakePublication(); let server = CiaoServer(factory: { _ in backend })
        let task = Task { try await server.start(PublicationConfiguration(type: .tcp("demo"))) }
        var started = backend.started.makeAsyncIterator(); _ = await started.next()
        try await backend.succeed(); let publication = try await task.value
        var events = server.events.makeAsyncIterator()
        #expect(await events.next() == .started(publication))
        await backend.fail(.dnsService(-1))
        #expect(await events.next() == .failed(.dnsService(-1)))
        #expect(await events.next() == .stopped)
        #expect(await server.publishedService == nil)
        await server.stop()
    }
    @Test func cancelledStartupDoesNotCommitPublication() async throws {
        let backend = FakePublication()
        let server = CiaoServer(factory: { _ in backend })
        let task = Task { try await server.start(PublicationConfiguration(type: .tcp("demo"))) }
        var started = backend.started.makeAsyncIterator(); _ = await started.next()
        task.cancel(); try await backend.succeed()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await server.publishedService == nil)
    }
    @Test func overlappingStartupKeepsOnlyLatestPublication() async throws {
        let first = FakePublication(); let second = FakePublication()
        let backends = Mutex([first, second])
        let server = CiaoServer(factory: { _ in backends.withLock { $0.removeFirst() } })
        let oldTask = Task { try await server.start(PublicationConfiguration(type: .tcp("demo"))) }
        var firstStarted = first.started.makeAsyncIterator(); _ = await firstStarted.next()
        let newTask = Task { try await server.start(PublicationConfiguration(type: .tcp("demo"))) }
        var secondStarted = second.started.makeAsyncIterator(); _ = await secondStarted.next()
        try await second.succeed(); let latest = try await newTask.value
        try await first.succeed()
        await #expect(throws: CiaoError.stopped) { try await oldTask.value }
        #expect(await server.publishedService == latest)
        await server.stop()
    }
    @Test func stopDuringStartupRejectsLateSuccess() async throws {
        let backend = FakePublication()
        let server = CiaoServer(factory: { _ in backend })
        let task = Task { try await server.start(PublicationConfiguration(type: .tcp("demo"))) }
        var started = backend.started.makeAsyncIterator(); _ = await started.next()
        await server.stop()
        try await backend.succeed()
        await #expect(throws: CiaoError.stopped) { try await task.value }
        #expect(await server.publishedService == nil)
    }
}
actor FakePublication: PublicationBackend {
    nonisolated let failures: AsyncStream<CiaoError>
    private let failureContinuation: AsyncStream<CiaoError>.Continuation
    nonisolated let started: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    private var completion: CheckedContinuation<PublishedService, Error>?
    init() {
        (started, continuation) = AsyncStream.makeStream()
        (failures, failureContinuation) = AsyncStream.makeStream()
    }
    func fail(_ error: CiaoError) { failureContinuation.yield(error) }
    func start(timeout: Duration) async throws -> PublishedService {
        try await withCheckedThrowingContinuation { completion in self.completion = completion; continuation.yield(()) }
    }
    func succeed() throws {
        completion?.resume(returning: PublishedService(service: Service(name: "demo", type: try .tcp("demo")), port: 42)); completion = nil
    }
    func updateTXT(_ record: TXTRecord) {}
    func stop() {}
}
