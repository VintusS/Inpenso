import Foundation

enum CSVExportService {
    static func export(
        transactions: [Expense],
        currencyCode: String,
        wallets: [Wallet] = [],
        transfers: [Transfer] = [],
        categoryName: (Expense) -> String
    ) throws -> URL {
        let csv = render(
            transactions: transactions, currencyCode: currencyCode,
            wallets: wallets, transfers: transfers, categoryName: categoryName
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Inpenso-Transactions-\(UUID().uuidString).csv")
        try Data(csv.utf8).write(to: url, options: .atomic)
        return url
    }

    static func render(
        transactions: [Expense],
        currencyCode: String,
        timeZone: TimeZone = .current,
        wallets: [Wallet] = [],
        transfers: [Transfer] = [],
        categoryName: (Expense) -> String
    ) -> String {
        let dates = DateFormatter()
        dates.locale = Locale(identifier: "en_US_POSIX")
        dates.calendar = Calendar(identifier: .gregorian)
        dates.timeZone = timeZone
        dates.dateFormat = "yyyy-MM-dd"

        let walletNames = Dictionary(wallets.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let header = "date,type,title,category,amount,currency,notes,wallet,from_wallet,to_wallet,fee"
        let records = transactions.map { transaction in
            [
                dates.string(from: transaction.date),
                transaction.type.rawValue,
                transaction.title,
                categoryName(transaction),
                plainAmount(transaction.price),
                currencyCode,
                transaction.notes ?? "",
                transaction.walletID.flatMap { walletNames[$0] } ?? "",
                "", "", "",
            ]
            .map(quotedField)
            .joined(separator: ",")
        }
        let transferRecords = transfers.map { transfer in
            [
                dates.string(from: transfer.date),
                "transfer", "", "",
                plainAmount(transfer.amount),
                currencyCode,
                transfer.note ?? "",
                "",
                walletNames[transfer.fromWalletID] ?? "",
                walletNames[transfer.toWalletID] ?? "",
                transfer.feeAmount.map(plainAmount) ?? "",
            ]
            .map(quotedField)
            .joined(separator: ",")
        }
        return ([header] + records + transferRecords).joined(separator: "\r\n") + "\r\n"
    }

    private static func quotedField(_ field: String) -> String {
        if field.unicodeScalars.contains(where: { ",\"\r\n".unicodeScalars.contains($0) }) {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    private static func plainAmount(_ amount: Double) -> String {
        let parts = String(amount).split(separator: "e", maxSplits: 1)
        guard parts.count == 2, let exponent = Int(parts[1]) else { return String(amount) }

        // Expand scientific notation without rounding to the currency's display precision.
        let mantissa = parts[0]
        let sign = mantissa.hasPrefix("-") ? "-" : ""
        let unsigned = mantissa.dropFirst(sign.count)
        let decimals = unsigned.split(separator: ".", maxSplits: 1)
        let digits = decimals.joined()
        let decimalIndex = decimals[0].count + exponent
        if decimalIndex <= 0 {
            return sign + "0." + String(repeating: "0", count: -decimalIndex) + digits
        }
        if decimalIndex >= digits.count {
            return sign + digits + String(repeating: "0", count: decimalIndex - digits.count)
        }
        return sign + digits.prefix(decimalIndex) + "." + digits.dropFirst(decimalIndex)
    }
}
