import Foundation

enum CoverageKind: String, CaseIterable, Identifiable {
    case manufacturer, retailer, creditCard, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .manufacturer: "Manufacturer warranty"
        case .retailer: "Retailer warranty"
        case .creditCard: "Credit-card warranty"
        case .other: "Other warranty"
        }
    }
}

enum CoverageDuration: String, CaseIterable, Identifiable {
    case fixed, ongoing, unknown
    var id: String { rawValue }
    var label: String {
        switch self {
        case .fixed: "Fixed end date"
        case .ongoing: "Ongoing / monthly"
        case .unknown: "End date unknown"
        }
    }
}

enum FormError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { text } else { nil } }
}

extension CoverageStatus {
    static func status(of coverage: Coverage, today: String = CalendarDay.encode(Date())) -> CoverageStatus {
        if let end = coverage.effectiveEnd, end < today {
            return coverage.cancelledOn == end ? .cancelled : .expired
        }
        if let start = coverage.startsOn, start > today { return .upcoming }
        if coverage.cancelledOn != nil { return .ending }
        if coverage.duration == "ongoing" { return .ongoing }
        return manufacturer(end: coverage.endsOn, today: today)
    }
}

struct CoverageDraft {
    var name = ""
    var provider = ""
    var kind: CoverageKind = .manufacturer
    var duration: CoverageDuration = .unknown
    var hasStart = false
    var start = Date()
    var end = Date()
    var isCancelled = false
    var cancellationEnd = Date()
    var terms = ""
    var exclusions = ""
    var notes = ""
    var cardVersion: CardVersion?

    init(coverage: Coverage? = nil, item: Item? = nil) {
        provider = item?.manufacturer ?? ""
        if let day = item?.purchasedOn, let date = CalendarDay.decode(day) { start = date }
        cardVersion = item?.purchaseCard
        guard let coverage else { return }
        name = coverage.name
        provider = coverage.provider
        kind = CoverageKind(rawValue: coverage.kind) ?? .other
        duration = CoverageDuration(rawValue: coverage.duration) ?? .unknown
        terms = coverage.terms
        exclusions = coverage.exclusions
        notes = coverage.notes
        cardVersion = coverage.cardVersion
        if let day = coverage.startsOn, let date = CalendarDay.decode(day) { hasStart = true; start = date }
        if let day = coverage.endsOn, let date = CalendarDay.decode(day) { end = date }
        if let day = coverage.cancelledOn, let date = CalendarDay.decode(day) { isCancelled = true; cancellationEnd = date }
    }

    func validate() throws {
        if hasStart && duration == .fixed && CalendarDay.encode(end) < CalendarDay.encode(start) {
            throw FormError.message("The end date cannot be before the coverage start date.")
        }
        if isCancelled {
            if hasStart && CalendarDay.encode(cancellationEnd) < CalendarDay.encode(start) {
                throw FormError.message("The final covered day cannot be before the coverage start date.")
            }
            if duration == .fixed && CalendarDay.encode(cancellationEnd) > CalendarDay.encode(end) {
                throw FormError.message("Cancellation cannot extend a fixed warranty beyond its original end date.")
            }
        }
    }

    func apply(to coverage: Coverage) throws {
        try validate()
        coverage.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        coverage.provider = provider.trimmingCharacters(in: .whitespacesAndNewlines)
        coverage.kind = kind.rawValue
        coverage.duration = duration.rawValue
        coverage.startsOn = hasStart ? CalendarDay.encode(start) : nil
        coverage.endsOn = duration == .fixed ? CalendarDay.encode(end) : nil
        coverage.cancelledOn = isCancelled ? CalendarDay.encode(cancellationEnd) : nil
        coverage.terms = terms
        coverage.exclusions = exclusions
        coverage.notes = notes
        coverage.cardVersion = kind == .creditCard ? cardVersion : nil
    }
}

struct CardDraft {
    var nickname = ""
    var bank = ""
    var network = "Visa"
    var productName = ""
    var firstFour = ""
    var lastFour = ""

    init(account: CardAccount? = nil) {
        guard let account else { return }
        nickname = account.nickname
        if let version = account.currentVersion {
            bank = version.bank; network = version.network; productName = version.productName
            firstFour = version.firstFour; lastFour = version.lastFour
        }
    }

    func validate() throws {
        for value in [nickname, bank, network, productName] {
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw FormError.message("Enter a nickname, issuing bank, card network, and card product name.")
            }
            // Card identity text must not become a workaround for entering a full number.
            let digits = value.filter(\.isNumber)
            guard digits.count < 12 else { throw FormError.message("Do not enter full card numbers in card details.") }
        }
        for digits in [firstFour, lastFour] {
            guard digits.utf8.count == 4, digits.utf8.allSatisfy({ (48...57).contains($0) }) else {
                throw FormError.message("Enter exactly four digits in each card-number field. Never enter a full card number or security code.")
            }
        }
    }

    /// Card identity fields are immutable after creation. A changed identity creates a version.
    @discardableResult
    func apply(to account: CardAccount) throws -> CardVersion {
        try validate()
        account.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let bank = bank.trimmingCharacters(in: .whitespacesAndNewlines)
        let network = network.trimmingCharacters(in: .whitespacesAndNewlines)
        let product = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let current = account.currentVersion, current.bank == bank, current.network == network,
           current.productName == product, current.firstFour == firstFour, current.lastFour == lastFour {
            return current
        }
        let version = CardVersion()
        version.bank = bank; version.network = network; version.productName = product
        version.firstFour = firstFour; version.lastFour = lastFour
        // Keep ordering deterministic even if two edits occur in the same clock tick.
        version.createdAt = max(Date(), (account.currentVersion?.createdAt ?? .distantPast).addingTimeInterval(0.001))
        account.versions = (account.versions ?? []) + [version]
        version.account = account
        return version
    }
}
