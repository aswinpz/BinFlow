import SwiftUI
import Observation

// MARK: - Value types

struct ItemInfo: Identifiable, Hashable, Sendable {
    var id: String { sku }
    let sku: String
    var name = "", gender = "", category = "", family = ""
    var bins: [String] = []
    /// A SKU with no bin in the sheet is unavailable.
    var available: Bool { !bins.isEmpty }
}

struct BinRef: Hashable { let code: String }

struct ItemSearchDocument: Sendable {
    let item: ItemInfo
    let normalizedSKU: String
    let searchableText: String
    let isAvailable: Bool
}

struct LogEntry: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var kind: String          // In, Out, New, Edit, Delete
    var sku: String
    var name: String
    var bin: String
}

enum BinCode {
    /// Turns the text in the Bin column into clean codes.
    /// "A22,23" -> [A22, A23]   "C06,07,08,09" -> [C06...C09]   "B2" -> [B02]   "EO8" -> [E08]   "B05,B10" -> [B05, B10]
    static func parse(_ raw: String) -> [String] {
        var out: [String] = []
        var zone = ""
        let pieces = raw.uppercased().components(separatedBy: CharacterSet(charactersIn: ",;/\n\t "))
        for piece in pieces where !piece.isEmpty {
            var digits = piece
            if let f = piece.first, f.isLetter {
                zone = String(f)
                digits = String(piece.dropFirst())
            }
            digits = digits.replacingOccurrences(of: "O", with: "0")
            var code = zone
            if !digits.isEmpty {
                if digits.count == 1, digits.allSatisfy({ $0.isNumber }) { digits = "0" + digits }
                code = zone + digits
            }
            if !code.isEmpty && !out.contains(code) { out.append(code) }
        }
        return out
    }
    static func zone(_ code: String) -> String { code.first.map { String($0) } ?? "?" }
}

enum SearchText {
    static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

// MARK: - Store

@Observable
final class Store {
    var items: [ItemInfo] = []
    var allBins: [String] = []
    var hasFile = false
    var fileName = ""
    var error: String?
    var showPicker = false
    var log: [LogEntry] = []
    private(set) var searchRevision = 0
    private(set) var availableCount = 0
    private(set) var unavailableCount = 0
    private(set) var isSaving = false
    private(set) var fileURL: URL?

    @ObservationIgnored private var rows: [SheetRow] = []
    @ObservationIgnored private var workbook: Workbook?
    @ObservationIgnored private var itemIndex: [String: ItemInfo] = [:]
    @ObservationIgnored private var binIndex: [String: [String]] = [:]
    @ObservationIgnored private(set) var searchDocuments: [ItemSearchDocument] = []
    @ObservationIgnored private var loadedData = Data()
    @ObservationIgnored private var loadedStamp: Date?
    @ObservationIgnored private var scoped = false

    private let bookmarkKey = "binflow.bookmark"
    private let logKey = "binflow.log"

    init() {
        if let d = UserDefaults.standard.data(forKey: logKey),
           let l = try? JSONDecoder().decode([LogEntry].self, from: d) { log = l }
        restore()
    }

    // MARK: Lookup

    func item(_ sku: String) -> ItemInfo? { itemIndex[sku] }
    func binContents(_ code: String) -> [ItemInfo] { (binIndex[code] ?? []).compactMap { itemIndex[$0] } }

    private func rebuild() {
        var order: [String] = []
        var map: [String: ItemInfo] = [:]
        var bins: [String: [String]] = [:]
        for r in rows where !r.sku.isEmpty {
            var it = map[r.sku] ?? {
                order.append(r.sku)
                return ItemInfo(sku: r.sku)
            }()
            if it.name.isEmpty { it.name = r.name }
            if it.gender.isEmpty { it.gender = r.gender }
            if it.category.isEmpty { it.category = r.category }
            if it.family.isEmpty { it.family = r.family }
            for c in BinCode.parse(r.bin) where !it.bins.contains(c) {
                it.bins.append(c)
                bins[c, default: []].append(r.sku)
            }
            map[r.sku] = it
        }
        itemIndex = map
        binIndex = bins
        items = order.compactMap { map[$0] }
        allBins = bins.keys.sorted()
        searchDocuments = items.map { item in
            let fields = [item.sku, item.name, item.family, item.category, item.bins.joined(separator: " ")]
            return ItemSearchDocument(item: item, normalizedSKU: SearchText.normalized(item.sku),
                                      searchableText: SearchText.normalized(fields.joined(separator: " ")),
                                      isAvailable: item.available)
        }
        availableCount = items.filter(\.available).count
        unavailableCount = items.count - availableCount
        searchRevision &+= 1
    }

    // MARK: File access

    func choose(_ url: URL) { openFile(url) }

    private func openFile(_ url: URL) {
        if scoped, let old = fileURL { old.stopAccessingSecurityScopedResource() }
        scoped = url.startAccessingSecurityScopedResource()
        fileURL = url
        do {
            try load()
            if let b = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(b, forKey: bookmarkKey)
            }
        } catch {
            hasFile = false
            self.error = "Couldn't open the spreadsheet: \(error.localizedDescription)"
        }
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        var stale = false
        if let u = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) {
            openFile(u)
        }
    }

    private func load() throws {
        guard let url = fileURL else { return }
        let data = try Self.readData(url)
        let wb = try Workbook.load(data)
        workbook = wb
        rows = wb.rows
        loadedData = data
        loadedStamp = Self.modDate(url)
        fileName = url.lastPathComponent
        hasFile = true
        rebuild()
    }

    func reload() {
        do { try load() } catch { self.error = "Couldn't reload: \(error.localizedDescription)" }
    }

    /// Forgets the connected spreadsheet (the file itself is not touched).
    func disconnect() {
        if scoped, let old = fileURL { old.stopAccessingSecurityScopedResource() }
        scoped = false
        fileURL = nil
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        rows = []; workbook = nil
        items = []; allBins = []; itemIndex = [:]; binIndex = [:]
        loadedData = Data(); loadedStamp = nil
        fileName = ""; hasFile = false
    }

    func clearLog() {
        log = []
        UserDefaults.standard.removeObject(forKey: logKey)
    }

    /// Called when the app comes to the foreground: picks up edits made in Excel.
    func refreshFromDisk() {
        guard hasFile, let url = fileURL, Self.modDate(url) != loadedStamp else { return }
        if let d = try? Self.readData(url), d != loadedData { _ = try? load() } else { loadedStamp = Self.modDate(url) }
    }

    private static func modDate(_ u: URL) -> Date? {
        (try? u.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    private static func readData(_ url: URL) throws -> Data {
        var coordError: NSError?
        var result: Result<Data, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { u in
            result = Result { try Data(contentsOf: u) }
        }
        if let coordError { throw coordError }
        guard let result else { throw XLSXError.missing("file") }
        return try result.get()
    }

    private static func writeData(_ data: Data, to url: URL) throws {
        var coordError: NSError?
        var failure: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { u in
            do { try data.write(to: u) } catch { failure = error }
        }
        if let coordError { throw coordError }
        if let failure { throw failure }
    }

    private enum SaveResult { case ok, failed(String), reloaded }

    private func save() -> SaveResult {
        guard var wb = workbook, let url = fileURL else { return .failed("no file selected") }
        // Someone else (Excel, OneDrive...) changed the file since we read it? Don't overwrite their work.
        if let stamp = loadedStamp, Self.modDate(url) != stamp,
           let current = try? Self.readData(url), current != loadedData {
            reload()
            return .reloaded
        }
        do {
            wb.rows = rows
            let data = try wb.serialize()
            try Self.writeData(data, to: url)
            workbook = wb
            loadedData = data
            loadedStamp = Self.modDate(url)
            return .ok
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private enum SnapshotSaveResult: Sendable {
        case saved(Data, Date?)
        case conflict
        case failed(String)
    }

    /// Serializes and writes a workbook snapshot away from the UI thread.
    @MainActor private func persistRowsInBackground(_ nextRows: [SheetRow]) async -> String? {
        guard !isSaving else { return "Please wait for the current save to finish." }
        guard var nextWorkbook = workbook, let url = fileURL else { return "Choose an Excel file before making changes." }
        nextWorkbook.rows = nextRows
        let writeWorkbook = nextWorkbook
        let expectedData = loadedData
        let expectedStamp = loadedStamp

        isSaving = true
        let outcome = await Task.detached(priority: .userInitiated) {
            if let stamp = expectedStamp, Store.modDate(url) != stamp,
               let current = try? Store.readData(url), current != expectedData {
                return SnapshotSaveResult.conflict
            }
            do {
                let data = try writeWorkbook.serialize()
                try Store.writeData(data, to: url)
                return SnapshotSaveResult.saved(data, Store.modDate(url))
            } catch {
                return SnapshotSaveResult.failed(error.localizedDescription)
            }
        }.value
        isSaving = false

        switch outcome {
        case .saved(let data, let stamp):
            rows = nextRows
            workbook = nextWorkbook
            loadedData = data
            loadedStamp = stamp
            rebuild()
            return nil
        case .conflict:
            _ = try? load()
            return "The spreadsheet changed in another app and was reloaded. Please repeat your change."
        case .failed(let message):
            return "Couldn't save the spreadsheet (\(message)). Your change was not applied."
        }
    }

    private func record(_ entries: [LogEntry]) {
        log.insert(contentsOf: entries.reversed(), at: 0)
        if log.count > 300 { log.removeLast(log.count - 300) }
        if let encoded = try? JSONEncoder().encode(log) { UserDefaults.standard.set(encoded, forKey: logKey) }
    }

    /// Runs a change, writes it to the spreadsheet, and rolls back if the write fails.
    private func apply(_ entries: [LogEntry], _ change: () -> Void) {
        let backup = rows
        change()
        rebuild()
        switch save() {
        case .ok:
            record(entries)
        case .failed(let msg):
            rows = backup; rebuild()
            error = "Couldn't save to the spreadsheet (\(msg)). Your change was not applied."
        case .reloaded:
            error = "The spreadsheet was changed by another app, so I reloaded it. Please repeat your last change."
        }
    }

    private func entry(_ kind: String, _ sku: String, _ bin: String = "") -> LogEntry {
        LogEntry(kind: kind, sku: sku, name: itemIndex[sku]?.name ?? "", bin: bin)
    }

    private func extraRow(like base: SheetRow, bin: String) -> SheetRow {
        SheetRow(gender: base.gender, category: base.category, family: base.family,
                 sku: base.sku, name: base.name, bin: bin)
    }

    // MARK: Edits (each one is saved to the Excel file immediately)

    /// Stock arrived: put the SKU into one or more bins.
    @MainActor func assign(sku: String, bin: String) async -> String? {
        let codes = BinCode.parse(bin)
        guard !codes.isEmpty else { return "Enter a bin such as A12." }
        guard let existing = itemIndex[sku], let base = rows.first(where: { $0.sku == sku }) else { return "Unknown SKU." }
        let fresh = codes.filter { !existing.bins.contains($0) }
        guard !fresh.isEmpty else { return "\(sku) is already in \(codes.joined(separator: ", "))." }
        var nextRows = rows
        for c in fresh {
            if let i = nextRows.firstIndex(where: { $0.sku == sku && BinCode.parse($0.bin).isEmpty }) {
                nextRows[i].bin = c
            } else {
                nextRows.append(extraRow(like: base, bin: c))
            }
        }
        let entries = fresh.map { entry("In", sku, $0) }
        if let message = await persistRowsInBackground(nextRows) { return message }
        record(entries)
        return nil
    }

    private func dropBin(_ code: String, sku: String) {
        for idx in rows.indices.reversed() where rows[idx].sku == sku {
            let codes = BinCode.parse(rows[idx].bin)
            guard codes.contains(code) else { continue }
            let rest = codes.filter { $0 != code }
            if !rest.isEmpty {
                rows[idx].bin = rest.joined(separator: ",")
            } else if rows[idx].name.isEmpty && rows.contains(where: { $0.sku == sku && !$0.name.isEmpty }) {
                rows.remove(at: idx)             // extra location row: remove it entirely
            } else {
                rows[idx].bin = ""               // main row: keep it, blank bin = unavailable
            }
        }
    }

    func removeBin(sku: String, code: String) {
        apply([entry("Out", sku, code)]) { dropBin(code, sku: sku) }
    }

    func markUnavailable(sku: String) {
        guard let it = itemIndex[sku] else { return }
        apply(it.bins.map { entry("Out", sku, $0) }) { for c in it.bins { dropBin(c, sku: sku) } }
    }

    func moveBin(sku: String, from: String, to: String) -> String? {
        guard let dest = BinCode.parse(to).first else { return "Enter a bin such as A12." }
        guard dest != from else { return nil }
        guard let it = itemIndex[sku], !it.bins.contains(dest) else { return "\(sku) is already in \(dest)." }
        apply([entry("Out", sku, from), entry("In", sku, dest)]) {
            for idx in rows.indices where rows[idx].sku == sku {
                var codes = BinCode.parse(rows[idx].bin)
                if let k = codes.firstIndex(of: from) {
                    codes[k] = dest
                    rows[idx].bin = codes.joined(separator: ",")
                }
            }
        }
        return nil
    }

    @MainActor func addItem(sku rawSku: String, name: String, gender: String, category: String, family: String, bin: String) async -> String? {
        let sku = rawSku.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sku.isEmpty else { return "SKU is required." }
        guard itemIndex[sku] == nil else { return "SKU \(sku) already exists." }
        guard !isSaving else { return "Please wait for the current save to finish." }
        guard workbook != nil, fileURL != nil else { return "Choose an Excel file before adding a SKU." }

        let codes = BinCode.parse(bin)
        let main = SheetRow(gender: gender.trimmed, category: category.trimmed, family: family.trimmed,
                            sku: sku, name: name.trimmed, bin: codes.first ?? "")
        var nextRows = rows
        nextRows.append(main)
        for c in codes.dropFirst() { nextRows.append(extraRow(like: main, bin: c)) }
        if let message = await persistRowsInBackground(nextRows) { return message }
        record([LogEntry(kind: "New", sku: sku, name: main.name, bin: codes.joined(separator: ","))])
        return nil
    }

    func updateItem(sku: String, newSku rawNew: String, name: String, gender: String, category: String, family: String) -> String? {
        let newSku = rawNew.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newSku.isEmpty else { return "SKU is required." }
        if newSku != sku, itemIndex[newSku] != nil { return "SKU \(newSku) already exists." }
        let primary = rows.firstIndex(where: { $0.sku == sku })
        apply([entry("Edit", sku)]) {
            for idx in rows.indices where rows[idx].sku == sku {
                if idx == primary || !rows[idx].name.isEmpty {
                    rows[idx].name = name.trimmed; rows[idx].gender = gender.trimmed
                    rows[idx].category = category.trimmed; rows[idx].family = family.trimmed
                }
                rows[idx].sku = newSku
            }
        }
        return nil
    }

    func deleteItem(sku: String) {
        apply([entry("Delete", sku)]) { rows.removeAll { $0.sku == sku } }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
