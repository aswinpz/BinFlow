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
                                HStack(spacing: 14) {
                                    Image(systemName: "square.grid.3x3.fill")
                                        .font(.title3)
                                        .foregroundStyle(Theme.accent)
                                        .frame(width: 42, height: 42)
                                        .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(code)
                                            .font(.headline.monospaced().weight(.heavy))
                                            .foregroundStyle(.white)
                                        Text("Zone \(z.id) • Rack Location")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Tag(text: "\(store.binContents(code).count) SKUs")
                                }
                            }
                            .cardRow()
                        }
                    } header: {
                        HStack {
                            Text("Zone \(z.id)").font(.headline.weight(.bold)).foregroundStyle(.white)
                            Spacer()
                            Text("\(z.bins.count) bins").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .plainRow()
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
            .navigationTitle("Bin Explorer")
            .searchable(text: $text, prompt: "Search bin code, e.g. A02")
            .toolbar { FileMenu() }
        }
    }
}

/// Detailed Bin View (Matches "WORKOUT" screen in reference with circular dial hero)
struct BinDetail: View {
    let code: String
    @Environment(Store.self) private var store
    @State private var showingAddSheet = false

    var body: some View {
        let list = store.binContents(code)
        let zone = BinCode.zone(code)

        List {
            // Circular Dial Hero Card (Matches workout stopwatch in reference)
            VStack(spacing: 16) {
                // Dial
                ZStack {
                    Circle()
                        .stroke(Theme.cardBorder, lineWidth: 10)
                        .frame(width: 150, height: 150)

                    // Arc
                    let progress = min(Double(list.count) / 10.0, 1.0)
                    Circle()
                        .trim(from: 0, to: CGFloat(max(progress, 0.08)))
                        .stroke(Theme.mintGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 150, height: 150)

                    VStack(spacing: 2) {
                        Text("\(list.count)")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("SKUs IN BIN")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Theme.accent)
                        Text("ZONE \(zone)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 6)

                // 3 Metric Pills under Dial
                HStack(spacing: 8) {
                    detailStat(title: "ZONE", value: "Zone \(zone)")
                    detailStat(title: "SKU COUNT", value: "\(list.count)")
                    detailStat(title: "STATUS", value: list.isEmpty ? "EMPTY" : "ACTIVE", highlight: Theme.accent)
                }

                // Primary Mint CTA Button ("+ ADD SKU TO BIN")
                Button {
                    showingAddSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .black))
                        Text("ADD SKU TO THIS BIN")
                            .font(.system(size: 12, weight: .black))
                    }
                    .foregroundStyle(Color(red: 0x06/255, green: 0x15/255, blue: 0x1F/255))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Theme.mintGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Theme.accent.opacity(0.35), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.cardBorder, lineWidth: 1))
            .plainRow()

            // Header for Assigned SKUs
            HStack {
                Text("SKUS IN THIS LOCATION")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(list.count) Registered")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .plainRow()

            // Assigned SKU Rows (Matches exercise rows in reference)
            ForEach(list) { it in
                NavigationLink(value: it.sku) {
                    HStack(spacing: 12) {
                        Image(systemName: "shippingbox.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.cyan)
                            .frame(width: 40, height: 40)
                            .background(Theme.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(it.name.isEmpty ? it.sku : it.name)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(it.sku)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            let tags = [it.gender, it.category, it.family].filter { !$0.isEmpty }.joined(separator: " · ")
                            if !tags.isEmpty {
                                Text(tags)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.accent.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.accent)
                    }
                }
                .cardRow()
                .swipeActions {
                    Button("Remove", role: .destructive) {
                        store.removeBin(sku: it.sku, code: code)
                    }
                }
            }
        }
        .cardList()
        .overlay {
            if list.isEmpty {
                ContentUnavailableView("Empty Bin", systemImage: "tray", description: Text("Tap '+ ADD SKU TO THIS BIN' above to stock items here."))
            }
        }
        .navigationTitle(code)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddSheet) {
            AddSKUDirectToBinSheet(targetBin: code)
        }
    }

    private func detailStat(title: String, value: String, highlight: Color = .white) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(highlight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.cardBorder, lineWidth: 1))
    }
}

/// Sheet to directly add or scan a SKU into a specific bin
struct AddSKUDirectToBinSheet: View {
    let targetBin: String
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var skuText = ""
    @State private var scanning = false
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Enter or scan SKU", text: $skuText)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Button {
                            scanning = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                                .foregroundStyle(Theme.accent)
                        }
                    }
                } header: {
                    Text("Stock SKU into Bin \(targetBin)")
                } footer: {
                    if let p = problem {
                        Text(p).foregroundStyle(.red)
                    } else {
                        Text("Assigns this product directly to \(targetBin) and saves to your spreadsheet.")
                    }
                }

                // Suggestions from existing SKUs
                if !skuText.isEmpty {
                    let matches = store.items.filter { $0.sku.localizedCaseInsensitiveContains(skuText.trimmed) }
                    if !matches.isEmpty {
                        Section("Matching catalog SKUs") {
                            ForEach(Array(matches.prefix(5))) { it in
                                Button {
                                    skuText = it.sku
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(it.sku).font(.subheadline.bold()).foregroundStyle(.white)
                                        if !it.name.isEmpty { Text(it.name).font(.caption).foregroundStyle(.secondary) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to \(targetBin)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to Bin") {
                        if let err = store.assign(sku: skuText.trimmed, bin: targetBin) {
                            problem = err
                        } else {
                            dismiss()
                        }
                    }
                    .disabled(skuText.trimmed.isEmpty)
                }
            }
            .sheet(isPresented: $scanning) {
                ScanSheet { code in
                    skuText = code
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
