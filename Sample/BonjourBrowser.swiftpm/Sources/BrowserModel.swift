import Ciao
import Foundation
import Observation

@MainActor @Observable
final class BrowserModel {
  struct Request: Equatable {
    let id = UUID()
    let domain: String
  }

  var domain = "local."
  var query = ""
  private(set) var request: Request?
  private(set) var services: Set<Service> = []
  private(set) var types: Set<ServiceType> = []
  private(set) var errors: [String: String] = [:]

  var sortedTypes: [ServiceType] { types.sorted { $0.rawValue < $1.rawValue } }

  func matches(_ type: ServiceType) -> [Service] {
    services.filter {
      $0.type == type
        && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
          || type.rawValue.localizedCaseInsensitiveContains(query))
    }.sorted { ($0.name, $0.interfaceIndex) < ($1.name, $1.interfaceIndex) }
  }

  func start() {
    services.removeAll()
    types.removeAll()
    errors.removeAll()
    let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
    request = Request(domain: trimmed.isEmpty ? "local." : trimmed)
  }

  func stop() {
    request = nil
    services.removeAll()
    types.removeAll()
    errors.removeAll()
  }

  /// The view owns this task. Restarting or closing it cancels every child browser.
  func scan(_ request: Request) async {
    guard self.request == request, !Task.isCancelled else { return }
    let enumeration = ServiceTypeSession(domain: request.domain)
    defer { enumeration.stop() }
    await withTaskGroup(of: Void.self) { group in
      do {
        for try await type in enumeration.types {
          guard self.request == request, !Task.isCancelled else { break }
          guard types.insert(type).inserted else { continue }
          group.addTask { await self.browse(type, request: request) }
        }
      } catch {
        if self.request == request && !Task.isCancelled {
          errors["Service type discovery"] = discoveryError(error)
        }
      }
      group.cancelAll()
    }
    if self.request == request {
      self.request = nil
      services.removeAll()
    }
  }

  private func browse(_ type: ServiceType, request: Request) async {
    let browser = CiaoBrowser()
    do {
      let session = try await browser.browse(
        type: type, domain: request.domain, automaticallyResolve: false)
      for try await event in session.events {
        guard self.request == request, !Task.isCancelled else { break }
        switch event {
        case .found(let service): services.insert(service)
        case .removed(let service): services.remove(service)
        default: break
        }
      }
    } catch {
      if self.request == request && !Task.isCancelled {
        errors[type.rawValue] = discoveryError(error)
      }
    }
    await browser.stop()
    if self.request == request {
      services = services.filter { $0.type != type }
    }
  }

  private func discoveryError(_ error: Error) -> String {
    if let ciaoError = error as? CiaoError {
      switch ciaoError {
      case .dnsService(-65555):
        return
          "Bonjour could not authorize this app (DNS-SD -65555). This does not necessarily mean you denied local network access."
      case .dnsService(-65570):
        return
          "Local network access is blocked (DNS-SD -65570). Allow BonjourBrowser in Settings, then start browsing again."
      default: break
      }
    }
    return String(describing: error)
  }

}
