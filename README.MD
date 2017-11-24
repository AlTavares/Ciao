
# Ciao

Lib to publish and find services using mDNS

## Installation

- Soon

## Usage

### Server
```swift
let ciaoServer = CiaoServer(type: ServiceType.tcp("ciaoserver"))
ciaoServer.start { (success) in
    print("Server started:", success)
}
ciaoServer.txtRecord = ["someKey": "someValue"]
```

### Browser
```swift
let ciaoBrowser = CiaoBrowser()
ciaoBrowser.browse(type: type) { service in
    print(service)
    print(service.txtRecordDictionary)
}
```

## Contributing

1. Fork it!
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request :D
