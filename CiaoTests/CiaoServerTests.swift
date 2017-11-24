//
//  CiaoTests.swift
//  CiaoTests
//
//  Created by Alexandre Tavares on 10/10/17.
//  Copyright © 2017 Tavares. All rights reserved.
//

import XCTest
@testable import Ciao

class CiaoServerTests: TestWithExpectation {
    var delegate: DummyServerDelegate!

    override func setUp() {
        super.setUp()
        delegate = DummyServerDelegate()
    }

    func testInitWithValidInfo() {
        testServer(type: ServiceType.tcp("ciaoserver").description, domain: "local.", name: "Ciao", valid: true)
    }

    func testInitWithValidInfoEmptyDomainAndName() {
        testServer(type: ServiceType.tcp("ciaoserver").description, domain: "", name: "", valid: true)
    }

    func testInitWithInvalidInfo() {
        testServer(type: "ciaoserver", domain: "local", name: "Ciao", valid: false)
    }

    func testInitWithInvalidInfoEmptyDomainAndName() {
        testServer(type: "ciaoserver", domain: "", name: "", valid: false)
    }

    func testServer(type: String, domain: String, name: String, valid: Bool) {
        let server = CiaoServer(type: type, domain: domain, name: name)
        delegate?.server = server
        server.netService.delegate = delegate
        test(server: server, valid: valid)
    }

    func test(server: CiaoServer, valid: Bool) {
        createExpectation()
        server.start { success in
            XCTAssertEqual(success, valid)
            self.done()
        }
        waitUntilDone(timeout: 5)
        XCTAssertNotNil(server.delegate)
        XCTAssertNotNil(server.netService.delegate)
        XCTAssertNotNil(delegate.server)
        XCTAssertEqual(server.started, valid)
        XCTAssertEqual(delegate.didPublishCalled, valid)
        XCTAssertEqual(delegate.didNotPublishCalled, !valid)
        if valid {
            stop(server: server)
        }
    }

    func stop(server: CiaoServer) {
        server.stop()
        XCTAssertTrue(delegate.didStopCalled)
        XCTAssertFalse(server.started)
    }
}

class DummyServerDelegate: CiaoServerDelegate {
    var didPublishCalled = false
    var didNotPublishCalled = false
    var didStopCalled = false

    override func netServiceDidPublish(_ sender: NetService) {
        super.netServiceDidPublish(sender)
        didPublishCalled = true
    }

    override func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        super.netService(sender, didNotPublish: errorDict)
        didNotPublishCalled = true
    }

    override func netServiceDidStop(_ sender: NetService) {
        super.netServiceDidStop(sender)
        didStopCalled = true
    }
}
