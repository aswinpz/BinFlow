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
        Group {
            List {
                ForEach(zones) { z in
                    Section {
                        ForEach(z.bins, id: \.self) { code in
                            NavigationLink(value: BinRef(code: code)) {
                                HStack {
                                    Text(code).font(.title3.monospaced().weight(.bold)).foregroundStyle(Theme.accent)
                                    Spacer()
                                    Tag(text: "\(store.binContents(code).count) SKUs")
                                }
                            }.cardRow()
                        }
                    } header: {
                        HStack {
                            Text("Zone \(z.id)").font(.headline)
                            Text("\(z.bins.count) bins").font(.subheadline).foregroundStyle(.secondary)
                        }.textCase(nil)
                    }
                }
            }
            .cardList()
            .overlay {
                if store.allBins.isEmpty {
                    ContentUnavailableView("No bins yet", systemImage: "square.grid.3x3",
                                           description: Text("Bins appear here once an item has a bin in your sheet."))
                } else if zones.isEmpty { ContentUnavailableView.search(text: text) }
            }
            .navigationTitle("Bins")
            .searchable(text: $text, prompt: "Bin code")
            .toolbar { FileMenu() }
        }
    }
}

struct BinDetail: View {
    let code: String
    @Environment(Store.self) private var store

    var body: some View {
        let list = store.binContents(code)
        List {
            Text("\(list.count) SKUs in \(code)").font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary).plainRow()
            ForEach(list) { it in
                NavigationLink(value: it.sku) { ItemRow(item: it) }
                    .cardRow()
                    .swipeActions {
                        Button("Remove", role: .destructive) { store.removeBin(sku: it.sku, code: code) }
                    }
            }
        }
        .cardList()
        .overlay { if list.isEmpty { ContentUnavailableView("Empty", systemImage: "tray", description: Text("No SKUs are in this bin.")) } }
        .navigationTitle(code).navigationBarTitleDisplayMode(.inline)
    }
}
