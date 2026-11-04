import SwiftUI

struct ItemRow: View {
    let item: ItemInfo
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name.isEmpty ? item.sku : item.name).font(.headline).lineLimit(2)
                Text(item.sku).font(.caption.monospaced()).foregroundStyle(.secondary)
                let sub = [item.gender, item.category, item.family].filter { !$0.isEmpty }.joined(separator: " · ")
                if !sub.isEmpty { Text(sub).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer(minLength: 8)
            if item.available {
                Text(item.bins.joined(separator: "\n"))
                    .font(.subheadline.monospaced().weight(.semibold)).multilineTextAlignment(.trailing)
                    .foregroundStyle(Theme.accent)
            } else {
                Text("Unavailable").font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.orange.opacity(0.18), in: Capsule()).foregroundStyle(.orange)
            }
        }
    }
}

struct FindView: View {
    @Environment(Store.self) private var store
    @State private var text = ""
    @State private var filter = Filter.all
    @State private var scanning = false
    @State private var adding = false

    enum Filter: String, CaseIterable { case all = "All", available = "Available", unavailable = "Unavailable" }

    private var results: [ItemInfo] {
        let q = text.trimmed
        return store.items.filter { it in
            if filter == .available && !it.available { return false }
            if filter == .unavailable && it.available { return false }
            if q.isEmpty { return true }
            return it.sku.localizedCaseInsensitiveContains(q) || it.name.localizedCaseInsensitiveContains(q)
                || it.family.localizedCaseInsensitiveContains(q) || it.category.localizedCaseInsensitiveContains(q)
                || it.bins.contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Show", selection: $filter) {
                        ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())

                Section("\(results.count) items") {
                    ForEach(results) { it in
                        NavigationLink(value: it.sku) { ItemRow(item: it) }
                    }
                }
            }
            .overlay {
                if store.items.isEmpty {
                    ContentUnavailableView("No items", systemImage: "shippingbox", description: Text("Sheet1 has no rows with a Product SKU."))
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: text)
                }
            }
            .navigationTitle("Find")
            .searchable(text: $text, prompt: "SKU, name, family or bin")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { scanning = true } label: { Image(systemName: "barcode.viewfinder") }
                    Button { adding = true } label: { Image(systemName: "plus") }
                    FileMenu()
                }
            }
            .sheet(isPresented: $scanning) { ScanSheet { text = $0 } }
            .sheet(isPresented: $adding) { EditItemSheet(sku: nil) }
            .binflowDestinations()
        }
    }
}

struct FileMenu: View {
    @Environment(Store.self) private var store
    var body: some View {
        Menu {
            Text(store.fileName)
            Button("Reload from file", systemImage: "arrow.clockwise") { store.reload() }
            Button("Choose a different file", systemImage: "folder") { store.showPicker = true }
            if let url = store.fileURL { ShareLink("Share / back up a copy", item: url) }
        } label: { Image(systemName: "ellipsis.circle") }
    }
}

struct ItemDetail: View {
    let sku: String
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var assigning = false
    @State private var editing = false
    @State private var moving: MoveTarget?
    @State private var confirmClear = false
    @State private var confirmDelete = false

    var body: some View {
        if let item = store.item(sku) {
            List {
                Section {
                    LabeledContent("SKU", value: item.sku)
                    if !item.name.isEmpty { LabeledContent("Name", value: item.name) }
                    if !item.gender.isEmpty { LabeledContent("Gender", value: item.gender) }
                    if !item.category.isEmpty { LabeledContent("Category", value: item.category) }
                    if !item.family.isEmpty { LabeledContent("Family", value: item.family) }
                }
                if item.available {
                    Section("Bins") {
                        ForEach(item.bins, id: \.self) { code in
                            NavigationLink(value: BinRef(code: code)) {
                                VStack(alignment: .leading) {
                                    Text(code).font(.title3.monospaced().weight(.bold))
                                    Text("Zone \(BinCode.zone(code))").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions {
                                Button("Remove", role: .destructive) { store.removeBin(sku: sku, code: code) }
                                Button("Move") { moving = MoveTarget(id: code) }.tint(.orange)
                            }
                        }
                        Button("Add another bin", systemImage: "plus.circle") { assigning = true }
                        Button("Mark unavailable", systemImage: "xmark.circle", role: .destructive) { confirmClear = true }
                    } footer: { Text("Swipe a bin to move or remove it. Removing the last bin makes the item unavailable.") }
                } else {
                    Section {
                        Label("Unavailable: no bin in the sheet", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Button { assigning = true } label: {
                            Label("Stock arrived: assign bin", systemImage: "shippingbox.and.arrow.backward").fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle(item.name.isEmpty ? item.sku : item.name).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Menu {
                    Button("Edit details", systemImage: "pencil") { editing = true }
                    Button("Delete item", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: { Image(systemName: "ellipsis.circle") }
            }
            .sheet(isPresented: $assigning) { AssignBinSheet(sku: sku, moveFrom: nil) }
            .sheet(item: $moving) { AssignBinSheet(sku: sku, moveFrom: $0.id) }
            .sheet(isPresented: $editing) { EditItemSheet(sku: sku) }
            .confirmationDialog("Mark \(item.sku) unavailable?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear all bins", role: .destructive) { store.markUnavailable(sku: sku) }
            } message: { Text("The Bin cell in your sheet will be emptied.") }
            .confirmationDialog("Delete \(item.sku)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete from sheet", role: .destructive) { store.deleteItem(sku: sku); dismiss() }
            } message: { Text("All rows for this SKU are removed from your spreadsheet.") }
        } else {
            ContentUnavailableView("Item not found", systemImage: "questionmark.folder")
        }
    }
}

struct MoveTarget: Identifiable { let id: String }

/// Assigns a bin (stock arrived) or moves an existing bin when `moveFrom` is set.
struct AssignBinSheet: View {
    let sku: String
    let moveFrom: String?
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var problem: String?

    private var codes: [String] { BinCode.parse(text) }
    private var suggestions: [String] {
        let q = text.trimmed.uppercased()
        guard !q.isEmpty else { return [] }
        return Array(store.allBins.filter { $0.hasPrefix(q) }.prefix(12))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Bin, e.g. A12 or A22,23", text: $text)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                } header: {
                    Text(moveFrom.map { "Move \(sku) from \($0) to" } ?? "Put \(sku) in")
                } footer: {
                    if let p = problem { Text(p).foregroundStyle(.red) }
                    else if !codes.isEmpty {
                        let newOnes = codes.filter { !store.allBins.contains($0) }
                        Text("Will be saved as \(codes.joined(separator: ", "))" + (newOnes.isEmpty ? "" : " · new bin: \(newOnes.joined(separator: ", "))"))
                    }
                }
                if !suggestions.isEmpty {
                    Section("Existing bins") {
                        ForEach(suggestions, id: \.self) { b in
                            Button { text = b } label: {
                                HStack { Text(b).font(.body.monospaced()); Spacer()
                                    Text("\(store.items(inBin: b).count) SKUs").font(.caption).foregroundStyle(.secondary) }
                            }.foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle(moveFrom == nil ? "Assign bin" : "Move").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let err: String?
                        if let from = moveFrom {
                            err = store.moveBin(sku: sku, from: from, to: text)
                        } else {
                            err = store.assign(sku: sku, bin: text)
                        }
                        if let err { problem = err } else { dismiss() }
                    }.disabled(codes.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// New item (sku == nil) or edit details of an existing one.
struct EditItemSheet: View {
    let sku: String?
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var skuText = ""
    @State private var name = ""
    @State private var gender = ""
    @State private var category = ""
    @State private var family = ""
    @State private var bin = ""
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("SKU", text: $skuText).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    TextField("Name", text: $name)
                    TextField("Gender (Men, Women, Unisex)", text: $gender)
                    TextField("Category (Sneakers, Sandals...)", text: $category)
                    TextField("Product family", text: $family)
                }
                if sku == nil {
                    Section {
                        TextField("Bin (optional)", text: $bin).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    } footer: { Text("Leave empty if the item hasn't arrived yet: it will show as Unavailable until you assign a bin.") }
                }
                if let problem { Section { Text(problem).foregroundStyle(.red) } }
            }
            .navigationTitle(sku == nil ? "New item" : "Edit item").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(sku == nil ? "Add" : "Save") {
                        let err: String?
                        if let sku {
                            err = store.updateItem(sku: sku, newSku: skuText, name: name, gender: gender, category: category, family: family)
                        } else {
                            err = store.addItem(sku: skuText, name: name, gender: gender, category: category, family: family, bin: bin)
                        }
                        if let err { problem = err } else { dismiss() }
                    }.disabled(skuText.trimmed.isEmpty)
                }
            }
            .onAppear {
                if let sku, let it = store.item(sku) {
                    skuText = it.sku; name = it.name; gender = it.gender; category = it.category; family = it.family
                }
            }
        }
    }
}
