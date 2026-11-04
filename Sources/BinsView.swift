import SwiftUI
import SwiftData

struct BinsView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Bin.code) private var bins: [Bin]
    @State private var adding = false

    private var zones: [String] { Array(Set(bins.map(\.zone))).sorted() }

    var body: some View {
        NavigationStack {
            List {
                ForEach(zones, id: \.self) { z in
                    let inZone = bins.filter { $0.zone == z }
                    Section("Zone \(z) · \(inZone.map(\.used).reduce(0, +))/\(inZone.map(\.capacity).reduce(0, +))") {
                        ForEach(inZone) { b in
                            NavigationLink(value: b) { BinRow(bin: b) }
                                .swipeActions {
                                    if b.used == 0 { Button("Delete", role: .destructive) { ctx.delete(b) } }
                                }
                        }
                    }
                }
            }
            .overlay {
                if bins.isEmpty {
                    ContentUnavailableView {
                        Label("No bins", systemImage: "square.grid.3x3")
                    } description: { Text("Add bins or start with sample data.") } actions: {
                        Button("Load demo data") { Allocator.seed(ctx) }.buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Bins")
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") } }
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
                ForEach(bin.lines.sorted { $0.qty > $1.qty }) { l in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(l.item?.name ?? "–").font(.headline)
                            Text(l.item?.sku ?? "").font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(l.qty)").font(.title3.monospacedDigit())
                    }
                }
            }
        }
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
                        ctx.insert(Bin(code: code.trimmingCharacters(in: .whitespaces).uppercased(),
                                       zone: zone.uppercased(), capacity: capacity))
                        dismiss()
                    }.disabled(!valid)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
