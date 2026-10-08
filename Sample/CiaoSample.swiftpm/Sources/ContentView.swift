import Ciao
import SwiftUI

struct ContentView: View {
    @State private var model = SampleModel()
    @State private var selected: Service?
    var body: some View {
        NavigationStack {
            Form {
                Section("Service") {
                    TextField("Bonjour type", text: $model.rawType)
                        .autocorrectionDisabled()
                    Picker("Transport", selection: $model.rawType) {
                        Text("TCP demo").tag("_ciao-demo._tcp")
                        Text("UDP demo").tag("_ciao-demo._udp")
                    }
                    TextField("Domain (empty uses Bonjour default)", text: $model.domain)
                    TextField("Name (empty uses device name)", text: $model.name)
                }
                Section("Publish") {
                    TextField("Port (0 chooses an available port)", text: $model.port)
                    Toggle("Advertise a port owned by another listener", isOn: $model.externalPort)
                    Toggle("Allow Bonjour to rename on conflict", isOn: $model.allowsRenaming)
                    Text("External publication advertises the supplied port. Listener publication binds it and rejects incoming connections.")
                        .font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $model.txt).frame(height: 90).font(.system(.body, design: .monospaced))
                    Text("TXT entries: one key=value or flag per line. Clear the editor to clear TXT records.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Publish") { model.publish() }.disabled(model.publication != nil || model.publishing)
                        Button("Update TXT") { Task { await model.updateTXT() } }.disabled(model.publication == nil)
                        Button("Stop") { Task { await model.stopPublication() } }.disabled(model.publication == nil && !model.publishing)
                    }
                    if let publication = model.publication {
                        LabeledContent("Published name", value: publication.service.name)
                        LabeledContent("Actual port", value: String(publication.port))
                    }
                }
                Section("Discover") {
                    HStack {
                        Button("Browse") { model.startBrowsing() }.disabled(model.browsing)
                        Button("Stop browsing") { Task { await model.stopBrowsing() } }.disabled(!model.browsing)
                    }
                    if model.services.isEmpty { Text(model.browsing ? "Looking for services…" : "Start browsing to find another instance.").foregroundStyle(.secondary) }
                    ForEach(model.services) { service in
                        Button { selected = service } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(service.name)
                                    Text("\(service.domain) · interface \(service.interfaceIndex)").font(.caption)
                                }
                                Spacer()
                                if let result = model.resolved[service] { Text(String(result.port)).monospacedDigit() }
                                Image(systemName: "chevron.right")
                            }
                        }
                    }
                }
                Section("Status") { Text(model.status).textSelection(.enabled) }
            }
            .navigationTitle("Ciao Bonjour")
            .task { await model.lifetime() }
            .sheet(item: $selected) { service in
                NavigationStack {
                    Form {
                        LabeledContent("Name", value: service.name)
                        LabeledContent("Type", value: service.type.rawValue)
                        LabeledContent("Domain", value: service.domain)
                        if let value = model.resolved[service] {
                            LabeledContent("Host", value: value.hostName)
                            LabeledContent("Port", value: String(value.port))
                            ForEach(value.addresses, id: \.self) { Text($0).font(.system(.body, design: .monospaced)) }
                            ForEach(value.txtRecord.values.keys.sorted(), id: \.self) { key in
                                LabeledContent(key, value: txtValue(value.txtRecord.values[key]))
                            }
                        }
                        Button("Resolve independently") { model.resolve(service) }
                        if model.resolving == service { Button("Cancel resolution") { model.cancelResolution() } }
                        Text(model.status).font(.caption)
                    }
                    .navigationTitle("Service details")
                    .toolbar { Button("Done") { model.cancelResolution(); selected = nil } }
                }
                .frame(minWidth: 350, minHeight: 400)
            }
        }
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 800)
        #endif
    }
    private func txtValue(_ value: TXTRecord.Value?) -> String {
        switch value {
        case .flag: "(flag)"
        case .bytes(let data): String(data: data, encoding: .utf8) ?? data.map { String(format: "%02x", $0) }.joined()
        case nil: ""
        }
    }
}
#Preview { ContentView() }
