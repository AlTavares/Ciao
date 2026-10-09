# ``Ciao``

Publish, discover, and resolve Bonjour services using Swift concurrency.

## Overview

Ciao exposes Sendable service/TXT values and actors that own discovery and publication lifetimes. Network.framework handles browsing and listener-backed publication; DNS-SD handles independent resolution, external ports, and type enumeration.

Always stop discovery sessions after early loop exits. Cancelling iteration tears down a session, but breaking out of a loop alone does not. Streams have one consumer and preserve all membership events through unbounded buffering. Supply a positive timeout for bounded startup/resolution. Search failures end discovery; automatic resolution failures identify their service.

The package requires Swift 6, iOS/tvOS 18, or macOS 15. Configure the consuming app's local-network purpose text, declared Bonjour types, and sandbox entitlements. Broad enumeration on iOS requires multicast entitlement approval.

## Topics

### Services and records
- ``ServiceType``
- ``Service``
- ``ResolvedService``
- ``TXTRecord``
- ``CiaoError``

### Discover and resolve
- ``CiaoBrowser``
- ``DiscoverySession``
- ``DiscoveryEvent``
- ``CiaoResolver``
- ``ServiceTypeSession``

### Publish
- ``CiaoServer``
- ``PublicationConfiguration``
- ``PublishedService``
- ``PublicationEvent``
