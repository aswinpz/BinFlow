import SwiftUI
import SwiftData

struct BinRow: View {
    let bin: Bin
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 5)
                Circle().trim(from: 0, to: bin.fill)
                    .stroke(Theme.fill(bin.fill), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }.frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(bin.code).font(.headline.monospaced())
                Text("Zone \(bin.zone)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(bin.used)/\(bin.capacity)").font(.subheadline.monospacedDigit())
                Text("\(bin.free) free").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct FindView: View {
    @Query(sort: \Item.name) private var items: [Item]
    @Query(sort: \Bin.code) private var bins: [Bin]
    @State private var text = ""
    @State private var scanning = false

    private var matchedItems: [Item] {
        guard !text.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(text) ||
            $0.sku.localizedCaseInsensitiveContains(text) || $0.barcode == text
        }
    }
    private var matchedBins: [Bin] {
        guard !text.isEmpty else { return [] }
        return bins.filter { $0.code.localizedCaseInsensitiveContains(text) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !matchedBins.isEmpty {
                    Section("Bins") {
                        ForEach(matchedBins) { b in
                            NavigationLink(value: b) { BinRow(bin: b) }
                        }
                    }
                }
                Section(text.isEmpty ? "All items" : "Items") {
                    ForEach(matchedItems) { it in
                        NavigationLink(value: it) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(it.name).font(.headline)
                                    Text(it.sku).font(.caption.monospaced()).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(it.total)").font(.title3.monospacedDigit().weight(.semibold))
                            }
                        }
                    }
                }
            }
            .overlay {
                if items.isEmpty { ContentUnavailableView("No stock yet", systemImage: "shippingbox",
                    description: Text("Add items in Allocate, or load demo data in Bins.")) }
                else if matchedItems.isEmpty && matchedBins.isEmpty { ContentUnavailableView.search(text: text) }
            }
            .navigationTitle("Find")
            .searchable(text: $text, prompt: "SKU, name, barcode or bin")
            .toolbar { Button { scanning = true } label: { Image(systemName: "barcode.viewfinder") } }
            .sheet(isPresented: $scanning) { ScanSheet { text = $0 } }
            .navigationDestination(for: Item.self) { ItemDetail(item: $0) }
            .navigationDestination(for: Bin.self) { BinDetail(bin: $0) }
        }
    }
}

struct ItemDetail: View {
    let item: Item
    @Environment(\.modelContext) private var ctx
    @State private var picking: StockLine?

    var body: some View {
        List {
            Section {
                LabeledContent("SKU", value: item.sku)
                if !item.barcode.isEmpty { LabeledContent("Barcode", value: item.barcode) }
                LabeledContent("Total on hand", value: "\(item.total)")
            }
            Section("Locations") {
                ForEach(item.lines.sorted { $0.qty > $1.qty }) { l in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(l.bin?.code ?? "–").font(.title3.monospaced().weight(.bold))
                            Text("Zone \(l.bin?.zone ?? "–")").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(l.qty)").font(.title3.monospacedDigit())
                    }
                    .swipeActions { Button("Pick") { picking = l }.tint(.orange) }
                    .contentShape(Rectangle())
                    .onTapGesture { picking = l }
                }
            }
        }
        .navigationTitle(item.name).navigationBarTitleDisplayMode(.inline)
        .sheet(item: $picking) { PickSheet(line: $0) }
    }
}

struct PickSheet: View {
    let line: StockLine
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var qty = 1

    var body: some View {
        NavigationStack {
            Form {
                Section("Pick from \(line.bin?.code ?? "")") {
                    Stepper("\(qty) of \(line.qty)", value: $qty, in: 1...max(line.qty, 1))
                    Button("Pick all \(line.qty)") { qty = line.qty }
                }
            }
            .navigationTitle(line.item?.name ?? "Pick").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") { Allocator.pick(line: line, qty: qty, ctx: ctx); dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
