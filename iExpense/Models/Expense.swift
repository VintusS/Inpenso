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

    init(
        id: UUID = UUID(),
        title: String,
        price: Double,
        date: Date,
        category: Category,
        type: TransactionType = .expense,
        categoryID: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.price = price
        self.date = date
        self.category = category
        self.type = type
        self.categoryID = categoryID ?? category.categoryID
        self.notes = notes
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
    }
}
