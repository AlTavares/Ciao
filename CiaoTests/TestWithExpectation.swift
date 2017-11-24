//
//  TestWithExpectation.swift
//  CiaoTests
//
//  Created by Alexandre Mantovani Tavares on 19/11/17.
//  Copyright © 2017 Tavares. All rights reserved.
//

import XCTest
@testable import Ciao

class TestWithExpectation: XCTestCase {
    var expectation: XCTestExpectation!
    
    func createExpectation() {
        expectation = expectation(description: "Expectation fulfilled")
    }
    
    func waitUntilDone(timeout: Double = 1) {
        waitForExpectations(timeout: timeout, handler: nil)
    }
    
    func done() {
        expectation.fulfill()
    }
}

