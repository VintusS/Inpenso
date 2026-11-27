import Foundation
@testable import Inpenso

enum TestFixtures {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    static func rule(startDate: Date, day: Int, walletID: UUID? = nil) -> RecurringRule {
        RecurringRule(
            title: "Rent", amount: 150_000, type: .expense, categoryID: Category.others.categoryID,
            dayOfMonth: day, startDate: startDate, walletID: walletID
        )
    }

    static func ledger() -> WalletLedger {
        let bank = Wallet(name: "BCA", kind: .bank, iconName: "building.columns", colorHex: "#34785D", openingBalance: 1_000_000)
        let cash = Wallet(name: "Cash", kind: .cash, iconName: "banknote", colorHex: "#34785D")
        return WalletLedger(wallets: [bank, cash], defaultWalletID: bank.id, transactions: [], transfers: [], currency: "IDR")
    }

    static func transfer(in ledger: WalletLedger) -> Transfer {
        Transfer(
            fromWalletID: ledger.wallets[0].id, toWalletID: ledger.wallets[1].id,
            amount: 200_000, date: date(2_025, 2, 1), feeAmount: 2_500
        )
    }
}
