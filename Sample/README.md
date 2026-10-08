# Ciao sample

Open CiaoSample.xcodeproj with Xcode 27, select CiaoSample_iOS or CiaoSample_macOS, and run. Choose your development team for signed iOS device runs. The app imports the local parent Swift package; no framework archive is required.

Run two instances on the same local network. Use matching TCP/UDP demo types. Publish with port zero, browse in the other instance, open a service, resolve independently, change TXT and press Update TXT, then resolve again to see its new data. Stop publication and observe removal. Repeat start/stop; stop browsing clears membership. Cancellation is available for independent resolution and publication startup.

Listener mode binds an available port and rejects connections. External mode only advertises a nonzero port belonging to an independently running server. Names may be automatically renamed unless the option is disabled. TXT lines use key=value; a line without '=' is a flag. An empty editor clears records. Binary incoming TXT values display as hex when they are not UTF-8.

The plists declare _ciao-demo._tcp and _ciao-demo._udp and explain local-network usage. macOS sandbox entitlements permit network client/server activity. Other service types are gated on iOS; add declared types and obtain multicast entitlement approval for broad browsing/enumeration. Verify permission behavior on signed physical devices.

The checked-in project is generated from project.yml. Regenerate with `xcodegen generate --spec Sample/project.yml` from the repository root after changing project configuration. XcodeGen is a development convenience and is not a dependency of the distributed library or CI builds.
