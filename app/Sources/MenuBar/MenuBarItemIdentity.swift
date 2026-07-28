import Foundation

enum MenuBarItemIdentity {
    static func disambiguatedStableIdentifiers(
        rawIdentifiers: [String?],
        titles: [String?]
    ) -> [String] {
        precondition(rawIdentifiers.count == titles.count)

        let candidates = zip(rawIdentifiers, titles).map { rawIdentifier, title in
            firstNonempty(rawIdentifier, title)
        }
        let totals = candidates.reduce(into: [String: Int]()) { result, candidate in
            guard let candidate else { return }
            result[normalized(candidate), default: 0] += 1
        }
        var occurrences = [String: Int]()
        var unnamedOccurrence = 0

        return candidates.map { candidate in
            guard let candidate else {
                unnamedOccurrence += 1
                return "barr-unnamed-item-\(unnamedOccurrence)"
            }

            let key = normalized(candidate)
            guard totals[key, default: 0] > 1 else { return candidate }
            occurrences[key, default: 0] += 1
            return "\(candidate)#\(occurrences[key, default: 0])"
        }
    }

    private static func firstNonempty(_ values: String?...) -> String? {
        values.first {
            guard let value = $0 else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? nil
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
