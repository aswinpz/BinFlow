import SwiftUI
import SwiftData

struct AllocateView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Item.name) private var items: [Item]
    @Query(sort: \Bin.code) private var bins: [Bin]
    @State private var item: Item?
    @State private var qty = 10
    @State private var zone = "Any"
    @State private var plan: Allocator.Plan?
    @State private var showAdd = false
    @State private var done = 0

    private var zones: [String] { ["Any"] + Array(Set(bins.map(\.zone))).sorted() }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    Picker("Item", selection: $item) {
                        Text("Select").tag(Item?.none)
                        ForEach(items) { Text("\($0.sku) · \($0.name)").tag(Optional($0)) }
                    }
                    Button("New item", systemImage: "plus") { showAdd = true }
                }
                Section("Quantity & zone") {
                    TextField("Quantity", value: $qty, format: .number).keyboardType(.numberPad)
                    Picker("Preferred zone", selection: $zone) { ForEach(zones, id: \.self) { Text($0) } }
                }
                Section {
                    Button("Suggest bins") {
                        guard let item, qty > 0 else { return }
                        plan = Allocator.plan(item: item, qty: qty, bins: bins, zone: zone == "Any" ? nil : zone)
                    }.disabled(item == nil || qty <= 0)
                }
                if let plan {
                    Section("Suggested placement") {
                        ForEach(plan.picks) { p in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.bin.code).font(.title3.monospaced().weight(.bold))
                                    Text(p.note).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("+\(p.qty)").font(.title3.monospacedDigit()).foregroundStyle(Theme.accent)
                            }
                        }
                        if plan.unplaced > 0 {
                            Label("\(plan.unplaced) units don't fit. Add bins or capacity.",
                                  systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        }
                    }
                    Section {
                        Button("Confirm allocation") {
                            guard let item else { return }
                            Allocator.commit(plan, item: item, ctx: ctx)
                            self.plan = nil; done += 1
                        }.disabled(plan.picks.isEmpty).fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle("Allocate")
            .sensoryFeedback(.success, trigger: done)
            .sheet(isPresented: $showAdd) { AddItemSheet { item = $0 } }
        }
    }
}

struct AddItemSheet: View {
    var onAdd: (Item) -> Void
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query private var items: [Item]
    @State private var sku = ""
    @State private var name = ""
    @State private var barcode = ""
    @State private var scanning = false

    private var valid: Bool {
        let s = sku.trimmingCharacters(in: .whitespaces)
        return !s.isEmpty && !name.isEmpty && !items.contains { $0.sku == s }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("SKU", text: $sku).textInputAutocapitalization(.characters)
                TextField("Name", text: $name)
                HStack {
                    TextField("Barcode (optional)", text: $barcode).keyboardType(.numbersAndPunctuation)
                    Button { scanning = true } label: { Image(systemName: "barcode.viewfinder") }
                }
            }
            .navigationTitle("New item").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let it = Item(sku: sku.trimmingCharacters(in: .whitespaces), name: name, barcode: barcode)
                        ctx.insert(it); onAdd(it); dismiss()
                    }.disabled(!valid)
                }
            }
            .sheet(isPresented: $scanning) { ScanSheet { barcode = $0 } }
        }
        .presentationDetents([.medium])
    }
}
