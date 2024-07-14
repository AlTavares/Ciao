//
//  CiaoBrowserTests.swift
//  CiaoTests
//
//  Created by Alexandre Mantovani Tavares on 19/11/17.
//  Copyright © 2017 Tavares. All rights reserved.
//

@testable import Ciao
import XCTest

class CiaoBrowserTests: TestWithExpectation {
    let serviceType = ServiceType.tcp("ciaoserver")

    func testIfBrowserCanFindServers() async throws {
        createExpectation()
        let browser = CiaoBrowser()
        var servicesFound = 0
        var servicesResolved = 0
        let server1 = CiaoServer(type: serviceType, name: "server1")
        let server2 = CiaoServer(type: serviceType, name: "server2", port: 3000)
        server1.txtRecord = ["server": "first"]
        server2.txtRecord = ["server": "second"]
        server1.start(options: .listenForConnections)
        server2.start()

        for await event in browser.browse(type: serviceType) {
            switch event {
            case .startedSearch:
                break
                
            case .stoppedSearch:
                break
                
            case .found(let service):
                servicesFound += 1
                XCTAssertEqual(browser.services.count, servicesFound)
                
            case .removed:
                break
                
            case .resolved(let result):
                let netService = try! result.get()
                servicesResolved += 1
                var expectedValue = ""
                switch netService.name {
                case "server1":
                    expectedValue = "first"
                case "server2":
                    expectedValue = "second"
                default:
                    XCTFail("Unexpected server")
                }
                XCTAssertNotNil(netService.txtRecordDictionary)
                XCTAssertEqual(netService.txtRecordDictionary!["server"], expectedValue)
                if servicesResolved == 2 {
                    XCTAssertEqual(browser.services.count, 2)
                    browser.stop()
                    self.done()
                }
            }
        }
        waitUntilDone(timeout: 5)
    }

    func testRemovedService() async throws {
        createExpectation()
        let browser = CiaoBrowser()
        let server = CiaoServer(type: serviceType, name: "server1")
        server.start(options: .listenForConnections)

        for await event in browser.browse(type: serviceType) {
            switch event {
            case .startedSearch:
                break
                
            case .stoppedSearch:
                break
                
            case .found:
                break
                
            case .removed(let service):
                XCTAssertEqual(browser.services.count, 0)
                browser.stop()
                self.done()
                
            case .resolved(let result):
                XCTAssertEqual(browser.services.count, 1)
                server.stop()
            }
        }
        waitUntilDone(timeout: 5)
    }

    func testRetain() {
        var parent: CiaoBrowserParent? = CiaoBrowserParent(CiaoBrowser())
        weak var browser = parent?.browser
        weak var delegate = browser?.delegate
        XCTAssertNotNil(browser)
        XCTAssertNotNil(delegate)
        parent = nil
        XCTAssertNil(browser)
        XCTAssertNil(delegate)
    }
}

private class CiaoBrowserParent {
    var browser: CiaoBrowser
    init(_ browser: CiaoBrowser) {
        self.browser = browser
    }
}
