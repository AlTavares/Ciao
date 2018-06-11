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
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testIfBrowserCanFindServers() {
        createExpectation()
        let serviceType = ServiceType.tcp("ciaoserver")
        let server1 = CiaoServer(type: serviceType, name: "server1")
        let server2 = CiaoServer(type: serviceType, name: "server2")
        server1.txtRecord = ["server": "first"]
        server2.txtRecord = ["server": "second"]
        server1.start()
        server2.start()
        let browser = CiaoBrowser()
        var serversFound = 0
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
    
    
}

