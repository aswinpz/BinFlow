import Foundation
import Compression

// MARK: - Minimal ZIP (read deflate/stored, write stored)

enum XLSXError: LocalizedError {
    case notZip, unsupported(String), missing(String), badSheet
    var errorDescription: String? {
        switch self {
        case .notZip: return "This doesn't look like an .xlsx file."
        case .unsupported(let s): return "Unsupported file contents: \(s)"
        case .missing(let s): return "Missing part in workbook: \(s)"
        case .badSheet: return "Couldn't read the first sheet."
        }
    }
}

struct ZipPart { var name: String; var data: Data }

enum Zip {
    private static func u16(_ d: Data, _ o: Int) -> Int { Int(d[d.startIndex + o]) | Int(d[d.startIndex + o + 1]) << 8 }
    private static func u32(_ d: Data, _ o: Int) -> Int { u16(d, o) | u16(d, o + 2) << 16 }

    static func read(_ data: Data) throws -> [ZipPart] {
        guard data.count > 22 else { throw XLSXError.notZip }
        // find end-of-central-directory record
        var eocd = -1
        var i = data.count - 22
        while i >= max(0, data.count - 66_000) {
            if u32(data, i) == 0x06054b50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw XLSXError.notZip }
        let count = u16(data, eocd + 10)
        var p = u32(data, eocd + 16)
        var parts: [ZipPart] = []
        for _ in 0..<count {
            guard p + 46 <= data.count, u32(data, p) == 0x02014b50 else { throw XLSXError.notZip }
            let method = u16(data, p + 10)
            let csize = u32(data, p + 20)
            let usize = u32(data, p + 24)
            let nlen = u16(data, p + 28), xlen = u16(data, p + 30), clen = u16(data, p + 32)
            let local = u32(data, p + 42)
            let nameData = data.subdata(in: (data.startIndex + p + 46)..<(data.startIndex + p + 46 + nlen))
            let name = String(decoding: nameData, as: UTF8.self)
            p += 46 + nlen + xlen + clen
            if name.hasSuffix("/") { continue }
            guard local + 30 <= data.count else { throw XLSXError.notZip }
            let start = local + 30 + u16(data, local + 26) + u16(data, local + 28)
            let raw = data.subdata(in: (data.startIndex + start)..<(data.startIndex + start + csize))
            switch method {
            case 0: parts.append(ZipPart(name: name, data: raw))
            case 8: parts.append(ZipPart(name: name, data: try inflate(raw, size: usize)))
            default: throw XLSXError.unsupported("compression method \(method)")
            }
        }
        return parts
    }

    private static func inflate(_ raw: Data, size: Int) throws -> Data {
        if size == 0 { return Data() }
        var out = Data(count: size)
        let n = out.withUnsafeMutableBytes { dst in
            raw.withUnsafeBytes { src in
                compression_decode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, size,
                                          src.bindMemory(to: UInt8.self).baseAddress!, raw.count,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        guard n == size else { throw XLSXError.unsupported("could not decompress a part") }
        return out
    }

    // CRC32
    private static let table: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
        return c
    }
    private static func crc32(_ d: Data) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        for b in d { c = table[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFFFFFF
    }

    /// Writes every part uncompressed ("stored"). Larger file, but always valid and very simple.
    static func write(_ parts: [ZipPart]) -> Data {
        var out = Data(), central = Data()
        func w16(_ d: inout Data, _ v: Int) { d.append(UInt8(v & 0xFF)); d.append(UInt8((v >> 8) & 0xFF)) }
        func w32(_ d: inout Data, _ v: UInt32) { for s in stride(from: 0, to: 32, by: 8) { d.append(UInt8((v >> UInt32(s)) & 0xFF)) } }
        let dosTime = 0, dosDate = (46 << 9) | (1 << 5) | 1   // 2026-01-01
        for part in parts {
            let name = Data(part.name.utf8)
            let crc = crc32(part.data)
            let offset = UInt32(out.count)
            w32(&out, 0x04034b50); w16(&out, 20); w16(&out, 0x0800); w16(&out, 0)
            w16(&out, dosTime); w16(&out, dosDate)
            w32(&out, crc); w32(&out, UInt32(part.data.count)); w32(&out, UInt32(part.data.count))
            w16(&out, name.count); w16(&out, 0)
            out.append(name); out.append(part.data)

            w32(&central, 0x02014b50); w16(&central, 20); w16(&central, 20); w16(&central, 0x0800); w16(&central, 0)
            w16(&central, dosTime); w16(&central, dosDate)
            w32(&central, crc); w32(&central, UInt32(part.data.count)); w32(&central, UInt32(part.data.count))
            w16(&central, name.count); w16(&central, 0); w16(&central, 0); w16(&central, 0); w16(&central, 0)
            w32(&central, 0); w32(&central, offset)
            central.append(name)
        }
        let cdOffset = UInt32(out.count)
        out.append(central)
        w32(&out, 0x06054b50); w16(&out, 0); w16(&out, 0)
        w16(&out, parts.count); w16(&out, parts.count)
        w32(&out, UInt32(central.count)); w32(&out, cdOffset); w16(&out, 0)
        return out
    }
}

// MARK: - XML parsing helpers

private final class SSTParser: NSObject, XMLParserDelegate {
    var strings: [String] = []
    private var current = ""
    private var inT = false
    private var phonetic = 0
    func parser(_ p: XMLParser, didStartElement e: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if e == "si" { current = "" }
        if e == "rPh" { phonetic += 1 }
        if e == "t" && phonetic == 0 { inT = true }
    }
    func parser(_ p: XMLParser, foundCharacters s: String) { if inT { current += s } }
    func parser(_ p: XMLParser, didEndElement e: String, namespaceURI: String?, qualifiedName: String?) {
        if e == "t" { inT = false }
        if e == "rPh" { phonetic -= 1 }
        if e == "si" { strings.append(current) }
    }
}

private final class SheetParser: NSObject, XMLParserDelegate {
    let shared: [String]
    var rows: [Int: [Int: String]] = [:]      // row number -> column index (0-based) -> text
    private var rowNum = 0, col = 0
    private var type = "", capturing = false, buf = ""
    init(shared: [String]) { self.shared = shared }

    static func colIndex(_ ref: String) -> Int {
        var n = 0
        for ch in ref.unicodeScalars where ch.value >= 65 && ch.value <= 90 { n = n * 26 + Int(ch.value) - 64 }
        return max(n - 1, 0)
    }
    func parser(_ p: XMLParser, didStartElement e: String, namespaceURI: String?, qualifiedName: String?, attributes a: [String: String]) {
        switch e {
        case "row": rowNum = Int(a["r"] ?? "") ?? (rowNum + 1)
        case "c": col = SheetParser.colIndex(a["r"] ?? ""); type = a["t"] ?? ""; buf = ""
        case "v", "t": capturing = true
        default: break
        }
    }
    func parser(_ p: XMLParser, foundCharacters s: String) { if capturing { buf += s } }
    func parser(_ p: XMLParser, didEndElement e: String, namespaceURI: String?, qualifiedName: String?) {
        switch e {
        case "v", "t": capturing = false
        case "c":
            var text = buf
            if type == "s", let i = Int(buf.trimmingCharacters(in: .whitespaces)), i >= 0, i < shared.count { text = shared[i] }
            if !text.isEmpty { rows[rowNum, default: [:]][col] = text }
        default: break
        }
    }
}

// MARK: - Workbook

/// One data row of Sheet1 (columns A-F).
struct SheetRow: Identifiable, Equatable {
    var id = UUID()
    var gender = "", category = "", family = "", sku = "", name = "", bin = ""
}

/// Holds the original workbook parts so everything we don't touch (styles, Sheet2, theme...) is written back unchanged.
struct Workbook {
    private(set) var parts: [ZipPart]
    private let sheetName: String
    var rows: [SheetRow]

    static func load(_ data: Data) throws -> Workbook {
        let parts = try Zip.read(data)
        guard let sheetPart = parts.first(where: { $0.name == "xl/worksheets/sheet1.xml" })
                ?? parts.filter({ $0.name.hasPrefix("xl/worksheets/sheet") && $0.name.hasSuffix(".xml") })
                         .sorted(by: { $0.name < $1.name }).first
        else { throw XLSXError.missing("worksheet") }

        var shared: [String] = []
        if let sst = parts.first(where: { $0.name == "xl/sharedStrings.xml" }) {
            let sp = SSTParser(); let x = XMLParser(data: sst.data); x.delegate = sp
            guard x.parse() else { throw XLSXError.unsupported("shared strings") }
            shared = sp.strings
        }
        let parser = SheetParser(shared: shared)
        let x = XMLParser(data: sheetPart.data); x.delegate = parser
        guard x.parse() else { throw XLSXError.badSheet }

        var rows: [SheetRow] = []
        for n in parser.rows.keys.sorted() where n > 1 {          // row 1 = header
            let c = parser.rows[n] ?? [:]
            func t(_ i: Int) -> String { (c[i] ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
            let r = SheetRow(gender: t(0), category: t(1), family: t(2), sku: t(3), name: t(4), bin: t(5))
            if r.sku.isEmpty && r.name.isEmpty && r.bin.isEmpty { continue }
            rows.append(r)
        }
        return Workbook(parts: parts, sheetName: sheetPart.name, rows: rows)
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Rebuilds sheet data from `rows` and returns the full .xlsx file.
    func serialize() throws -> Data {
        guard let idx = parts.firstIndex(where: { $0.name == sheetName }),
              var xml = String(data: parts[idx].data, encoding: .utf8),
              let open = xml.range(of: "<sheetData>"),
              let close = xml.range(of: "</sheetData>"),
              let h0 = xml.range(of: "<row r=\"1\""),
              let h1 = xml.range(of: "</row>", range: h0.upperBound..<xml.endIndex)
        else { throw XLSXError.badSheet }

        let header = String(xml[h0.lowerBound..<h1.upperBound])
        var body = header
        body.reserveCapacity(rows.count * 260)
        for (i, r) in rows.enumerated() {
            let n = i + 2
            var cells = ""
            func cell(_ col: String, _ text: String, _ style: Int) {
                guard !text.isEmpty else { return }
                cells += "<c r=\"\(col)\(n)\" s=\"\(style)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(Workbook.esc(text))</t></is></c>"
            }
            cell("A", r.gender, 1); cell("B", r.category, 1); cell("C", r.family, 1)
            cell("D", r.sku, 1); cell("E", r.name, 4); cell("F", r.bin, 1)
            body += "<row r=\"\(n)\" ht=\"\(r.name.isEmpty ? "20.05" : "27.95")\" customHeight=\"1\">\(cells)</row>"
        }
        xml.replaceSubrange(open.upperBound..<close.lowerBound, with: body)

        let last = rows.count + 1
        xml = xml.replacingOccurrences(of: "<dimension ref=\"[^\"]*\"/>", with: "<dimension ref=\"A1:F\(last)\"/>", options: .regularExpression)
        xml = xml.replacingOccurrences(of: "<autoFilter ref=\"[^\"]*\"", with: "<autoFilter ref=\"A1:F\(last)\"", options: .regularExpression)

        var out = parts
        out[idx].data = Data(xml.utf8)
        if let w = out.firstIndex(where: { $0.name == "xl/workbook.xml" }),
           let s = String(data: out[w].data, encoding: .utf8) {
            let fixed = s.replacingOccurrences(of: "\\$A\\$1:\\$F\\$[0-9]+", with: "\\$A\\$1:\\$F\\$\(last)", options: .regularExpression)
            out[w].data = Data(fixed.utf8)
        }
        return Zip.write(out)
    }
}
