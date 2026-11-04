import SwiftData
import Foundation

/// Allocation strategy:
/// 1. Consolidate into bins already holding the SKU (fullest first).
/// 2. Otherwise best-fit: smallest bin that fits the remainder, preferring the chosen zone.
/// 3. If nothing fits whole, fill the largest free bins and overflow onward.
enum Allocator {
    struct Pick: Identifiable { let id = UUID(); let bin: Bin; let qty: Int; let note: String }
    struct Plan { var picks: [Pick]; var unplaced: Int }

    static func plan(item: Item, qty: Int, bins: [Bin], zone: String?) -> Plan {
        var left = qty
        var picks: [Pick] = []
        var used = Set<String>()
        func inZone(_ b: Bin) -> Bool { zone == nil || b.zone == zone }

        let holding = bins
            .filter { b in b.free > 0 && b.lines.contains { $0.item?.sku == item.sku } }
            .sorted { $0.free < $1.free }
        for b in holding where left > 0 {
            let n = min(b.free, left)
            picks.append(Pick(bin: b, qty: n, note: "Already holds this SKU"))
            left -= n; used.insert(b.code)
        }

        while left > 0 {
            let pool = bins.filter { !used.contains($0.code) && $0.free > 0 }
            let ranked = pool.sorted { a, b in
                if inZone(a) != inZone(b) { return inZone(a) }
                let fa = a.free >= left, fb = b.free >= left
                if fa != fb { return fa }
                return fa ? a.free < b.free : a.free > b.free
            }
            guard let b = ranked.first else { break }
            let n = min(b.free, left)
            let note = !inZone(b) ? "Outside preferred zone" : (b.free >= left ? "Best fit" : "Fills bin, overflow continues")
            picks.append(Pick(bin: b, qty: n, note: note))
            left -= n; used.insert(b.code)
        }
        return Plan(picks: picks, unplaced: left)
    }

    static func commit(_ plan: Plan, item: Item, ctx: ModelContext) {
        for p in plan.picks { add(item: item, bin: p.bin, qty: p.qty, ctx: ctx) }
        try? ctx.save()
    }

    static func add(item: Item, bin: Bin, qty: Int, ctx: ModelContext) {
        if let line = bin.lines.first(where: { $0.item?.sku == item.sku }) {
            line.qty += qty; line.updated = .now
        } else {
            let l = StockLine(qty: qty)
            ctx.insert(l); l.item = item; l.bin = bin
        }
        ctx.insert(Movement(kind: "In", sku: item.sku, name: item.name, binCode: bin.code, qty: qty))
    }

    static func pick(line: StockLine, qty: Int, ctx: ModelContext) {
        guard let item = line.item, let bin = line.bin else { return }
        let n = min(qty, line.qty)
        ctx.insert(Movement(kind: "Out", sku: item.sku, name: item.name, binCode: bin.code, qty: n))
        line.qty -= n; line.updated = .now
        if line.qty == 0 { ctx.delete(line) }
        try? ctx.save()
    }

    static func seed(_ ctx: ModelContext) {
        var bins: [Bin] = []
        for z in ["A", "B", "C"] {
            for i in 1...6 {
                let b = Bin(code: "\(z)-\(String(format: "%02d", i))", zone: z, capacity: z == "C" ? 200 : 100)
                ctx.insert(b); bins.append(b)
            }
        }
        let seeds: [(String, String, String, Int)] = [
            ("SKU-1001", "Running Shoe Pro", "6290001000011", 140),
            ("SKU-1002", "Training Tee, Black", "6290001000028", 90),
            ("SKU-1003", "Sport Socks 3-pack", "6290001000035", 260),
            ("SKU-1004", "Gym Bag 40L", "6290001000042", 45)
        ]
        for s in seeds {
            let it = Item(sku: s.0, name: s.1, barcode: s.2)
            ctx.insert(it)
            commit(plan(item: it, qty: s.3, bins: bins, zone: nil), item: it, ctx: ctx)
        }
        try? ctx.save()
    }
}
