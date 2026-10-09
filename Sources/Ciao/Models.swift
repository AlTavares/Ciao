import Foundation

public enum CiaoError: Error, Sendable, Equatable, CustomStringConvertible {
    case invalidServiceType(String)
    case invalidTXTRecord(String)
    case invalidConfiguration(String)
    case dnsService(Int32)
    case network(String)
    case timedOut
    case stopped

    public var description: String {
        switch self {
        case .invalidServiceType(let value): "Invalid Bonjour service type: \(value)"
        case .invalidTXTRecord(let reason): "Invalid TXT record: \(reason)"
        case .invalidConfiguration(let reason): "Invalid configuration: \(reason)"
        case .dnsService(let code): "DNS-SD error \(code)"
        case .network(let message): message
        case .timedOut: "The operation timed out"
        case .stopped: "The operation stopped"
        }
    }
}

/// A Bonjour type, including its TCP or UDP transport. The trailing dot is normalized.
public struct ServiceType: Hashable, Sendable, CustomStringConvertible {
    public enum Transport: String, Sendable { case tcp, udp }
    public let rawValue: String
    public let transport: Transport
    public var description: String { rawValue }

    public init(_ rawValue: String) throws {
        let value = rawValue.hasSuffix(".") ? String(rawValue.dropLast()) : rawValue
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].hasPrefix("_"),
              let transport = Transport(rawValue: String(parts[1].dropFirst())),
              parts[1] == "_\(transport.rawValue)" else {
            throw CiaoError.invalidServiceType(rawValue)
        }
        let name = parts[0].dropFirst()
        guard (1...15).contains(name.utf8.count), name.first != "-", name.last != "-",
              name.contains(where: { $0.isASCII && $0.isLetter }),
              name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }),
              !name.contains("--") else { throw CiaoError.invalidServiceType(rawValue) }
        self.rawValue = value.lowercased()
        self.transport = transport
    }
    public static func tcp(_ name: String) throws -> Self { try Self("_\(name)._tcp") }
    public static func udp(_ name: String) throws -> Self { try Self("_\(name)._udp") }
}

/// Identity includes the interface index: the same service on two interfaces has two identities.
public struct Service: Hashable, Sendable, Identifiable {
    public let name: String
    public let type: ServiceType
    public let domain: String
    public let interfaceIndex: UInt32
    public var id: Self { self }
    public init(name: String, type: ServiceType, domain: String = "local.", interfaceIndex: UInt32 = 0) {
        self.name = name
        self.type = type
        self.domain = domain.isEmpty ? "local." : (domain.hasSuffix(".") ? domain : domain + ".")
        self.interfaceIndex = interfaceIndex
    }
}

/// Values distinguish a key without a value from a key with an empty value.
public struct TXTRecord: Hashable, Sendable {
    public enum Value: Hashable, Sendable { case flag; case bytes(Data) }
    public let values: [String: Value]
    public init(_ values: [String: Value] = [:]) throws {
        var normalized: [String: Value] = [:]
        for (key, value) in values {
            guard !key.isEmpty, key.utf8.allSatisfy({ (0x20...0x7e).contains($0) && $0 != 0x3d }) else {
                throw CiaoError.invalidTXTRecord("Keys must contain printable ASCII without '='")
            }
            let key = key.lowercased()
            guard normalized[key] == nil else { throw CiaoError.invalidTXTRecord("Duplicate key \(key)") }
            let count = key.utf8.count + (value.data.map { 1 + $0.count } ?? 0)
            guard count <= 255 else { throw CiaoError.invalidTXTRecord("Entry exceeds 255 bytes") }
            normalized[key] = value
        }
        self.values = normalized
        guard wireData.count <= 65535 else { throw CiaoError.invalidTXTRecord("Record exceeds 65535 bytes") }
    }
    public init(strings: [String: String]) throws {
        try self.init(strings.mapValues { .bytes(Data($0.utf8)) })
    }
    public static let empty = try! TXTRecord()
    public subscript(text key: String) -> String? {
        guard case .bytes(let bytes) = values[key.lowercased()] else { return nil }
        return String(data: bytes, encoding: .utf8)
    }
    public var wireData: Data {
        var result = Data()
        for key in values.keys.sorted() {
            var entry = Data(key.utf8)
            if let data = values[key]?.data { entry.append(0x3d); entry.append(data) }
            result.append(UInt8(entry.count)); result.append(entry)
        }
        // RFC 6763: even an empty TXT record contains one empty string.
        return result.isEmpty ? Data([0]) : result
    }
    public init(wireData: Data) throws {
        var values: [String: Value] = [:]
        var offset = 0
        while offset < wireData.count {
            let length = Int(wireData[offset]); offset += 1
            guard offset + length <= wireData.count else { throw CiaoError.invalidTXTRecord("Truncated entry") }
            let entry = wireData.subdata(in: offset..<(offset + length)); offset += length
            if entry.isEmpty { continue }
            let separator = entry.firstIndex(of: 0x3d)
            let keyBytes = separator.map { entry.prefix(upTo: $0) } ?? entry.prefix(entry.count)
            guard let key = String(data: keyBytes, encoding: .ascii) else { throw CiaoError.invalidTXTRecord("Invalid key") }
            let value: Value = separator.map { .bytes(Data(entry.suffix(from: entry.index(after: $0)))) } ?? .flag
            // DNS-SD treats keys as case insensitive and uses the first occurrence.
            if values[key.lowercased()] == nil { values[key.lowercased()] = value }
        }
        try self.init(values)
    }
}
private extension TXTRecord.Value {
    var data: Data? { if case .bytes(let data) = self { data } else { nil } }
}

public struct ResolvedService: Sendable, Equatable {
    public let service: Service
    public let hostName: String
    public let port: UInt16
    /// Numeric IPv4/IPv6 addresses; scoped IPv6 addresses retain their zone identifier.
    public let addresses: [String]
    public let txtRecord: TXTRecord
    public init(service: Service, hostName: String, port: UInt16, addresses: [String], txtRecord: TXTRecord) {
        self.service = service; self.hostName = hostName; self.port = port
        self.addresses = addresses; self.txtRecord = txtRecord
    }
}

public enum DiscoveryEvent: Sendable, Equatable {
    case started
    case found(Service)
    case removed(Service)
    case resolved(ResolvedService)
    case resolutionFailed(Service, CiaoError)
    case stopped
}

public struct PublicationConfiguration: Sendable {
    public enum Mode: Sendable { case externalPort; case listener }
    public var type: ServiceType
    public var name: String
    public var domain: String
    public var port: UInt16
    public var mode: Mode
    public var allowsRenaming: Bool
    public var txtRecord: TXTRecord
    /// External mode advertises a caller-owned port. Listener mode binds the port (zero chooses an ephemeral port).
    public init(type: ServiceType, name: String = "", domain: String = "", port: UInt16 = 0,
                mode: Mode = .listener, allowsRenaming: Bool = true, txtRecord: TXTRecord = .empty) {
        self.type = type; self.name = name; self.domain = domain; self.port = port
        self.mode = mode; self.allowsRenaming = allowsRenaming; self.txtRecord = txtRecord
    }
}
public struct PublishedService: Sendable, Equatable {
    public let service: Service
    public let port: UInt16
}

/// Publication status, including failures after startup. Events do not own the server lifetime.
public enum PublicationEvent: Sendable, Equatable {
    case started(PublishedService)
    case stopped
    case failed(CiaoError)
}
