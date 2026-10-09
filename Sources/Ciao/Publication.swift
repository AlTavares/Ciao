import Foundation
import Network

protocol PublicationBackend: Sendable {
    var failures: AsyncStream<CiaoError> { get }
    func start(timeout: Duration) async throws -> PublishedService
    func updateTXT(_ record: TXTRecord) async throws
    func stop() async
}

private final class ExternalPublication: PublicationBackend {
    var failures: AsyncStream<CiaoError> { operation.failures }
    private let operation = DNSOperation()
    private let configuration: PublicationConfiguration
    init(_ configuration: PublicationConfiguration) { self.configuration = configuration }
    func start(timeout: Duration) async throws -> PublishedService {
        try Task.checkCancellation()
        operation.register(configuration)
        return try await withTaskCancellationHandler {
            try await withDeadline(timeout) {
                for try await event in self.operation.events {
                    if case .published(let value) = event { return value }
                }
                try Task.checkCancellation()
                throw CiaoError.stopped
            }
        } onCancel: { self.operation.stop() }
    }
    func updateTXT(_ record: TXTRecord) async throws { try await operation.updateTXT(record) }
    func stop() async { operation.stop() }
}

private actor ListenerPublication: PublicationBackend {
    nonisolated let failures: AsyncStream<CiaoError>
    private let failureContinuation: AsyncStream<CiaoError>.Continuation
    private var published: PublishedService?
    private let listener: NWListener
    private let configuration: PublicationConfiguration
    private let events: AsyncThrowingStream<PublishedService, Error>
    private let continuation: AsyncThrowingStream<PublishedService, Error>.Continuation
    private var stopped = false
    init(_ configuration: PublicationConfiguration) throws {
        self.configuration = configuration
        let parameters: NWParameters = configuration.type.transport == .tcp ? .tcp : .udp
        listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: configuration.port)!)
        (events, continuation) = AsyncThrowingStream.makeStream()
        (failures, failureContinuation) = AsyncStream.makeStream()
        listener.service = Self.service(configuration, record: configuration.txtRecord)
        let listener = listener
        let continuation = continuation
        let failures = failureContinuation
        listener.stateUpdateHandler = { state in
            switch state {
            case .failed(let error), .waiting(let error):
                let failure = CiaoError.network(String(describing: error))
                failures.yield(failure); failures.finish(); continuation.finish(throwing: failure)
            case .cancelled: failures.finish(); continuation.finish()
            default: break
            }
        }
        listener.serviceRegistrationUpdateHandler = { [weak listener] change in
            guard case .add(let endpoint) = change,
                  case .service(let name, let rawType, let domain, _) = endpoint,
                  let type = try? ServiceType(rawType), let port = listener?.port else { return }
            continuation.yield(PublishedService(service: Service(name: name, type: type, domain: domain), port: port.rawValue))
        }
        // Ciao owns only the listener lifetime, not an application protocol. Connections are rejected.
        listener.newConnectionHandler = { $0.cancel() }
    }
    private static func service(_ config: PublicationConfiguration, record: TXTRecord) -> NWListener.Service {
        var service = NWListener.Service(name: config.name.isEmpty ? nil : config.name,
            type: config.type.rawValue, domain: config.domain.isEmpty ? nil : config.domain, txtRecord: record.wireData)
        service.noAutoRename = !config.allowsRenaming
        return service
    }
    func start(timeout: Duration) async throws -> PublishedService {
        try Task.checkCancellation()
        guard !stopped else { throw CiaoError.stopped }
        listener.start(queue: DispatchQueue(label: "Ciao.Listener"))
        let result = try await withTaskCancellationHandler {
            try await withDeadline(timeout) {
                for try await value in self.events { return value }
                try Task.checkCancellation(); throw CiaoError.stopped
            }
        } onCancel: { self.listener.cancel() }
        guard !stopped else { throw CiaoError.stopped }
        published = result
        return result
    }
    func updateTXT(_ record: TXTRecord) throws {
        guard !stopped else { throw CiaoError.stopped }
        var config = configuration
        if let published { config.name = published.service.name; config.domain = published.service.domain }
        listener.service = Self.service(config, record: record)
    }
    func stop() { guard !stopped else { return }; stopped = true; listener.cancel(); continuation.finish(); failureContinuation.finish() }
    deinit { listener.cancel(); continuation.finish(); failureContinuation.finish() }
}

/// Reusable publication owner. stop cancels startup as well as an established publication.
public actor CiaoServer {
    public nonisolated let events: AsyncStream<PublicationEvent>
    private let continuation: AsyncStream<PublicationEvent>.Continuation
    private var monitor: Task<Void, Never>?
    public private(set) var publishedService: PublishedService?
    private var backend: (any PublicationBackend)?
    private var generation = UUID()
    private let factory: @Sendable (PublicationConfiguration) throws -> any PublicationBackend
    public init() {
        (events, continuation) = AsyncStream.makeStream()
        factory = { configuration in
            switch configuration.mode {
            case .externalPort: ExternalPublication(configuration)
            case .listener: try ListenerPublication(configuration)
            }
        }
    }
    init(factory: @escaping @Sendable (PublicationConfiguration) throws -> any PublicationBackend) {
        (events, continuation) = AsyncStream.makeStream(); self.factory = factory
    }
    public func start(_ configuration: PublicationConfiguration, timeout: Duration = .seconds(10)) async throws -> PublishedService {
        try Task.checkCancellation()
        guard timeout > .zero else { throw CiaoError.invalidConfiguration("Timeout must be positive") }
        if case .externalPort = configuration.mode, configuration.port == 0 {
            throw CiaoError.invalidConfiguration("External publication requires a nonzero port")
        }
        let token = UUID(); generation = token
        monitor?.cancel(); monitor = nil
        let previous = backend; backend = nil; publishedService = nil
        if previous != nil { continuation.yield(.stopped) }
        await previous?.stop()
        guard token == generation else { throw CiaoError.stopped }
        try Task.checkCancellation()
        let operation = try factory(configuration); backend = operation
        do {
            let result = try await operation.start(timeout: timeout)
            try Task.checkCancellation()
            guard token == generation else { throw CiaoError.stopped }
            publishedService = result; continuation.yield(.started(result))
            monitor = Task { [weak self, operation] in
                for await failure in operation.failures { await self?.publicationFailed(failure, token: token) }
            }
            return result
        } catch {
            await operation.stop()
            if token == generation {
                backend = nil; publishedService = nil
                if !(error is CancellationError) { continuation.yield(.failed(error as? CiaoError ?? .network(String(describing: error)))) }
            }
            throw error
        }
    }
    public func updateTXT(_ record: TXTRecord) async throws {
        guard let backend, publishedService != nil else { throw CiaoError.stopped }
        try await backend.updateTXT(record)
    }
    private func publicationFailed(_ error: CiaoError, token: UUID) async {
        guard token == generation else { return }
        continuation.yield(.failed(error)); await stop()
    }
    public func stop() async {
        let wasActive = backend != nil
        monitor?.cancel(); monitor = nil
        generation = UUID(); publishedService = nil
        let previous = backend; backend = nil
        if wasActive { continuation.yield(.stopped) }
        await previous?.stop()
    }
    deinit { monitor?.cancel(); continuation.finish(); if let backend { Task { await backend.stop() } } }
}
