import Foundation

enum SearchField: String, CaseIterable, Identifiable {
    case all, name, manufacturer, store, country, price, purchaseDate, serial, coverage, card, category, tags, location, notes, attachments
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: "All fields"
        case .name: "Item name"
        case .manufacturer: "Manufacturer"
        case .store: "Store"
        case .country: "Country"
        case .price: "Price / currency"
        case .purchaseDate: "Purchase date"
        case .serial: "Serial number"
        case .coverage: "Coverage"
        case .card: "Credit card"
        case .category: "Category"
        case .tags: "Tags"
        case .location: "Used in"
        case .notes: "Notes"
        case .attachments: "Attachment names"
        }
    }
}

enum InventorySearch {
    static func matches(_ item: Item, query: String, field: SearchField) -> Bool {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return true }
        return values(item, field: field).contains { $0.localizedStandardContains(text) }
    }

    private static func cardValues(_ card: CardVersion?) -> [String] {
        guard let card else { return [] }
        return [card.account?.nickname ?? "", card.bank, card.network, card.productName, card.firstFour, card.lastFour, card.maskedNumber]
    }

    static func values(_ item: Item, field: SearchField) -> [String] {
        switch field {
        case .all: return SearchField.allCases.filter { $0 != .all }.flatMap { values(item, field: $0) }
        case .name: return [item.name]
        case .manufacturer: return [item.manufacturer]
        case .store: return [item.retailer]
        case .country: return [item.countryCode, Locale.current.localizedString(forRegionCode: item.countryCode) ?? ""]
        case .price: return [item.priceAmount ?? "", item.currencyCode, Money.label(item.priceAmount, currency: item.currencyCode)]
        case .purchaseDate: return [item.purchasedOn ?? "", item.purchasedOn == nil ? "" : CalendarDay.label(item.purchasedOn)]
        case .serial: return [item.serialNumber]
        case .category: return [item.category?.name ?? ""]
        case .tags: return (item.tags ?? []).map(\.name)
        case .location: return [item.location?.name ?? ""]
        case .notes: return [item.notes]
        case .attachments:
            return ((item.attachments ?? []) + (item.coverages ?? []).flatMap { $0.attachments ?? [] }).flatMap {
                [$0.title, AttachmentRole(rawValue: $0.role)?.label ?? $0.role]
            }
        case .card: return cardValues(item.purchaseCard) + (item.coverages ?? []).flatMap { cardValues($0.cardVersion) }
        case .coverage:
            return (item.coverages ?? []).flatMap { coverage -> [String] in
                let dates = [coverage.startsOn, coverage.endsOn, coverage.cancelledOn].compactMap { $0 }
                return [coverage.title, coverage.provider, coverage.terms, coverage.exclusions, coverage.notes,
                        CoverageKind(rawValue: coverage.kind)?.label ?? coverage.kind,
                        CoverageDuration(rawValue: coverage.duration)?.label ?? coverage.duration,
                        CoverageStatus.status(of: coverage).label, coverage.source] + dates + dates.map { CalendarDay.label($0) }
            }
        }
    }
}
