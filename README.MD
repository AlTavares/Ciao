## Ciao

# Join the Ciao Project as a Contributor!

🚀 **We're inviting open-source enthusiasts to contribute!** 🚀

Despite a pause in updates, [Ciao](https://github.com/AlTavares/Ciao) is operational and ready for enhancements. Your contributions can breathe new life into it!

**How You Can Help:**
- **Code Enhancements:** From minor tweaks to major features, all contributions are welcome.
- **Documentation Updates:** Help keep our documentation current and user-friendly.
- **Community Engagement:** Support users and enrich discussions.

Start by forking the repo, create your feature branch, and dive into our [issues](https://github.com/AlTavares/Ciao/issues). Every contribution is a step towards advancement!

[![Platforms](https://img.shields.io/cocoapods/p/Ciao.svg)](https://cocoapods.org/pods/Ciao)
[![License](https://img.shields.io/cocoapods/l/Ciao.svg)](https://raw.githubusercontent.com/AlTavares/Ciao/master/LICENSE)

[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![CocoaPods compatible](https://img.shields.io/cocoapods/v/Ciao.svg)](https://cocoapods.org/pods/Ciao)


Lib to publish and find services using mDNS

- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [License](#license)

## Requirements

- iOS 8.0+ / Mac OS X 10.10+ / tvOS 9.0+
- Xcode 9.0+

## Installation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

To integrate Ciao into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
use_frameworks!

pod 'Ciao', '~> 2.1.2'
```

Then, run the following command:

```bash
$ pod install
```

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that automates the process of adding frameworks to your Cocoa application.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate Ciao into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "AlTavares/Ciao" ~> 2.1.2
```
### Swift Package Manager

To use Ciao as a [Swift Package Manager](https://swift.org/package-manager/) package just add the following in your Package.swift file.

``` swift
dependencies: [
    .package(url: "https://github.com/AlTavares/Ciao.git", from: "2.1.2")
]
```

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

// get notified when a service is found
browser.serviceFoundHandler = { service in
    print("Service found")
    print(service)
}

// register to automatically resolve a service
browser.serviceResolvedHandler = { service in
    print("Service resolved")
    print(service)
    print(service.hostName)
    print(service.txtRecordDictionary)
}

browser.serviceRemovedHandler = { service in
    print("Service removed")
    print(service)
}

ciaoBrowser.browse(type: type)
```

### Resolver

Optionally you can also use the resolver to any NetService instance

```swift

var resolver = CiaoResolver(service: service)
resolver?.resolve(withTimeout: 0) { (result: Result<NetService, ErrorDictionary>) in
    print(result)
}

```

## Contributing

1. Fork it!
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request :D

## License

Ciao is released under the MIT license. See [LICENSE](https://github.com/AlTavares/Ciao/blob/master/LICENSE) for details.
