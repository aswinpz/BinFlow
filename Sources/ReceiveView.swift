import SwiftUI

/// Where items without a bin wait for stock. Tap one when it arrives and give it a bin.
struct ReceiveView: View {
    @Environment(Store.self) private var store
    @State private var text = ""
    @State private var onlyUnavailable = true
    @State private var scanning = false
    @State private var adding = false
    @State private var target: MoveTarget?

    private var results: [ItemInfo] {
        let q = text.trimmed
        return store.items.filter { it in
            if onlyUnavailable && it.available { return false }
            if q.isEmpty { return true }
            return it.sku.localizedCaseInsensitiveContains(q) || it.name.localizedCaseInsensitiveContains(q)
                || it.family.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Show", selection: $onlyUnavailable) {
                        Text("Unavailable").tag(true)
                        Text("All items").tag(false)
                    }.pickerStyle(.segmented)
                } footer: { Text("Tap an item when its stock arrives, then enter the bin it goes into. The Bin cell in your sheet is filled in for you.") }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())

                Section("\(results.count) items") {
                    ForEach(results) { it in
                        Button { target = MoveTarget(id: it.sku) } label: { ItemRow(item: it) }
                            .foregroundStyle(.primary)
                    }
                }
            }
            .overlay {
                if results.isEmpty {
                    if text.isEmpty { ContentUnavailableView("Nothing waiting", systemImage: "checkmark.circle", description: Text("Every item has a bin.")) }
                    else { ContentUnavailableView.search(text: text) }
                }
            }
            .navigationTitle("Receive")
            .searchable(text: $text, prompt: "SKU or name")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { scanning = true } label: { Image(systemName: "barcode.viewfinder") }
                    Button { adding = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $scanning) { ScanSheet { text = $0 } }
            .sheet(isPresented: $adding) { EditItemSheet(sku: nil) }
            .sheet(item: $target) { AssignBinSheet(sku: $0.id, moveFrom: nil) }
        }
    }
}
