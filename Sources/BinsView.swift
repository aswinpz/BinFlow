import SwiftUI
import SwiftData

struct BinsView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Bin.code) private var bins: [Bin]
    @State private var adding = false
    private var zones: [String] { Array(Set(bins.map(\.zone))).sorted() }
    private var totalCapacity: Int { bins.reduce(0) { $0 + $1.capacity } }
    private var totalUsed: Int { bins.reduce(0) { $0 + $1.used } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(eyebrow: "Warehouse layout", title: "Your bins", subtitle: "Capacity and stock by storage zone.")
                    HStack(spacing: 10) {
                        MetricTile(title: "Total bins", value: "\(bins.count)", symbol: "square.grid.2x2")
                        MetricTile(title: "Units stored", value: "\(totalUsed)", symbol: "shippingbox")
                    }
                    if !bins.isEmpty {
                        SurfaceCard {
                            HStack {
                                Text("Overall capacity").font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(totalUsed) / \(totalCapacity)").font(.subheadline.monospacedDigit().weight(.bold))
                            }
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.line)
                                    Capsule().fill(Theme.fill(totalCapacity == 0 ? 0 : Double(totalUsed) / Double(totalCapacity)))
                                        .frame(width: proxy.size.width * (totalCapacity == 0 ? 0 : min(Double(totalUsed) / Double(totalCapacity), 1)))
                                }
                            }.frame(height: 9)
                        }
                    }
                    ForEach(zones, id: \.self) { zone in
                        let group = bins.filter { $0.zone == zone }
                        SectionLabel(title: "Zone \(zone)", trailing: "\(group.count) bins · \(group.reduce(0) { $0 + $1.used }) / \(group.reduce(0) { $0 + $1.capacity }) units")
                        SurfaceCard {
                            ForEach(Array(group.enumerated()), id: \.element.persistentModelID) { index, bin in
                                NavigationLink(value: bin) {
                                    BinRow(bin: bin).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                .swipeActions {
                                    if bin.used == 0 {
                                        Button("Delete", role: .destructive) { ctx.delete(bin) }
                                    }
                                }
                                if index < group.count - 1 { Divider().overlay(Theme.line) }
                            }
                        }
                    }
                    if bins.isEmpty {
                        ContentUnavailableView {
                            Label("No bins yet", systemImage: "square.grid.2x2")
                        } description: { Text("Create your first storage bin or load sample data.") } actions: {
                            Button("Load sample data") { Allocator.seed(ctx) }.buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 28)
            }
            .background(Theme.canvas).toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                Button { adding = true } label: {
                    Label("Add a bin", systemImage: "plus")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                }
                .buttonStyle(.borderedProminent).tint(Theme.accent)
                .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 4)
                .background(.ultraThinMaterial)
            }
            .sheet(isPresented: $adding) { AddBinSheet(existing: bins.map(\.code)) }
            .navigationDestination(for: Bin.self) { BinDetail(bin: $0) }
        }
    }
}

struct BinDetail: View {
    let bin: Bin
    var body: some View {
        List {
            Section { BinRow(bin: bin) }
            Section("Contents") {
                if bin.lines.isEmpty { Text("Empty").foregroundStyle(.secondary) }
                ForEach(bin.lines.sorted { $0.qty > $1.qty }) { line in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(line.item?.name ?? "–").font(.headline)
                            Text(line.item?.sku ?? "").font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(line.qty)").font(.title3.monospacedDigit())
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Theme.canvas)
        .navigationTitle(bin.code).navigationBarTitleDisplayMode(.inline)
    }
}

struct AddBinSheet: View {
    let existing: [String]
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var zone = ""
    @State private var capacity = 100
    private var valid: Bool {
        let c = code.trimmingCharacters(in: .whitespaces).uppercased()
        return !c.isEmpty && !zone.isEmpty && capacity > 0 && !existing.contains(c)
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Bin code (e.g. A-07)", text: $code).textInputAutocapitalization(.characters)
                TextField("Zone (e.g. A)", text: $zone).textInputAutocapitalization(.characters)
                TextField("Capacity (units)", value: $capacity, format: .number).keyboardType(.numberPad)
            }
            .navigationTitle("New bin").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        ctx.insert(Bin(code: code.trimmingCharacters(in: .whitespaces).uppercased(), zone: zone.uppercased(), capacity: capacity))
                        dismiss()
                    }.disabled(!valid)
                }
            }
        }.presentationDetents([.medium])
    }
}
