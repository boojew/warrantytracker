import Foundation

/// A Gregorian calendar day stored without a time zone or time of day.
enum CalendarDay {
    static func encode(_ date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    static func decode(_ value: String, timeZone: TimeZone = .current) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)),
              encode(date, timeZone: timeZone) == value else { return nil }
        return date
    }

    static func label(_ value: String?) -> String {
        guard let value, let date = decode(value) else { return "Not entered" }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

enum EntryError: LocalizedError {
    case missingName, invalidPrice, warrantyBeforePurchase

    var errorDescription: String? {
        switch self {
        case .missingName: "Enter an item name."
        case .invalidPrice: "Enter a price of zero or more using digits and a decimal separator, without currency symbols or thousands separators."
        case .warrantyBeforePurchase: "The manufacturer warranty end date cannot be before the purchase date."
        }
    }
}

enum Money {
    static func parse(_ input: String, locale: Locale = .current) throws -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let separator = locale.decimalSeparator ?? "."
        let normalized = trimmed.replacingOccurrences(of: separator, with: ".")
        guard normalized.range(of: #"^[0-9]{1,12}(\.[0-9]{1,4})?$"#, options: .regularExpression) != nil,
              let amount = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            throw EntryError.invalidPrice
        }
        return NSDecimalNumber(decimal: amount).stringValue
    }

    static func editable(_ amount: String?) -> String {
        (amount ?? "").replacingOccurrences(of: ".", with: Locale.current.decimalSeparator ?? ".")
    }

    static func label(_ amount: String?, currency: String) -> String {
        guard let amount, let value = Decimal(string: amount, locale: Locale(identifier: "en_US_POSIX")) else {
            return "Not entered"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        // Preserve all entered decimal places instead of silently rounding a price.
        formatter.maximumFractionDigits = max(formatter.maximumFractionDigits, amount.split(separator: ".").dropFirst().first?.count ?? 0)
        return "\(formatter.string(from: NSDecimalNumber(decimal: value)) ?? amount) \(currency)"
    }
}

enum CoverageStatus {
    case unknown, recorded, expired, ongoing, cancelled, upcoming, ending

    static func manufacturer(end: String?, today: String = CalendarDay.encode(Date())) -> Self {
        guard let end else { return .unknown }
        return end < today ? .expired : .recorded
    }

    var label: String {
        switch self {
        case .unknown: "End date unknown"
        case .recorded: "Warranty recorded"
        case .expired: "Warranty expired"
        case .ongoing: "Ongoing — user recorded"
        case .cancelled: "Cancelled"
        case .upcoming: "Starts in the future"
        case .ending: "Cancellation scheduled"
        }
    }
}

struct ItemDraft {
    var name = ""
    var manufacturer = ""
    var retailer = ""
    var countryCode = "CA"
    var currencyCode = "CAD"
    var price = ""
    var hasPurchaseDate = false
    var purchaseDate = Date()
    var serialNumber = ""
    var notes = ""
    var hasWarrantyEnd = false
    var warrantyEnd = Date()
    var purchaseCard: CardVersion?
    var category: Classification?
    var location: Classification?
    var tags: [Classification] = []
    private(set) var createsInitialCoverage = true

    init(item: Item? = nil, defaults: Preferences? = nil) {
        countryCode = defaults?.countryCode ?? "CA"
        currencyCode = defaults?.currencyCode ?? "CAD"
        guard let item else { return }
        createsInitialCoverage = false
        name = item.name
        manufacturer = item.manufacturer
        retailer = item.retailer
        countryCode = item.countryCode
        currencyCode = item.currencyCode
        price = Money.editable(item.priceAmount)
        serialNumber = item.serialNumber
        notes = item.notes
        purchaseCard = item.purchaseCard
        category = item.category
        location = item.location
        tags = item.tags ?? []
        if let day = item.purchasedOn, let date = CalendarDay.decode(day) {
            hasPurchaseDate = true
            purchaseDate = date
        }
        if let day = item.manufacturerCoverage?.endsOn, let date = CalendarDay.decode(day) {
            hasWarrantyEnd = true
            warrantyEnd = date
        }
    }

    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw EntryError.missingName }
        _ = try Money.parse(price)
        if createsInitialCoverage && hasPurchaseDate && hasWarrantyEnd && CalendarDay.encode(warrantyEnd) < CalendarDay.encode(purchaseDate) {
            throw EntryError.warrantyBeforePurchase
        }
    }

    func apply(to item: Item) throws {
        try validate()
        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.manufacturer = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        item.retailer = retailer.trimmingCharacters(in: .whitespacesAndNewlines)
        item.countryCode = countryCode
        item.currencyCode = currencyCode
        item.priceAmount = try Money.parse(price)
        item.purchasedOn = hasPurchaseDate ? CalendarDay.encode(purchaseDate) : nil
        item.serialNumber = serialNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        item.notes = notes
        item.purchaseCard = purchaseCard
        item.category = category
        item.location = location
        item.tags = tags
        item.updatedAt = Date()
        // Editing purchase details must never silently rewrite confirmed warranty records.
        guard createsInitialCoverage && (item.coverages ?? []).isEmpty else { return }
        let coverage = Coverage()
        item.coverages = [coverage]
        coverage.item = item
        coverage.provider = item.manufacturer
        coverage.startsOn = item.purchasedOn
        coverage.endsOn = hasWarrantyEnd ? CalendarDay.encode(warrantyEnd) : nil
        coverage.duration = hasWarrantyEnd ? "fixed" : "unknown"
    }
}
