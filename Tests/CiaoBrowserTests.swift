//
//  CiaoBrowserTests.swift
//  CiaoTests
//
//  Created by Alexandre Mantovani Tavares on 19/11/17.
//  Copyright © 2017 Tavares. All rights reserved.
//

import XCTest
@testable import Ciao

class CiaoBrowserTests: TestWithExpectation {
    let serviceType = ServiceType.tcp("ciaoserver")
    
    func testIfBrowserCanFindServers() {
        createExpectation()
        let browser = CiaoBrowser()
        var serversFound = 0
        let server1 = CiaoServer(type: serviceType, name: "server1")
        let server2 = CiaoServer(type: serviceType, name: "server2")
        server1.txtRecord = ["server": "first"]
        server2.txtRecord = ["server": "second"]
        server1.start()
        server2.start()
        browser.browse(type: serviceType) { netService in
            serversFound += 1
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
            if serversFound == 2 {
                XCTAssertEqual(browser.services.count, 2)
                self.done()
            }
        }
        waitUntilDone(timeout: 5)
    }

    func testRetain() {
        var parent: CiaoBrowserParent? = CiaoBrowserParent(CiaoBrowser())
        weak var browser = parent?.browser
        weak var delegate = browser?.delegate
        weak var resolverDelegate = browser?.resolverDelegate
        XCTAssertNotNil(browser)
        XCTAssertNotNil(delegate)
        XCTAssertNotNil(resolverDelegate)
        parent = nil
        XCTAssertNil(browser)
        XCTAssertNil(delegate)
        XCTAssertNil(resolverDelegate)
    }

}


private class CiaoBrowserParent {
    var browser: CiaoBrowser
    init(_ browser: CiaoBrowser) {
        self.browser = browser
    }
}
