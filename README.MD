## Ciao

[![Platforms](https://img.shields.io/cocoapods/p/Ciao.svg)](https://cocoapods.org/pods/Ciao)
[![License](https://img.shields.io/cocoapods/l/Ciao.svg)](https://raw.githubusercontent.com/AlTavares/Ciao/master/LICENSE)

[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![CocoaPods compatible](https://img.shields.io/cocoapods/v/Ciao.svg)](https://cocoapods.org/pods/Ciao)

[![Travis](https://img.shields.io/travis/AlTavares/Ciao/master.svg)](https://travis-ci.org/AlTavares/Ciao/branches)
[![JetpackSwift](https://img.shields.io/badge/JetpackSwift-framework-red.svg)](https://github.com/JetpackSwift/FrameworkTemplate)

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

pod 'Ciao', '~> 1.0.0'
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
github "Ciao/Ciao" ~> 1.0.0
```
### Swift Package Manager

To use Ciao as a [Swift Package Manager](https://swift.org/package-manager/) package just add the following in your Package.swift file.

``` swift
import PackageDescription

let package = Package(
    name: "HelloCiao",
    dependencies: [
        .Package(url: "https://github.com/AlTavares/Ciao.git", "1.0.0")
    ]
)
```

### Manually

If you prefer not to use either of the aforementioned dependency managers, you can integrate Ciao into your project manually.

#### Git Submodules

- Open up Terminal, `cd` into your top-level project directory, and run the following command "if" your project is not initialized as a git repository:

```bash
$ git init
```

- Add Ciao as a git [submodule](http://git-scm.com/docs/git-submodule) by running the following command:

```bash
$ git submodule add https://github.com/AlTavares/Ciao.git
$ git submodule update --init --recursive
```

- Open the new `Ciao` folder, and drag the `Ciao.xcodeproj` into the Project Navigator of your application's Xcode project.

    > It should appear nested underneath your application's blue project icon. Whether it is above or below all the other Xcode groups does not matter.

- Select the `Ciao.xcodeproj` in the Project Navigator and verify the deployment target matches that of your application target.
- Next, select your application project in the Project Navigator (blue project icon) to navigate to the target configuration window and select the application target under the "Targets" heading in the sidebar.
- In the tab bar at the top of that window, open the "General" panel.
- Click on the `+` button under the "Embedded Binaries" section.
- You will see two different `Ciao.xcodeproj` folders each with two different versions of the `Ciao.framework` nested inside a `Products` folder.

    > It does not matter which `Products` folder you choose from.

- Select the `Ciao.framework`.

- And that's it!

> The `Ciao.framework` is automagically added as a target dependency, linked framework and embedded framework in a copy files build phase which is all you need to build on the simulator and a device.

#### Embeded Binaries

- Download the latest release from https://github.com/AlTavares/Ciao/releases
- Next, select your application project in the Project Navigator (blue project icon) to navigate to the target configuration window and select the application target under the "Targets" heading in the sidebar.
- In the tab bar at the top of that window, open the "General" panel.
- Click on the `+` button under the "Embedded Binaries" section.
- Add the downloaded `Ciao.framework`.
- And that's it!

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

## License

Ciao is released under the MIT license. See [LICENSE](https://github.com/AlTavares/Ciao/blob/master/LICENSE) for details.
