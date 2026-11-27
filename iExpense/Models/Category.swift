//
//  Category.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation
import AppIntents
import SwiftUI

enum TransactionType: String, CaseIterable, Codable, Identifiable {
    case expense
    case income
    /// Money back for a purchase (refund or cashback). Adds to the wallet, and lowers spending
    /// in its expense category instead of counting as income.
    case refund

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .expense:
            return "Expense"
        case .income:
            return "Income"
        case .refund:
            return "Refund"
        }
    }

    var amountColor: Color {
        switch self {
        case .expense:
            return .primary
        case .income, .refund:
            return .green
        }
    }

    /// True when the money comes into the wallet.
    var isInflow: Bool { self != .expense }

    /// Refunds use expense categories: they reduce spending in that category.
    var categoryKind: CategoryKind { self == .income ? .income : .expense }

    var titlePlaceholder: String {
        switch self {
        case .expense:
            return "Expense title"
        case .income:
            return "Income title"
        case .refund:
            return "e.g. Store refund or cashback"
        }
    }

    /// Types a recurring rule can produce.
    static let recurringCases: [TransactionType] = [.expense, .income]
}

enum CategoryKind: String, Codable, CaseIterable, Identifiable {
    case expense
    case income

    var id: String { rawValue }

    var displayName: String { self == .income ? "Income" : "Expense" }
}

enum Category: String, CaseIterable, Codable, AppEnum {
    case food
    case eatingOut
    case rent
    case shopping
    case entertainment
    case transportation
    case utilities
    case subscriptions
    case healthcare
    case education
    case work
    case others
    case salary
    case interest
    case investmentReturns
    case giftsRepayments
    case otherIncome
    case feesInterest

    var kind: CategoryKind {
        switch self {
        case .salary, .interest, .investmentReturns, .giftsRepayments, .otherIncome:
            return .income
        default:
            return .expense
        }
    }

    var displayName: String {
        switch self {
        case .food:
            return "Food"
        case .eatingOut:
            return "Eating Out"
        case .rent:
            return "Rent"
        case .shopping:
            return "Shopping"
        case .entertainment:
            return "Entertainment"
        case .transportation:
            return "Transportation"
        case .utilities:
            return "Utilities"
        case .subscriptions:
            return "Subscriptions"
        case .healthcare:
            return "Healthcare"
        case .education:
            return "Education"
        case .work:
            return "Work"
        case .others:
            return "Others"
        case .feesInterest:
            return "Fees & Interest"
        case .salary:
            return "Salary"
        case .interest:
            return "Interest"
        case .investmentReturns:
            return "Investment Returns"
        case .giftsRepayments:
            return "Gifts & Repayments"
        case .otherIncome:
            return "Other Income"
        }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"

    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .food: "Food",
        .eatingOut: "Eating Out",
        .rent: "Rent",
        .shopping: "Shopping",
        .entertainment: "Entertainment",
        .transportation: "Transportation",
        .utilities: "Utilities",
        .subscriptions: "Subscriptions",
        .healthcare: "Healthcare",
        .education: "Education",
        .work: "Work",
        .others: "Others",
        .feesInterest: "Fees & Interest",
        .salary: "Salary",
        .interest: "Interest",
        .investmentReturns: "Investment Returns",
        .giftsRepayments: "Gifts & Repayments",
        .otherIncome: "Other Income",
    ]
}

extension Category {
    var categoryID: String {
        "builtin-\(rawValue)"
    }

    /// Moves an entry out of a built-in category of the wrong kind: income saved before income
    /// categories existed (Work becomes Salary, the rest Other Income), or a refund in an income category.
    /// Custom categories are left alone.
    static func normalizedCategoryID(_ id: String, for type: TransactionType) -> String {
        guard let category = category(from: id), category.kind != type.categoryKind else { return id }
        switch type.categoryKind {
        case .income:
            return (category == .work ? Category.salary : .otherIncome).categoryID
        case .expense:
            return Category.others.categoryID
        }
    }

    static func category(from id: String) -> Category? {
        guard id.hasPrefix("builtin-") else { return nil }
        return Category(rawValue: String(id.dropFirst("builtin-".count)))
    }

    var defaultIconName: String {
        switch self {
        case .food:
            return "cart.fill"
        case .eatingOut:
            return "fork.knife"
        case .rent:
            return "house.fill"
        case .shopping:
            return "bag.fill"
        case .entertainment:
            return "tv.fill"
        case .transportation:
            return "car.fill"
        case .utilities:
            return "bolt.fill"
        case .subscriptions:
            return "repeat"
        case .healthcare:
            return "heart.fill"
        case .education:
            return "book.fill"
        case .work:
            return "briefcase.fill"
        case .others:
            return "ellipsis"
        case .salary:
            return "banknote.fill"
        case .interest, .feesInterest:
            return "percent"
        case .investmentReturns:
            return "chart.line.uptrend.xyaxis"
        case .giftsRepayments:
            return "gift.fill"
        case .otherIncome:
            return "plus.circle.fill"
        }
    }

    var defaultColorHex: String {
        switch self {
        case .food:
            return "#34C759"
        case .eatingOut:
            return "#00C7BE"
        case .rent:
            return "#AF52DE"
        case .shopping:
            return "#FF9500"
        case .entertainment:
            return "#FF2D55"
        case .transportation:
            return "#007AFF"
        case .utilities:
            return "#FFCC00"
        case .subscriptions:
            return "#30B0C7"
        case .healthcare:
            return "#FF3B30"
        case .education:
            return "#5856D6"
        case .work:
            return "#A2845E"
        case .others:
            return "#8E8E93"
        case .salary:
            return "#34C759"
        case .interest, .feesInterest:
            return "#30B0C7"
        case .investmentReturns:
            return "#5856D6"
        case .giftsRepayments:
            return "#FF2D55"
        case .otherIncome:
            return "#8E8E93"
        }
    }

    var color: Color {
        switch self {
        case .food:
            return .green
        case .eatingOut:
            return .mint
        case .rent:
            return .purple
        case .shopping:
            return .orange
        case .entertainment:
            return .pink
        case .transportation:
            return .blue
        case .utilities:
            return .yellow
        case .subscriptions:
            return .teal
        case .healthcare:
            return .red
        case .education:
            return .indigo
        case .work:
            return .brown
        case .others, .otherIncome:
            return .gray
        case .salary:
            return .green
        case .interest, .feesInterest:
            return .teal
        case .investmentReturns:
            return .indigo
        case .giftsRepayments:
            return .pink
        }
    }
}

struct FinanceCategory: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var iconName: String
    var colorHex: String
    var isCustom: Bool
    var kind: CategoryKind = .expense

    var displayName: String { name }

    init(id: String, name: String, iconName: String, colorHex: String, isCustom: Bool, kind: CategoryKind = .expense) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.isCustom = isCustom
        self.kind = kind
    }

    enum CodingKeys: String, CodingKey {
        case id, name, iconName, colorHex, isCustom, kind
    }

    /// `kind` is missing from catalogs saved before income categories existed: those were all expense.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        iconName = try container.decode(String.self, forKey: .iconName)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        isCustom = try container.decode(Bool.self, forKey: .isCustom)
        kind = try container.decodeIfPresent(CategoryKind.self, forKey: .kind) ?? .expense
    }

    var color: Color {
        Color(hex: colorHex) ?? .gray
    }

    static let builtInCategories: [FinanceCategory] = Category.allCases.map(builtIn(for:))

    static func builtIn(for category: Category) -> FinanceCategory {
        FinanceCategory(
            id: category.categoryID,
            name: category.displayName,
            iconName: category.defaultIconName,
            colorHex: category.defaultColorHex,
            isCustom: false,
            kind: category.kind
        )
    }

    static var fallback: FinanceCategory {
        builtIn(for: .others)
    }

    static func fallback(for kind: CategoryKind) -> FinanceCategory {
        builtIn(for: kind == .income ? .otherIncome : .others)
    }
}

struct CategoryCatalogState: Codable, Equatable {
    var orderedCategoryIDs: [String]
    var customCategories: [FinanceCategory]
    var builtInOverrides: [String: FinanceCategory]
    var hiddenCategoryIDs: Set<String>
    /// Pickers list the most used categories first instead of `orderedCategoryIDs`.
    var sortsByUsage: Bool

    init(
        orderedCategoryIDs: [String] = [],
        customCategories: [FinanceCategory] = [],
        builtInOverrides: [String: FinanceCategory] = [:],
        hiddenCategoryIDs: Set<String> = [],
        sortsByUsage: Bool = false
    ) {
        self.orderedCategoryIDs = orderedCategoryIDs
        self.customCategories = customCategories
        self.builtInOverrides = builtInOverrides
        self.hiddenCategoryIDs = hiddenCategoryIDs
        self.sortsByUsage = sortsByUsage
    }

    enum CodingKeys: String, CodingKey {
        case orderedCategoryIDs
        case customCategories
        case builtInOverrides
        case hiddenCategoryIDs
        case sortsByUsage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderedCategoryIDs = try container.decodeIfPresent([String].self, forKey: .orderedCategoryIDs) ?? []
        customCategories = try container.decodeIfPresent([FinanceCategory].self, forKey: .customCategories) ?? []
        builtInOverrides = try container.decodeIfPresent([String: FinanceCategory].self, forKey: .builtInOverrides) ?? [:]
        hiddenCategoryIDs = try container.decodeIfPresent(Set<String>.self, forKey: .hiddenCategoryIDs) ?? []
        sortsByUsage = try container.decodeIfPresent(Bool.self, forKey: .sortsByUsage) ?? false
    }
}

extension Color {
    init?(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")

        guard sanitized.count == 6,
              let value = Int(sanitized, radix: 16) else {
            return nil
        }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
