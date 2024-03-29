//
//  NetServiceExtension.swift
//  Ciao
//
//  Created by Alexandre Tavares on 11/10/17.
//  Copyright © 2017 Tavares. All rights reserved.
//

import Foundation

extension NetService {
    public class func dictionary(fromTXTRecord data: Data) -> [String: String] {
        return NetService.dictionary(fromTXTRecord: data).mapValues { data in
            String(data: data, encoding: .utf8) ?? ""
        }
    }

    public class func data(fromTXTRecord data: [String: String]) -> Data {
        return NetService.data(fromTXTRecord: data.mapValues { $0.data(using: .utf8) ?? Data() })
    }

    public func setTXTRecord(dictionary: [String: String]?){
        guard let dictionary = dictionary else {
            self.setTXTRecord(nil)
            return
        }
        self.setTXTRecord(NetService.data(fromTXTRecord: dictionary))
    }

    public var txtRecordDictionary: [String: String]? {
        guard let txtRecordData = self.txtRecordData() else { return nil }
        var records = [String: String]()
        let txtRecord = CFNetServiceCreateDictionaryWithTXTData(nil, txtRecordData as CFData)?.takeRetainedValue() as? Dictionary<String,Data> ?? ["": txtRecordData]
        for (key, data) in txtRecord {
            if let line = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                records[key] = line as String
            } else {
                records[key] = data.description
            }
        }
        return records
    }
}
