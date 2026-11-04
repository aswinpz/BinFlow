import SwiftData
import Foundation

@Model final class Bin {
    @Attribute(.unique) var code: String
    var zone: String
    var capacity: Int
    @Relationship(deleteRule: .cascade, inverse: \StockLine.bin) var lines: [StockLine] = []

    init(code: String, zone: String, capacity: Int) {
        self.code = code; self.zone = zone; self.capacity = capacity
    }
    var used: Int { lines.reduce(0) { $0 + $1.qty } }
    var free: Int { max(capacity - used, 0) }
    var fill: Double { capacity == 0 ? 0 : min(Double(used) / Double(capacity), 1) }
}

@Model final class Item {
    @Attribute(.unique) var sku: String
    var name: String
    var barcode: String
    @Relationship(deleteRule: .cascade, inverse: \StockLine.item) var lines: [StockLine] = []

    init(sku: String, name: String, barcode: String = "") {
        self.sku = sku; self.name = name; self.barcode = barcode
    }
    var total: Int { lines.reduce(0) { $0 + $1.qty } }
}

@Model final class StockLine {
    var item: Item?
    var bin: Bin?
    var qty: Int
    var updated: Date
    init(qty: Int) { self.qty = qty; self.updated = .now }
}

@Model final class Movement {
    var date: Date
    var kind: String   // "In" or "Out"
    var sku: String
    var name: String
    var binCode: String
    var qty: Int
    init(kind: String, sku: String, name: String, binCode: String, qty: Int) {
        self.date = .now; self.kind = kind; self.sku = sku
        self.name = name; self.binCode = binCode; self.qty = qty
    }
}
