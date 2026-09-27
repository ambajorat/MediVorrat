import Foundation

/// Ergebnis eines Packungs-Scans.
/// Deutsche Rx-Packungen tragen den securPharm-DataMatrix (IFA- oder GS1-Format)
/// und meist zusätzlich den PZN-Strichcode (Code 39).
struct PackCode: Equatable {
    /// Schlüssel für den Packungskatalog: PZN, sonst GTIN, sonst Rohcode
    var key: String
    var pzn: String?
    /// Seriennummer der einzelnen Packung (nur DataMatrix)
    var serial: String?
    var raw: String

    /// Eindeutig für genau diese Packung – verhindert doppeltes Einbuchen
    var packID: String? { serial.map { "\(key)|\($0)" } }

    var label: String {
        if let pzn { return "PZN \(pzn)" }
        return "Code \(raw.prefix(18))"
    }

    private static let GS: Character = "\u{1D}"
    private static let RS: Character = "\u{1E}"
    private static let EOT: Character = "\u{04}"

    static func parse(_ input: String) -> PackCode {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // Symbologie-Kennung wie "]d2" entfernen
        if s.hasPrefix("]"), s.count > 3 { s = String(s.dropFirst(3)) }

        // 1) PZN-Strichcode: "-12345678", "PZN-12345678" oder alte PZN7
        var t = s.uppercased().replacingOccurrences(of: "PZN", with: "")
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: "-: "))
        if (t.count == 7 || t.count == 8), t.allSatisfy(\.isNumber) {
            let pzn = t.count == 7 ? "0" + t : t
            return PackCode(key: pzn, pzn: pzn, serial: nil, raw: input)
        }

        // 2) IFA-Format (securPharm): Datenbezeichner 9N (PPN), S (Seriennr.), 1T, D
        if s.contains("[)>") || s.contains("9N") {
            let parts = s.split(whereSeparator: { $0 == GS || $0 == RS || $0 == EOT }).map(String.init)
            var pzn: String?
            var serial: String?
            for p in parts {
                if p.hasPrefix("9N") {
                    let d = Array(p.dropFirst(2).filter(\.isNumber))
                    if d.count >= 10, d[0] == "1", d[1] == "1" { pzn = String(d[2..<10]) }
                } else if p.hasPrefix("S"), p.count > 1 {
                    serial = String(p.dropFirst())
                }
            }
            if let pzn { return PackCode(key: pzn, pzn: pzn, serial: serial, raw: input) }
        }

        // 3) GS1-Format: AI 01 (GTIN/NTIN), 17 (Verfall), 10 (Charge), 21 (Seriennr.), 710 (PZN)
        var rest = Substring(s).drop(while: { $0 == GS })
        if rest.hasPrefix("01") || rest.hasPrefix("21") || rest.hasPrefix("710") {
            var gtin: String?
            var serial: String?
            var pzn: String?

            func variable(_ aiLength: Int) -> String {
                rest = rest.dropFirst(aiLength)
                let v = rest.prefix(while: { $0 != GS })
                rest = rest.dropFirst(v.count)
                return String(v)
            }

            while !rest.isEmpty {
                if rest.first == GS { rest = rest.dropFirst(); continue }
                if rest.hasPrefix("01") {
                    gtin = String(rest.dropFirst(2).prefix(14)); rest = rest.dropFirst(16)
                } else if rest.hasPrefix("17") {
                    rest = rest.dropFirst(8)
                } else if rest.hasPrefix("710") {
                    pzn = String(variable(3).prefix(8))
                } else if rest.hasPrefix("21") {
                    serial = variable(2)
                } else if rest.hasPrefix("10") {
                    _ = variable(2)
                } else {
                    break
                }
            }
            // Deutsche NTIN: 04150 + PZN8 + Prüfziffer
            if pzn == nil, let g = gtin, g.count == 14, g.hasPrefix("04150") {
                pzn = String(Array(g)[5..<13])
            }
            if let key = pzn ?? gtin {
                return PackCode(key: key, pzn: pzn, serial: serial, raw: input)
            }
        }

        // 4) Unbekanntes Format: Rohcode als Schlüssel
        return PackCode(key: s, pzn: nil, serial: nil, raw: input)
    }

    /// Stückzahl aus erkanntem Packungstext, z. B. „100 Filmtabletten“, „98 St.“
    static func packSize(in texts: [String]) -> Int? {
        let pattern = #"(\d{1,3})\s*(Filmtabletten|Retardtabletten|Tabletten|Hartkapseln|Kapseln|Dragees|Stück|Stk\.?|St\.|Tbl\.)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        for text in texts {
            let range = NSRange(text.startIndex..., in: text)
            if let m = regex.firstMatch(in: text, range: range),
               let r = Range(m.range(at: 1), in: text),
               let n = Int(text[r]), n > 0 {
                return n
            }
        }
        return nil
    }
}

struct PackEntry: Codable, Equatable {
    var medicationID: UUID
    var packSize: Int
}
