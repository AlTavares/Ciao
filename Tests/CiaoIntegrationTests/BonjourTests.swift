import Foundation
import Network
import Testing
@testable import Ciao

/// Opt in on a runner with local-network permission. Missing permission is a failure, not a retry.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["CIAO_INTEGRATION_TESTS"] == "1"), .timeLimit(.minutes(2)))
struct BonjourTests {
    @Test(arguments: [ServiceType.Transport.tcp, .udp])
    func listenerPublishResolveTXTAndRemoval(_ transport: ServiceType.Transport) async throws {
        let type = try ServiceType("_ciaotest._\(transport.rawValue)")
        let name = "Ciao-\(UUID().uuidString)"
        let server = CiaoServer(); let browser = CiaoBrowser()
        let record = try TXTRecord(strings: ["version": "1"])
        do {
            let publication = try await server.start(PublicationConfiguration(type: type, name: name, txtRecord: record))
            #expect(publication.port != 0)
            let session = try await browser.browse(type: type)
            let discovered = try await withDeadline(.seconds(15)) {
                for try await event in session.events {
                    if case .resolved(let result) = event, result.service.name == publication.service.name { return result }
                    if case .resolutionFailed(let service, let error) = event, service.name == name { throw error }
                }
                throw CiaoError.stopped
            }
            #expect(discovered.port == publication.port); #expect(!discovered.addresses.isEmpty)
            #expect(discovered.txtRecord == record)
            let updated = try TXTRecord(["binary": .bytes(Data([0, 255]))])
            try await server.updateTXT(updated)
            // Wait for DNS cache propagation; resolution errors are not retried.
            let resolved = try await withDeadline(.seconds(15)) {
                while true {
                    let value = try await CiaoResolver.resolve(discovered.service)
                    if value.txtRecord == updated { return value }
                    try await Task.sleep(for: .milliseconds(100))
                }
            }
            #expect(resolved.txtRecord == updated)
            try await server.updateTXT(.empty)
            await server.stop()
            try await withDeadline(.seconds(15)) {
                for try await event in session.events {
                    if case .removed(let service) = event, service == discovered.service { return }
                }
                throw CiaoError.stopped
            }
            await browser.stop()
            #expect(await server.publishedService == nil)
        } catch { await server.stop(); await browser.stop(); throw error }
    }
    @Test(arguments: [ServiceType.Transport.tcp, .udp])
    func advertisesAlreadyBoundExternalPortAndEnforcesNameConflict(_ transport: ServiceType.Transport) async throws {
        let listener = try NWListener(using: transport == .tcp ? .tcp : .udp, on: .any)
        let (ready, continuation) = AsyncThrowingStream<UInt16, Error>.makeStream()
        listener.stateUpdateHandler = { state in
            if case .ready = state, let port = listener.port { continuation.yield(port.rawValue) }
            if case .failed(let error) = state { continuation.finish(throwing: error) }
        }
        listener.newConnectionHandler = { $0.cancel() }
        listener.start(queue: DispatchQueue(label: "Ciao.Tests.ExternalListener"))
        defer { listener.cancel(); continuation.finish() }
        let port = try await withDeadline(.seconds(10)) { for try await port in ready { return port }; throw CiaoError.stopped }
        let first = CiaoServer(); let second = CiaoServer()
        let config = PublicationConfiguration(type: try ServiceType("_ciaotest._\(transport.rawValue)"), name: "Ciao-\(UUID().uuidString)", port: port,
                                              mode: .externalPort, allowsRenaming: false)
        do {
            let published = try await first.start(config)
            #expect(published.port == port)
            let resolved = try await CiaoResolver.resolve(published.service)
            #expect(resolved.port == port)
            let updated = try TXTRecord(["binary": .bytes(Data([0, 255]))])
            for record in [updated, .empty] {
                try await first.updateTXT(record)
                try await withDeadline(.seconds(10)) {
                    while true {
                        let value = try await CiaoResolver.resolve(published.service)
                        if value.txtRecord == record { return }
                        try await Task.sleep(for: .milliseconds(100))
                    }
                }
            }
            var conflicting = config
            conflicting.port = port == 65535 ? port - 1 : port + 1
            await #expect(throws: CiaoError.dnsService(-65548)) { try await second.start(conflicting) }
            conflicting.allowsRenaming = true
            let renamed = try await second.start(conflicting)
            #expect(renamed.service.name != published.service.name)
            await first.stop(); await second.stop()
        } catch { await first.stop(); await second.stop(); throw error }
    }
    @Test func defaultsAndRepeatedPublicationUseFreshLifetimes() async throws {
        let server = CiaoServer()
        do {
            for _ in 0..<2 {
                let result = try await server.start(PublicationConfiguration(type: .tcp("ciaotest")))
                #expect(!result.service.name.isEmpty)
                #expect(!result.service.domain.isEmpty)
                #expect(result.port != 0)
                await server.stop()
                #expect(await server.publishedService == nil)
            }
        } catch { await server.stop(); throw error }
    }
    @Test func resolutionHasDeadlineAndCancellation() async throws {
        let missing = Service(name: "Missing-\(UUID().uuidString)", type: try .tcp("ciaotest"))
        await #expect(throws: CiaoError.timedOut) { try await CiaoResolver.resolve(missing, timeout: .milliseconds(100)) }
        let task = Task { try await CiaoResolver.resolve(missing) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
    @Test func enumeratesPublishedType() async throws {
        let server = CiaoServer()
        let session = ServiceTypeSession()
        defer { session.stop() }
        let type = try ServiceType.tcp("ciaotest")
        do {
            _ = try await server.start(PublicationConfiguration(type: type, name: "Ciao-\(UUID().uuidString)"))
            try await withDeadline(.seconds(15)) { for try await discovered in session.types { if discovered == type { return } }; throw CiaoError.stopped }
            await server.stop()
        } catch { await server.stop(); throw error }
    }
}
