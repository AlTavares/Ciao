// beak: AlTavares/Ciao @ branch:develop

import Foundation
import Ciao

public func start() {
    let ciaoServer = CiaoServer(type: ServiceType.tcp("ciaoserver"))
    ciaoServer.start { success in
        print("Server started:", success)
    }
    ciaoServer.txtRecord = ["someKey": "someValue"]
    RunLoop.main.run()
}

public func startHTTP() {
    let ciaoServer = CiaoServer(type: ServiceType.tcp("http"), name: "ciao", port: 8080)
    ciaoServer.start { success in
        print("Server started:", success)
    }
    RunLoop.main.run()
}
