import Ciao
import SwiftUI

struct BrowserView: View {
  @State private var model = BrowserModel()
  @State private var selected: Service?

  var body: some View {
    NavigationStack {
      List {
        Section {
          TextField("Domain", text: $model.domain)
            .autocorrectionDisabled()
            .disabled(model.request != nil)
          HStack {
            Button(model.request == nil ? "Start browsing" : "Refresh") { model.start() }
            Spacer()
            if model.request != nil {
              Button("Stop", role: .cancel) { model.stop() }
            }
          }
          .buttonStyle(.bordered)
          Text("\(model.services.count) service endpoints · \(model.types.count) types")
            .foregroundStyle(.secondary)
        } footer: {
          Text(
            "Discovers advertised types in this domain. A service visible on multiple network interfaces appears once per interface."
          )
        }

        if !model.errors.isEmpty {
          Section("Discovery errors") {
            ForEach(model.errors.keys.sorted(), id: \.self) { key in
              VStack(alignment: .leading) {
                Text(key).font(.headline)
                Text(model.errors[key] ?? "").font(.caption)
              }
            }
            #if targetEnvironment(macCatalyst)
              Text(
                "Check System Settings → Privacy & Security → Local Network. If BonjourBrowser is already enabled, no new prompt is expected. All-type enumeration can still fail with -65555; this is a known unresolved issue."
              )
              .font(.caption)
            #else
              Text(
                "Allow local network access in Settings, then start browsing again. Broad discovery on iOS also requires Apple's approved multicast entitlement."
              )
              .font(.caption)
            #endif
          }
        }

        ForEach(model.sortedTypes, id: \.self) { type in
          let services = model.matches(type)
          if !services.isEmpty {
            Section(type.rawValue) {
              ForEach(services) { service in
                Button {
                  selected = service
                } label: {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(service.name).foregroundStyle(.primary)
                    Text("\(service.domain) · interface \(service.interfaceIndex)")
                      .font(.caption).foregroundStyle(.secondary)
                  }
                }
              }
            }
          }
        }

        if model.sortedTypes.allSatisfy({ model.matches($0).isEmpty }) {
          ContentUnavailableView(
            model.query.isEmpty ? "No services yet" : "No matches",
            systemImage: "network",
            description: Text(
              model.request == nil
                ? "Start browsing to discover Bonjour services."
                : "Listening for services advertised on your network."))
        }
      }
      .navigationTitle("Bonjour Browser")
      .searchable(text: $model.query, prompt: "Service name or type")
      .task(id: model.request) {
        if let request = model.request { await model.scan(request) }
      }
      .sheet(item: $selected) { ServiceDetails(service: $0) }
    }
  }
}

private struct ServiceDetails: View {
  let service: Service
  @Environment(\.dismiss) private var dismiss
  @State private var result: ResolvedService?
  @State private var error: String?
  @State private var attempt = 0

  var body: some View {
    NavigationStack {
      Form {
        Section("Service") {
          LabeledContent("Name", value: service.name)
          LabeledContent("Type", value: service.type.rawValue)
          LabeledContent("Domain", value: service.domain)
          LabeledContent("Interface", value: String(service.interfaceIndex))
        }
        if let result {
          Section("Endpoint") {
            LabeledContent("Host", value: result.hostName)
            LabeledContent("Port", value: String(result.port))
            ForEach(result.addresses, id: \.self) { Text($0) }
          }
          Section("TXT record") {
            if result.txtRecord.values.isEmpty { Text("No TXT values") }
            ForEach(result.txtRecord.values.keys.sorted(), id: \.self) { key in
              LabeledContent(key, value: txtValue(result.txtRecord.values[key]))
            }
          }
        } else if let error {
          Section("Resolution failed") { Text(error) }
        } else {
          ProgressView("Resolving…")
        }
        Button("Resolve again") { attempt += 1 }
      }
      .textSelection(.enabled)
      .navigationTitle("Service details")
      .toolbar { Button("Done") { dismiss() } }
      .task(id: attempt) {
        result = nil
        error = nil
        do {
          let resolved = try await CiaoResolver.resolve(service, timeout: .seconds(10))
          try Task.checkCancellation()
          result = resolved
        } catch {
          if !Task.isCancelled { self.error = String(describing: error) }
        }
      }
    }
  }

  private func txtValue(_ value: TXTRecord.Value?) -> String {
    switch value {
    case .flag: "(flag)"
    case .bytes(let data):
      String(data: data, encoding: .utf8)
        ?? data.map { String(format: "%02x", $0) }.joined(separator: " ")
    case nil: ""
    }
  }
}
