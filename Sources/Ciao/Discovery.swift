import Foundation
import Network

/// Internal seam lets lifecycle tests drive snapshots and failures without Bonjour.
protocol DiscoveryBackend: Sendable {
    var events: AsyncThrowingStream<BackendDiscoveryEvent, Error> { get }
    func stop()
}
enum BackendDiscoveryEvent: Sendable { case started; case snapshot(Set<Service>) }

private final class NetworkDiscovery: DiscoveryBackend {
    let events: AsyncThrowingStream<BackendDiscoveryEvent, Error>
    private let browser: NWBrowser
    private let continuation: AsyncThrowingStream<BackendDiscoveryEvent, Error>.Continuation
    init(type: ServiceType, domain: String) {
        (events, continuation) = AsyncThrowingStream.makeStream()
        browser = NWBrowser(for: .bonjour(type: type.rawValue, domain: domain.isEmpty ? nil : domain), using: .init())
        let continuation = continuation
        browser.stateUpdateHandler = { state in
            switch state {
            case .ready: continuation.yield(.started)
            case .failed(let error), .waiting(let error): continuation.finish(throwing: CiaoError.network(String(describing: error)))
            case .cancelled: continuation.finish()
            default: break
            }
        }
        browser.browseResultsChangedHandler = { results, _ in
            var services: Set<Service> = []
            for result in results {
                guard case .service(let name, let rawType, let domain, _) = result.endpoint,
                      let type = try? ServiceType(rawType) else { continue }
                let indexes = result.interfaces.map { UInt32($0.index) }
                for index in indexes.isEmpty ? [0] : indexes {
                    services.insert(Service(name: name, type: type, domain: domain, interfaceIndex: index))
                }
            }
            continuation.yield(.snapshot(services))
        }
        browser.start(queue: DispatchQueue(label: "Ciao.Discovery"))
    }
    func stop() { browser.cancel(); continuation.finish() }
    deinit { browser.cancel(); continuation.finish() }
}

/// Owns one discovery lifetime. Always call stop after an early loop exit.
/// Events are unbounded so membership changes are never silently dropped.
public actor DiscoverySession {
    public nonisolated let events: AsyncThrowingStream<DiscoveryEvent, Error>
    public private(set) var services: Set<Service> = []
    private let continuation: AsyncThrowingStream<DiscoveryEvent, Error>.Continuation
    private let backend: any DiscoveryBackend
    private let resolver: @Sendable (Service) async throws -> ResolvedService
    private let automaticallyResolve: Bool
    private var consumer: Task<Void, Never>?
    private var resolutions: [Service: (UUID, Task<Void, Never>)] = [:]
    private var stopped = false

    init(backend: any DiscoveryBackend, automaticallyResolve: Bool,
         resolver: @escaping @Sendable (Service) async throws -> ResolvedService) {
        self.backend = backend; self.automaticallyResolve = automaticallyResolve; self.resolver = resolver
        (events, continuation) = AsyncThrowingStream.makeStream()
    }
    func activate() {
        continuation.onTermination = { [weak self] _ in Task { await self?.stop() } }
        consumer = Task { [weak self, backend] in
            do {
                for try await event in backend.events {
                    guard !Task.isCancelled else { break }
                    await self?.receive(event)
                }
                await self?.stop()
            } catch { await self?.fail(error) }
        }
    }
    private func receive(_ event: BackendDiscoveryEvent) {
        guard !stopped else { return }
        switch event {
        case .started: continuation.yield(.started)
        case .snapshot(let next):
            // Remove before add, and cancel resolution before emitting removal.
            for service in services.subtracting(next).sorted(by: serviceOrder) {
                resolutions.removeValue(forKey: service)?.1.cancel()
                continuation.yield(.removed(service))
            }
            for service in next.subtracting(services).sorted(by: serviceOrder) {
                continuation.yield(.found(service))
                if automaticallyResolve {
                    let token = UUID()
                    let task = Task { [weak self, resolver] in
                        do { let result = try await resolver(service); await self?.resolved(result, token: token) }
                        catch { await self?.resolutionFailed(service, error: error, token: token) }
                    }
                    resolutions[service] = (token, task)
                }
            }
            services = next
        }
    }
    private func resolved(_ result: ResolvedService, token: UUID) {
        guard !stopped, services.contains(result.service), resolutions[result.service]?.0 == token else { return }
        resolutions.removeValue(forKey: result.service)
        continuation.yield(.resolved(result))
    }
    private func resolutionFailed(_ service: Service, error: Error, token: UUID) {
        guard !stopped, services.contains(service), resolutions[service]?.0 == token else { return }
        resolutions.removeValue(forKey: service)
        if !(error is CancellationError) { continuation.yield(.resolutionFailed(service, error as? CiaoError ?? .network(String(describing: error)))) }
    }
    private func fail(_ error: Error) {
        guard !stopped else { return }
        continuation.finish(throwing: error)
        stop()
    }
    public func stop() {
        guard !stopped else { return }
        stopped = true
        backend.stop(); consumer?.cancel(); consumer = nil
        for (_, task) in resolutions.values { task.cancel() }
        resolutions.removeAll(); services.removeAll()
        continuation.yield(.stopped); continuation.finish()
    }
    deinit { backend.stop(); consumer?.cancel(); for (_, task) in resolutions.values { task.cancel() }; continuation.finish() }
}
private func serviceOrder(_ lhs: Service, _ rhs: Service) -> Bool {
    (lhs.domain, lhs.type.rawValue, lhs.name, lhs.interfaceIndex) < (rhs.domain, rhs.type.rawValue, rhs.name, rhs.interfaceIndex)
}

/// A reusable browser. Starting a search stops its previous session and clears membership.
public actor CiaoBrowser {
    private var active: DiscoverySession?
    private var generation = UUID()
    public init() {}
    public func browse(type: ServiceType, domain: String = "", automaticallyResolve: Bool = true,
                       resolutionTimeout: Duration = .seconds(10)) async throws -> DiscoverySession {
        try Task.checkCancellation()
        guard resolutionTimeout > .zero else { throw CiaoError.invalidConfiguration("Timeout must be positive") }
        let token = UUID(); generation = token
        let previous = active; active = nil
        await previous?.stop()
        guard token == generation else { throw CiaoError.stopped }
        try Task.checkCancellation()
        let session = DiscoverySession(backend: NetworkDiscovery(type: type, domain: domain), automaticallyResolve: automaticallyResolve) {
            try await CiaoResolver.resolve($0, timeout: resolutionTimeout)
        }
        active = session
        await session.activate()
        guard token == generation else { await session.stop(); throw CiaoError.stopped }
        if Task.isCancelled { await session.stop(); throw CancellationError() }
        return session
    }
    public func stop() async { generation = UUID(); let previous = active; active = nil; await previous?.stop() }
    deinit { if let active { Task { await active.stop() } } }
}

/// Enumerates service types via DNS-SD. Broad enumeration on iOS requires multicast entitlement approval.
public final class ServiceTypeSession: Sendable {
    public let types: AsyncThrowingStream<ServiceType, Error>
    private let operation: DNSOperation
    private let task: Task<Void, Never>
    public init(domain: String = "") {
        let operation = DNSOperation()
        self.operation = operation
        let (stream, continuation) = AsyncThrowingStream<ServiceType, Error>.makeStream()
        self.types = stream
        task = Task {
            do {
                var seen: Set<ServiceType> = []
                for try await event in operation.events {
                    if case .type(let type) = event, seen.insert(type).inserted { continuation.yield(type) }
                }
                continuation.finish()
            } catch { continuation.finish(throwing: error) }
        }
        continuation.onTermination = { _ in operation.stop() }
        operation.enumerate(domain: domain)
    }
    public func stop() { operation.stop(); task.cancel() }
    deinit { operation.stop(); task.cancel() }
}
