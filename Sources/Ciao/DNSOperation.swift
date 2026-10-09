import Foundation
import Network
import CiaoDNS
import Darwin

// DNS-SD requires creation, callbacks, updates, and deallocation on the same serial queue.
// This is the only unchecked wrapper: all mutable fields and C references are queue-confined.
// Callback contexts are unretained; the caller retains the operation through completion, and
// deinit synchronously drains that queue before releasing the C references.
final class DNSOperation: @unchecked Sendable {
    enum Event: Sendable { case published(PublishedService); case resolved(ResolvedService); case type(ServiceType) }
    let failures: AsyncStream<CiaoError>
    private let failureContinuation: AsyncStream<CiaoError>.Continuation
    let events: AsyncThrowingStream<Event, Error>
    private let continuation: AsyncThrowingStream<Event, Error>.Continuation
    private let queue = DispatchQueue(label: "Ciao.DNS-SD")
    private let queueKey = DispatchSpecificKey<Bool>()
    private var references: [DNSServiceRef] = []
    private var stopped = false
    private var resolved: (Service, String, UInt16, TXTRecord)?
    private var addresses: Set<String> = []

    init() {
        (events, continuation) = AsyncThrowingStream.makeStream()
        (failures, failureContinuation) = AsyncStream.makeStream()
        queue.setSpecific(key: queueKey, value: true)
        continuation.onTermination = { [weak self] _ in self?.stop() }
    }
    private var context: UnsafeMutableRawPointer { Unmanaged.passUnretained(self).toOpaque() }
    private func attach(_ reference: DNSServiceRef?, error: DNSServiceErrorType) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard error == 0, let reference else { fail(.dnsService(error)); return }
        references.append(reference)
        let code = DNSServiceSetDispatchQueue(reference, queue)
        if code != 0 { fail(.dnsService(code)) }
    }
    private func fail(_ error: CiaoError) {
        failureContinuation.yield(error); failureContinuation.finish()
        continuation.finish(throwing: error); cleanup()
    }
    private func cleanup() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard !stopped else { return }
        stopped = true
        failureContinuation.finish()
        for reference in references { DNSServiceRefDeallocate(reference) }
        references.removeAll()
    }
    func stop() {
        // Complete deallocation before returning, so immediate reuse cannot race withdrawal.
        if DispatchQueue.getSpecific(key: queueKey) == true { cleanup(); continuation.finish() }
        else { queue.sync { cleanup(); continuation.finish() } }
    }
    deinit {
        if DispatchQueue.getSpecific(key: queueKey) == true { cleanup() }
        else { queue.sync { cleanup() } }
    }
    func register(_ config: PublicationConfiguration) {
        queue.async {
            guard !self.stopped else { return }
            guard config.port != 0 else { self.fail(.invalidConfiguration("External publication requires a nonzero port")); return }
            var reference: DNSServiceRef?
            let data = config.txtRecord.wireData
            let error = data.withUnsafeBytes { bytes in
                DNSServiceRegister(&reference, config.allowsRenaming ? 0 : DNSServiceFlags(kDNSServiceFlagsNoAutoRename), 0,
                    config.name.isEmpty ? nil : config.name, config.type.rawValue,
                    config.domain.isEmpty ? nil : config.domain, nil, config.port.bigEndian,
                    UInt16(data.count), bytes.baseAddress, { _, _, error, name, type, domain, context in
                        guard let context else { return }
                        let owner = Unmanaged<DNSOperation>.fromOpaque(context).takeUnretainedValue()
                        guard !owner.stopped else { return }
                        guard error == 0, let name, let type, let domain else { owner.fail(.dnsService(error)); return }
                        do {
                            let service = Service(name: String(cString: name), type: try ServiceType(String(cString: type)), domain: String(cString: domain))
                            // The supplied port remains owned by the caller.
                            owner.continuation.yield(.published(PublishedService(service: service, port: owner.registrationPort)))
                        } catch { owner.fail(.invalidConfiguration(String(describing: error))) }
                    }, self.context)
            }
            self.registrationPort = config.port
            self.attach(reference, error: error)
        }
    }
    private var registrationPort: UInt16 = 0
    func updateTXT(_ record: TXTRecord) async throws {
        try await withCheckedThrowingContinuation { (completion: CheckedContinuation<Void, Error>) in
            queue.async {
                guard !self.stopped, let reference = self.references.first else { completion.resume(throwing: CiaoError.stopped); return }
                let data = record.wireData
                let code = data.withUnsafeBytes { DNSServiceUpdateRecord(reference, nil, 0, UInt16(data.count), $0.baseAddress, 0) }
                if code == 0 { completion.resume() } else { completion.resume(throwing: CiaoError.dnsService(code)) }
            }
        }
    }
    func resolve(_ service: Service) {
        queue.async {
            guard !self.stopped else { return }
            var reference: DNSServiceRef?
            let code = DNSServiceResolve(&reference, 0, service.interfaceIndex, service.name, service.type.rawValue, service.domain,
                { _, _, interface, error, _, host, port, length, bytes, context in
                    guard let context else { return }
                    let owner = Unmanaged<DNSOperation>.fromOpaque(context).takeUnretainedValue()
                    guard !owner.stopped else { return }
                    guard error == 0, let host else { owner.fail(.dnsService(error)); return }
                    do {
                        let data = bytes.map { Data(bytes: $0, count: Int(length)) } ?? Data()
                        let record = try TXTRecord(wireData: data)
                        owner.resolved = (owner.requestedService!, String(cString: host), UInt16(bigEndian: port), record)
                        owner.lookupAddresses(host: String(cString: host), interface: interface)
                    } catch { owner.fail(.invalidTXTRecord(String(describing: error))) }
                }, self.context)
            self.requestedService = service
            self.attach(reference, error: code)
        }
    }
    private var requestedService: Service?
    private func lookupAddresses(host: String, interface: UInt32) {
        guard resolved != nil, !stopped else { return }
        var reference: DNSServiceRef?
        let code = DNSServiceGetAddrInfo(&reference, 0, interface,
            DNSServiceProtocol(kDNSServiceProtocol_IPv4 | kDNSServiceProtocol_IPv6), host,
            { _, flags, _, error, _, address, _, context in
                guard let context else { return }
                let owner = Unmanaged<DNSOperation>.fromOpaque(context).takeUnretainedValue()
                guard !owner.stopped else { return }
                // An absent A or AAAA record must not discard results from the other family.
                if error == kDNSServiceErr_NoSuchRecord { return }
                guard error == 0, let address else { owner.fail(.dnsService(error)); return }
                var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(address, socklen_t(address.pointee.sa_len), &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                    if flags & DNSServiceFlags(kDNSServiceFlagsAdd) != 0 { owner.addresses.insert(String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)) }
                }
                if flags & DNSServiceFlags(kDNSServiceFlagsMoreComing) == 0, let (service, host, port, record) = owner.resolved, !owner.addresses.isEmpty {
                    owner.continuation.yield(.resolved(ResolvedService(service: service, hostName: host, port: port,
                        addresses: owner.addresses.sorted(), txtRecord: record)))
                    owner.continuation.finish()
                    owner.cleanup()
                }
            }, context)
        attach(reference, error: code)
    }
    func enumerate(domain: String) {
        queue.async {
            guard !self.stopped else { return }
            var reference: DNSServiceRef?
            let code = DNSServiceBrowse(&reference, 0, 0, "_services._dns-sd._udp", domain.isEmpty ? nil : domain,
                { _, flags, _, error, name, type, _, context in
                    guard let context else { return }
                    let owner = Unmanaged<DNSOperation>.fromOpaque(context).takeUnretainedValue()
                    guard !owner.stopped else { return }
                    guard error == 0, let name, let type else { owner.fail(.dnsService(error)); return }
                    if flags & DNSServiceFlags(kDNSServiceFlagsAdd) != 0 {
                        let raw = String(cString: name) + "." + String(cString: type).split(separator: ".").first.map(String.init)!
                        if let serviceType = try? ServiceType(raw) { owner.continuation.yield(.type(serviceType)) }
                    }
                }, self.context)
            self.attach(reference, error: code)
        }
    }
}

/// Resolve SRV, TXT and address records without creating a network connection.
public enum CiaoResolver {
    public static func resolve(_ service: Service, timeout: Duration = .seconds(10)) async throws -> ResolvedService {
        try Task.checkCancellation()
        guard timeout > .zero else { throw CiaoError.invalidConfiguration("Timeout must be positive") }
        let operation = DNSOperation()
        operation.resolve(service)
        defer { operation.stop() }
        return try await withTaskCancellationHandler {
            try await withDeadline(timeout) {
                for try await event in operation.events {
                    if case .resolved(let value) = event { return value }
                }
                try Task.checkCancellation()
                throw CiaoError.stopped
            }
        } onCancel: { operation.stop() }
    }
}

func withDeadline<Value: Sendable>(_ duration: Duration, operation: @escaping @Sendable () async throws -> Value) async throws -> Value {
    try await withDeadline(duration, clock: ContinuousClock(), operation: operation)
}

func withDeadline<Value: Sendable, C: Clock>(_ duration: Duration, clock: C, operation: @escaping @Sendable () async throws -> Value) async throws -> Value where C.Duration == Duration {
    guard duration > .zero else { throw CiaoError.invalidConfiguration("Timeout must be positive") }
    return try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask(operation: operation)
        let deadline = clock.now.advanced(by: duration)
        group.addTask { try await clock.sleep(until: deadline, tolerance: nil); throw CiaoError.timedOut }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}
