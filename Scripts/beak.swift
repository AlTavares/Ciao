// beak: AlTavares/Ciao @ 1.0.2

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
