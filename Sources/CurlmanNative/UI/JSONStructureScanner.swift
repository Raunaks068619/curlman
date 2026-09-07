import Foundation

enum JSONFoldKind: String, Sendable {
    case object
    case array

    var itemLabel: String {
        switch self {
        case .object: "keys"
        case .array: "items"
        }
    }
}

struct JSONFoldRegion: Hashable, Identifiable, Sendable {
    let openingOffset: Int
    let closingOffset: Int
    let openingLine: Int
    let kind: JSONFoldKind
    let itemCount: Int

    var id: Int { openingOffset }

    var hiddenRange: NSRange {
        NSRange(location: openingOffset + 1, length: max(closingOffset - openingOffset - 1, 0))
    }

    var collapsedRange: NSRange {
        NSRange(location: openingOffset + 1, length: max(closingOffset - openingOffset, 0))
    }

    var summary: String {
        "… \(itemCount) \(kind.itemLabel)"
    }

    var collapsedSummary: String {
        "\(summary) \(kind == .object ? "}" : "]")"
    }
}

struct JSONStructureScanner {
    func regions(in source: String) -> [JSONFoldRegion] {
        guard let data = source.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil else {
            return []
        }

        let string = source as NSString
        var stack: [(delimiter: unichar, offset: Int, line: Int)] = []
        var regions: [JSONFoldRegion] = []
        var isInsideString = false
        var isEscaped = false
        var line = 1

        for offset in 0..<string.length {
            let character = string.character(at: offset)

            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if character == 0x5C {
                    isEscaped = true
                } else if character == 0x22 {
                    isInsideString = false
                }
            } else {
                switch character {
                case 0x22:
                    isInsideString = true
                case 0x7B, 0x5B:
                    stack.append((character, offset, line))
                case 0x7D, 0x5D:
                    guard let opening = stack.last,
                          delimitersMatch(opening.delimiter, character) else { return [] }
                    stack.removeLast()
                    guard line > opening.line else { break }
                    let kind: JSONFoldKind = opening.delimiter == 0x7B ? .object : .array
                    let range = NSRange(location: opening.offset, length: offset - opening.offset + 1)
                    regions.append(
                        JSONFoldRegion(
                            openingOffset: opening.offset,
                            closingOffset: offset,
                            openingLine: opening.line,
                            kind: kind,
                            itemCount: itemCount(in: string.substring(with: range), kind: kind)
                        )
                    )
                case 0x0A:
                    line += 1
                default:
                    break
                }
            }
        }

        guard stack.isEmpty, !isInsideString else { return [] }
        return regions.sorted { $0.openingOffset < $1.openingOffset }
    }

    private func delimitersMatch(_ opening: unichar, _ closing: unichar) -> Bool {
        (opening == 0x7B && closing == 0x7D) || (opening == 0x5B && closing == 0x5D)
    }

    private func itemCount(in source: String, kind: JSONFoldKind) -> Int {
        guard let data = source.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return 0
        }
        switch kind {
        case .object:
            return (value as? [String: Any])?.count ?? 0
        case .array:
            return (value as? [Any])?.count ?? 0
        }
    }
}
