//
//  CiaoBrowserTests.swift
//  CiaoTests
//
//  Created by Alexandre Mantovani Tavares on 19/11/17.
//  Copyright © 2017 Tavares. All rights reserved.
//

@testable import Ciao
import XCTest

class CiaoBrowserTests: XCTestCase {
    let serviceType = ServiceType.tcp("ciaoserver")
    
    @MainActor
    func testIfBrowserCanFindServers() async throws {
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
            print(event)
            switch event {
            case .startedSearch:
                break
                
            case .stoppedSearch:
                break
                
            case .found:
                servicesFound += 1
                
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
                }
            }
        }
        XCTAssertEqual(browser.services.count, servicesFound)
    }

    @MainActor
    func testRemovedService() async {
        let browser = CiaoBrowser()
        let server = CiaoServer(type: serviceType, name: "server1")
        
        for await event in browser.browse(type: serviceType) {
            print(event)
            switch event {
            case .startedSearch:
                break
                
            case .stoppedSearch:
                break
                
            case .found:
                break
                
            case .removed:
                XCTAssertEqual(browser.services.count, 0)
                browser.stop()
                
            case .resolved:
                XCTAssertEqual(browser.services.count, 1)
                server.stop()
            }
        }
        XCTAssertEqual(browser.services.count, 0)
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
