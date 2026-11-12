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
        Group {
            List {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Show", selection: $onlyUnavailable) {
                        Text("Unavailable").tag(true)
                        Text("All items").tag(false)
                    }.pickerStyle(.segmented)
                    Text("Tap an item when its stock arrives, then enter the bin it goes into.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.plainRow()

                ForEach(results) { it in
                    Button { target = MoveTarget(id: it.sku) } label: { ItemRow(item: it) }
                        .foregroundStyle(.primary).cardRow()
                }
            }
            .cardList()
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
                    Button { scanning = true } label: {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 46, height: 46)
                            .background(Theme.accent.opacity(0.14), in: Circle())
                            .overlay(Circle().stroke(Theme.accent.opacity(0.5), lineWidth: 1))
                    }
                    .accessibilityLabel("Scan SKU with OCR")
                    Button { adding = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $scanning) { ScanSheet { text = $0 } }
            .sheet(isPresented: $adding) { EditItemSheet(sku: nil) }
            .sheet(item: $target) { AssignBinSheet(sku: $0.id, moveFrom: nil) }
        }
    }
}
