//
//  Expense.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation

struct Expense: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var price: Double
    var date: Date
    var category: Category
    var type: TransactionType
    var categoryID: String
    var notes: String?
    /// Wallet the money moved in or out of. nil only for data not yet migrated.
    var walletID: UUID?
    /// For a refund: the purchase it pays back. Its spending then counts against that purchase's date.
    var refundOfID: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        price: Double,
        date: Date,
        category: Category,
        type: TransactionType = .expense,
        categoryID: String? = nil,
        notes: String? = nil,
        walletID: UUID? = nil,
        refundOfID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.price = price
        self.date = date
        self.category = category
        self.type = type
        self.categoryID = categoryID ?? category.categoryID
        self.notes = notes
        self.walletID = walletID
        self.refundOfID = refundOfID
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case price
        case date
        case category
        case type
        case categoryID
        case notes
        case walletID
        case refundOfID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        price = try container.decode(Double.self, forKey: .price)
        date = try container.decode(Date.self, forKey: .date)
        category = try container.decodeIfPresent(Category.self, forKey: .category) ?? .others
        type = try container.decodeIfPresent(TransactionType.self, forKey: .type) ?? .expense
        categoryID = try container.decodeIfPresent(String.self, forKey: .categoryID) ?? category.categoryID
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        walletID = try container.decodeIfPresent(UUID.self, forKey: .walletID)
        refundOfID = try container.decodeIfPresent(UUID.self, forKey: .refundOfID)
    }

    /// Effect on the wallet: inflows (income, refunds) are positive.
    var signedAmount: Double { type.isInflow ? price : -price }
}

/// One entry's effect on spending: expenses add, refunds subtract. Income is not spending.
struct SpendingEntry {
    let categoryID: String
    let amount: Double
    /// The day the spending counts on. For a linked refund, the purchase's date.
    let date: Date
}

extension Array where Element == Expense {
    /// Money in minus money out, each on its own date. Cash flow, unlike spending, ignores refund links.
    var netCashflow: Double { reduce(0) { $0 + $1.signedAmount } }
}

extension Array where Element == Expense {
    /// Spending effects of every expense and refund. A refund linked to a purchase in this array
    /// counts on the purchase's date and in its current category, so a refund that arrives days later
    /// lowers the right month, and follows the purchase if it is recategorized.
    var spendingEntries: [SpendingEntry] {
        let purchases = Dictionary(
            filter { $0.type == .expense }.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return compactMap { transaction in
            switch transaction.type {
            case .expense:
                return SpendingEntry(categoryID: transaction.categoryID, amount: transaction.price, date: transaction.date)
            case .refund:
                let purchase = transaction.refundOfID.flatMap { purchases[$0] }
                return SpendingEntry(
                    categoryID: purchase?.categoryID ?? transaction.categoryID,
                    amount: -transaction.price,
                    date: purchase?.date ?? transaction.date
                )
            case .income:
                return nil
            }
        }
    }
}
