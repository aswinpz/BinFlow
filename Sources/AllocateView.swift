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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(eyebrow: "Stock movement", title: "Allocate", subtitle: "Find the best bin for incoming stock.")
                    SurfaceCard {
                        Label("PRODUCT", systemImage: "tag").font(.caption.weight(.bold)).tracking(1).foregroundStyle(Theme.accent)
                        Picker("Choose product", selection: $item) {
                            Text("Select an item").tag(Item?.none)
                            ForEach(items) { Text("\($0.sku) · \($0.name)").tag(Optional($0)) }
                        }
                        .pickerStyle(.menu).tint(Theme.ink)
                        Divider()
                        Button { showAdd = true } label: {
                            Label("Create new product", systemImage: "plus.circle.fill")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                        }
                    }
                    SurfaceCard {
                        Label("QUANTITY & ZONE", systemImage: "slider.horizontal.3").font(.caption.weight(.bold)).tracking(1).foregroundStyle(Theme.accent)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Incoming quantity").font(.subheadline.weight(.medium))
                                Text("Units to place").font(.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Stepper("\(qty)", value: $qty, in: 1...99999).fixedSize()
                        }
                        Divider()
                        Picker("Preferred zone", selection: $zone) {
                            ForEach(zones, id: \.self) { Text($0 == "Any" ? "Any zone" : "Zone \($0)") }
                        }.tint(Theme.ink)
                    }
                    Button {
                        guard let item, qty > 0 else { return }
                        plan = Allocator.plan(item: item, qty: qty, bins: bins, zone: zone == "Any" ? nil : zone)
                    } label: {
                        Label("Suggest best bins", systemImage: "sparkles")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
                    .disabled(item == nil || bins.isEmpty)

                    if let plan {
                        SectionLabel(title: "Suggested placement", trailing: "\(plan.picks.count) bins")
                        SurfaceCard {
                            ForEach(plan.picks) { pick in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(pick.bin.code).font(.title3.monospaced().weight(.bold))
                                        Text(pick.note).font(.caption).foregroundStyle(Theme.muted)
                                    }
                                    Spacer()
                                    Text("+\(pick.qty)").font(.title3.monospacedDigit().weight(.bold)).foregroundStyle(Theme.accent)
                                }
                            }
                            if plan.unplaced > 0 {
                                Label("\(plan.unplaced) units don't fit. Add bins or capacity.", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                        }
                        Button {
                            guard let item else { return }
                            Allocator.commit(plan, item: item, ctx: ctx)
                            self.plan = nil; done += 1
                        } label: {
                            Label("Confirm allocation", systemImage: "checkmark.circle.fill")
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent).tint(Theme.accent).disabled(plan.picks.isEmpty)
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 28)
            }
            .background(Theme.canvas).toolbar(.hidden, for: .navigationBar)
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
            .navigationTitle("New product").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let item = Item(sku: sku.trimmingCharacters(in: .whitespaces), name: name, barcode: barcode)
                        ctx.insert(item); onAdd(item); dismiss()
                    }.disabled(!valid)
                }
            }
            .sheet(isPresented: $scanning) { ScanSheet { barcode = $0 } }
        }.presentationDetents([.medium])
    }
}
