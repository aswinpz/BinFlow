import SwiftUI
import SwiftData

struct BinRow: View {
    let bin: Bin
    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 5)
                Circle().trim(from: 0, to: bin.fill)
                    .stroke(Theme.fill(bin.fill), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "shippingbox").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
            }.frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(bin.code).font(.headline.monospaced())
                Text("Zone \(bin.zone)").font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(bin.used)/\(bin.capacity)").font(.subheadline.monospacedDigit().weight(.semibold))
                Text("\(bin.free) free").font(.caption).foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, 5)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(eyebrow: "Stock lookup", title: "Find stock", subtitle: "Search a SKU, product name, barcode or bin.")
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                        TextField("Search inventory…", text: $text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if !text.isEmpty {
                            Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted) }
                        }
                        Button { scanning = true } label: {
                            Image(systemName: "barcode.viewfinder")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 13))
                        }
                        .accessibilityLabel("Scan barcode")
                    }
                    .padding(8)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(Theme.line, lineWidth: 1))

                    if text.isEmpty {
                        HStack(spacing: 10) {
                            MetricTile(title: "Products", value: "\(items.count)", symbol: "tag")
                            MetricTile(title: "Bins", value: "\(bins.count)", symbol: "square.grid.2x2")
                        }
                    }

                    if !matchedBins.isEmpty {
                        SectionLabel(title: "Matching bins", trailing: "\(matchedBins.count) found")
                        SurfaceCard {
                            ForEach(Array(matchedBins.enumerated()), id: \.element.persistentModelID) { index, bin in
                                NavigationLink(value: bin) {
                                    BinRow(bin: bin).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                if index < matchedBins.count - 1 { Divider().overlay(Theme.line) }
                            }
                        }
                    }

                    SectionLabel(title: text.isEmpty ? "All products" : "Products", trailing: "\(matchedItems.count) found")
                    if matchedItems.isEmpty {
                        ContentUnavailableView.search(text: text)
                            .frame(maxWidth: .infinity).padding(.vertical, 20)
                    } else {
                        SurfaceCard {
                            ForEach(Array(matchedItems.enumerated()), id: \.element.persistentModelID) { index, item in
                                NavigationLink(value: item) {
                                    HStack(spacing: 12) {
                                        RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.09))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "tag.fill").foregroundStyle(Theme.accent))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                            Text(item.sku).font(.caption.monospaced()).foregroundStyle(Theme.muted)
                                        }
                                        Spacer()
                                        Text("\(item.total)").font(.title3.monospacedDigit().weight(.bold)).foregroundStyle(Theme.accent)
                                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                if index < matchedItems.count - 1 { Divider().overlay(Theme.line) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 24)
            }
            .background(Theme.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $scanning) { ScanSheet { text = $0 } }
            .navigationDestination(for: Item.self) { ItemDetail(item: $0) }
            .navigationDestination(for: Bin.self) { BinDetail(bin: $0) }
        }
    }
}

struct ItemDetail: View {
    let item: Item
    @State private var picking: StockLine?
    var body: some View {
        List {
            Section {
                LabeledContent("SKU", value: item.sku)
                if !item.barcode.isEmpty { LabeledContent("Barcode", value: item.barcode) }
                LabeledContent("Total on hand", value: "\(item.total)")
            }
            Section("Locations") {
                ForEach(item.lines.sorted { $0.qty > $1.qty }) { line in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(line.bin?.code ?? "–").font(.title3.monospaced().weight(.bold))
                            Text("Zone \(line.bin?.zone ?? "–")").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(line.qty)").font(.title3.monospacedDigit().weight(.semibold))
                    }
                    .swipeActions { Button("Pick") { picking = line }.tint(.orange) }
                    .contentShape(Rectangle()).onTapGesture { picking = line }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Theme.canvas)
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
                    Stepper("Quantity: \(qty) of \(line.qty)", value: $qty, in: 1...max(line.qty, 1))
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
