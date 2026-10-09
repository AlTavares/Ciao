import Foundation
import Testing
@testable import Ciao

@Test func serviceTypesNormalizeAndValidate() throws {
    #expect(try ServiceType("_HTTP._tcp.").rawValue == "_http._tcp")
    #expect(try ServiceType.udp("demo").transport == .udp)
    for value in ["http", "_a._sctp", "_123._tcp", "_-abc._tcp", "_a--b._udp", "_way-too-long-name._tcp", "_é._tcp"] {
        #expect(throws: CiaoError.invalidServiceType(value)) { try ServiceType(value) }
    }
}
@Test func identityIncludesInterfaceAndNormalizesDomain() throws {
    let type = try ServiceType.tcp("demo")
    #expect(Service(name: "one", type: type, domain: "local") == Service(name: "one", type: type, domain: ""))
    #expect(Service(name: "one", type: type, interfaceIndex: 1) != Service(name: "one", type: type, interfaceIndex: 2))
}
@Test func txtPreservesBinaryFlagsAndEmptyValues() throws {
    let record = try TXTRecord(["FLAG": .flag, "empty": .bytes(Data()), "binary": .bytes(Data([0, 255, 61])), "text": .bytes(Data("Olá".utf8))])
    #expect(try TXTRecord(wireData: record.wireData) == record)
    #expect(record[text: "TEXT"] == "Olá")
    #expect(record[text: "binary"] == nil)
    #expect(TXTRecord.empty.wireData == Data([0]))
}
@Test func txtRejectsMalformedRecords() {
    #expect(throws: CiaoError.self) { try TXTRecord(["bad=key": .flag]) }
    #expect(throws: CiaoError.self) { try TXTRecord(["x": .bytes(Data(repeating: 0, count: 255))]) }
    #expect(throws: CiaoError.self) { try TXTRecord(["A": .flag, "a": .flag]) }
    #expect(throws: CiaoError.self) { try TXTRecord(wireData: Data([4, 1])) }
}
@Test func txtUsesFirstCaseInsensitiveKey() throws {
    #expect(try TXTRecord(wireData: Data([3, 65, 61, 49, 3, 97, 61, 50]))[text: "a"] == "1")
}
