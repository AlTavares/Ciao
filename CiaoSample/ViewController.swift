//
//  ViewController.swift
//  CiaoSample
//
//  Created by Alexandre Tavares on 10/10/17.
//  Copyright © 2017 Tavares. All rights reserved.
//

import UIKit
import Ciao

class ViewController: UIViewController {
    var ciaoServer: CiaoServer!
    var ciaoBrowser: CiaoBrowser!
    let type = ServiceType.tcp("CiaoSample")
    var count = 0

    @IBAction func browse(_ sender: Any) {
        ciaoBrowser = CiaoBrowser()
        ciaoBrowser.browse(type: type) { service in
            dump(service)
            dump(service.txtRecordDictionary)
        }
    }

    @IBAction func server(_ sender: Any) {
        ciaoServer = CiaoServer(type: type)
        ciaoServer.start { (success) in
            print("Server started:", success)
        }
        updateTxtRecord()
    }

    @IBAction func updateTxtRecord() {
        ciaoServer.txtRecord = ["recordKey": "update count: \(count)"]
        count += 1
    }
}
