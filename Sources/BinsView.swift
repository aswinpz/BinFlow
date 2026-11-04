import SwiftUI

struct BinsView: View {
    @Environment(Store.self) private var store
    @State private var text = ""

    private struct ZoneGroup: Identifiable { let id: String; let bins: [String] }

    private var zones: [ZoneGroup] {
        let q = text.trimmed
        let bins = q.isEmpty ? store.allBins : store.allBins.filter { $0.localizedCaseInsensitiveContains(q) }
        let grouped = Dictionary(grouping: bins) { BinCode.zone($0) }
        return grouped.keys.sorted().map { ZoneGroup(id: $0, bins: grouped[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(zones) { z in
                    Section("Zone \(z.id) · \(z.bins.count) bins") {
                        ForEach(z.bins, id: \.self) { code in
                            NavigationLink(value: BinRef(code: code)) {
                                HStack {
                                    Text(code).font(.headline.monospaced())
                                    Spacer()
                                    Text("\(store.binContents(code).count) SKUs").font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if store.allBins.isEmpty {
                    ContentUnavailableView("No bins yet", systemImage: "square.grid.3x3",
                                           description: Text("Bins appear here once an item has a bin in your sheet."))
                } else if zones.isEmpty { ContentUnavailableView.search(text: text) }
            }
            .navigationTitle("Bins")
            .searchable(text: $text, prompt: "Bin code")
            .toolbar { FileMenu() }
            .binflowDestinations()
        }
    }
}

struct BinDetail: View {
    let code: String
    @Environment(Store.self) private var store

    var body: some View {
        let list = store.binContents(code)
        List {
            Section("\(list.count) SKUs in \(code)") {
                ForEach(list) { it in
                    NavigationLink(value: it.sku) { ItemRow(item: it) }
                        .swipeActions {
                            Button("Remove", role: .destructive) { store.removeBin(sku: it.sku, code: code) }
                        }
                }
            }
        }
        .overlay { if list.isEmpty { ContentUnavailableView("Empty", systemImage: "tray", description: Text("No SKUs are in this bin.")) } }
        .navigationTitle(code).navigationBarTitleDisplayMode(.inline)
    }
}
