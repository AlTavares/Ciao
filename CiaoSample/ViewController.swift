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
    let type = "CiaoSample"

    @IBAction func browse(_ sender: Any) {
        ciaoBrowser = CiaoBrowser()
        ciaoBrowser.browse(type: type) { service in
            dump(service)
            dump(NetService.dictionary(fromTXTRecord: service.txtRecordData()!) as [String: String])
        }
    }

    @IBAction func server(_ sender: Any) {
        ciaoServer = CiaoServer(type: type)
        ciaoServer.txtRecord = ["ovo": "xunda"]
    }
}
