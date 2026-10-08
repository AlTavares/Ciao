import Ciao
import Foundation
import Observation

@MainActor @Observable
final class SampleModel {
    var name = "Ciao Demo"
    var domain = ""
    var rawType = "_ciao-demo._tcp"
    var port = "0"
    var externalPort = false
    var allowsRenaming = true
    var txt = "version=1\nnote=Hello from Ciao"
    var publication: PublishedService?
    var services: [Service] = []
    var resolved: [Service: ResolvedService] = [:]
    var status = "Ready"
    var browsing = false
    var publishing = false
    var resolving: Service?
    private let server = CiaoServer()
    private let browser = CiaoBrowser()
    private var browseTask: Task<Void, Never>?
    private var publishTask: Task<Void, Never>?
    private var resolveTask: Task<Void, Never>?
    private var browseGeneration = UUID()
    private var resolveGeneration = UUID()

    private func serviceType() throws -> ServiceType {
        let type = try ServiceType(rawType)
        #if os(iOS)
        guard ["_ciao-demo._tcp", "_ciao-demo._udp"].contains(type.rawValue) else {
            throw CiaoError.invalidConfiguration("This sample declares only _ciao-demo TCP/UDP. Add other types to NSBonjourServices; broad browsing also needs the multicast entitlement.")
        }
        #endif
        return type
    }
    private func record() throws -> TXTRecord {
        var values: [String: TXTRecord.Value] = [:]
        for line in txt.split(separator: "\n") {
            let pieces = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            values[String(pieces[0])] = pieces.count == 2 ? .bytes(Data(pieces[1].utf8)) : .flag
        }
        return try TXTRecord(values)
    }
    func publish() {
        guard !publishing else { return }
        publishTask = Task {
            publishing = true
            defer { publishing = false }
            do {
                guard let number = UInt16(port) else { throw CiaoError.invalidConfiguration("Port must be between 0 and 65535") }
                let config = PublicationConfiguration(type: try serviceType(), name: name, domain: domain, port: number,
                    mode: externalPort ? .externalPort : .listener, allowsRenaming: allowsRenaming, txtRecord: try record())
                publication = try await server.start(config)
                status = "Published \(publication!.service.name) on port \(publication!.port)"
            } catch { if !Task.isCancelled { status = String(describing: error) } }
        }
    }
    func stopPublication() async {
        publishTask?.cancel(); publishTask = nil
        await server.stop(); publication = nil; status = "Publication stopped"
    }
    func updateTXT() async {
        do { try await server.updateTXT(record()); status = "TXT record updated" }
        catch { status = String(describing: error) }
    }
    func startBrowsing() {
        guard !browsing else { return }
        let token = UUID(); browseGeneration = token
        browsing = true; services = []; resolved = [:]
        browseTask = Task {
            do {
                let session = try await browser.browse(type: serviceType(), domain: domain)
                for try await event in session.events {
                    guard !Task.isCancelled, token == browseGeneration else { break }
                    switch event {
                    case .started: status = "Browsing \(rawType)"
                    case .found(let service): if !services.contains(service) { services.append(service) }
                    case .removed(let service): services.removeAll { $0 == service }; resolved[service] = nil
                    case .resolved(let value): resolved[value.service] = value
                    case .resolutionFailed(let service, let error): status = "\(service.name): \(error)"
                    case .stopped: break
                    }
                }
                await session.stop()
            } catch { if !Task.isCancelled { status = String(describing: error) } }
            if token == browseGeneration { browsing = false }
        }
    }
    func stopBrowsing() async {
        browseGeneration = UUID(); browseTask?.cancel(); browseTask = nil
        await browser.stop(); browsing = false; services = []; resolved = [:]; status = "Browsing stopped"
    }
    func resolve(_ service: Service) {
        resolveTask?.cancel(); resolving = service
        let token = UUID(); resolveGeneration = token
        resolveTask = Task {
            do {
                let result = try await CiaoResolver.resolve(service)
                try Task.checkCancellation()
                resolved[service] = result; status = "Resolved \(service.name) without connecting"
            } catch { if !Task.isCancelled { status = String(describing: error) } }
            if token == resolveGeneration { resolving = nil }
        }
    }
    func cancelResolution() {
        if resolving != nil { status = "Resolution cancelled" }
        resolveGeneration = UUID(); resolveTask?.cancel(); resolveTask = nil; resolving = nil
    }
    /// The view's task owns cleanup when its window disappears or the app closes the view.
    func lifetime() async {
        for await event in server.events {
            guard !Task.isCancelled else { break }
            switch event {
            case .started(let info): publication = info
            case .stopped: publication = nil
            case .failed(let error): publication = nil; status = String(describing: error)
            }
        }
        cancelResolution(); await stopBrowsing(); await stopPublication()
    }
}
